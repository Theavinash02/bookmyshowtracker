import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import 'checker.dart';

/// Loads pages in a hidden, real Android WebView (Chrome engine).
///
/// BookMyShow is behind Cloudflare, which rejects plain HTTP clients
/// (HTTP 403). A real browser engine passes the check, keeps the
/// clearance cookie, and also runs the page's JavaScript, so show-times
/// that are rendered client-side are visible too.
class WebFetcher {
  HeadlessInAppWebView? _view;
  InAppWebViewController? _ctrl;
  Completer<void>? _loaded;
  int _status = 200;

  Future<InAppWebViewController> _controller() async {
    if (_ctrl != null) return _ctrl!;
    final created = Completer<InAppWebViewController>();
    _view = HeadlessInAppWebView(
      // A tall "screen" so lazily-rendered theater lists render fully
      // (pixels; a hidden WebView otherwise has a tiny viewport).
      initialSize: const Size(1080, 12000),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        thirdPartyCookiesEnabled: true,
        blockNetworkImage: true, // faster, images are not needed
        mediaPlaybackRequiresUserGesture: true,
      ),
      onWebViewCreated: (c) {
        if (!created.isCompleted) created.complete(c);
      },
      onLoadStart: (c, url) => _status = 200,
      onLoadStop: (c, url) {
        final l = _loaded;
        if (l != null && !l.isCompleted) l.complete();
      },
      onReceivedHttpError: (c, req, res) {
        if (req.isForMainFrame ?? true) _status = res.statusCode ?? _status;
      },
      onReceivedError: (c, req, err) {
        if (!(req.isForMainFrame ?? true)) return;
        final l = _loaded;
        if (l != null && !l.isCompleted) {
          l.completeError(Exception('Load failed: ${err.description}'));
        }
      },
    );
    await _view!.run();
    _ctrl = await created.future.timeout(const Duration(seconds: 20));
    return _ctrl!;
  }

  Future<String> _dom(InAppWebViewController c) async {
    final r = await c.evaluateJavascript(
        source: '(document.documentElement ? document.documentElement.outerHTML : "")'
            ' + "\\n<!--TEXT-->\\n" + (document.body ? document.body.innerText : "")');
    return r is String ? r : '';
  }

  Future<FetchedPage> fetch(String url) async {
    final c = await _controller();
    _loaded = Completer<void>();
    _status = 200;
    await c.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    await _loaded!.future.timeout(const Duration(seconds: 40));
    return _settle(c, url);
  }

  /// Waits for a Cloudflare check to finish and for JavaScript-rendered
  /// content to settle (page text unchanged across two polls).
  Future<FetchedPage> _settle(InAppWebViewController c, String url) async {
    var html = '';
    var last = -1;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (true) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      // Scroll to the bottom to trigger lazy loading of more theaters.
      try {
        await c.evaluateJavascript(
            source: 'window.scrollTo(0, document.body ? document.body.scrollHeight : 0);');
      } catch (_) {}
      html = await _dom(c);
      final challenge = looksLikeChallenge(html);
      if (!challenge && html.length == last) break;
      if (DateTime.now().isAfter(deadline)) break;
      last = html.length;
    }
    final current = await c.getUrl();
    final status = looksLikeChallenge(html) ? 403 : _status;
    return FetchedPage(
        status, Uri.parse(current?.toString() ?? url), html);
  }

  /// Loads [url] and clicks the element whose text is [buttonText] (like a
  /// person pressing "Book tickets"). Returns the page after the click: its
  /// URL (if it navigated) and DOM (including any picker that opened). If
  /// there is no such button, returns the page as loaded, unclicked.
  Future<ClickResult> clickAndCapture(String url, String buttonText) async {
    final before = await fetch(url);
    final c = await _controller();
    // Click the real control, not an outer wrapper with the same text
    // (a click on a wrapper never reaches the button's handler): prefer
    // <button>/<a>/role=button, else the innermost matching element.
    final js = '''(function(){
      var want = ${jsonEncode(buttonText.toLowerCase())};
      var all = Array.prototype.slice.call(
          document.querySelectorAll('button,a,[role=button],div,span'));
      var m = all.filter(function(e){
        return e.innerText && e.innerText.trim().toLowerCase() === want; });
      if (!m.length) return 'none';
      var b = m.find(function(e){
        return e.tagName === 'BUTTON' || e.tagName === 'A' ||
               e.getAttribute('role') === 'button'; }) || m[m.length - 1];
      b.click();
      return 'clicked';
    })()''';
    final r = await c.evaluateJavascript(source: js);
    if (r != 'clicked') return ClickResult(before, clicked: false);
    _loaded = Completer<void>();
    // Either a navigation (wait for it) or an in-page picker (just settle).
    try {
      await _loaded!.future.timeout(const Duration(seconds: 8));
    } catch (_) {}
    return ClickResult(await _settle(c, before.finalUrl.toString()),
        clicked: true);
  }

  Future<void> dispose() async {
    try {
      await _view?.dispose();
    } catch (_) {}
    _view = null;
    _ctrl = null;
  }
}

/// Creates a page loader that uses the WebView, falling back to plain
/// HTTP if the WebView itself cannot be used on this phone.
class PageLoader {
  final _web = WebFetcher();
  final _client = http.Client();
  bool _webBroken = false;

  Future<FetchedPage> load(String url) async {
    if (!_webBroken) {
      try {
        return await _web.fetch(url);
      } on TimeoutException {
        rethrow;
      } catch (e) {
        // Only give up on the WebView if it could not even be created.
        if (_web._ctrl == null) {
          _webBroken = true;
        } else {
          rethrow;
        }
      }
    }
    return fetchPage(_client, url);
  }

  /// See [WebFetcher.clickAndCapture]; null without a working WebView.
  Future<ClickResult?> click(String url, String buttonText) async {
    if (_webBroken) return null;
    try {
      return await _web.clickAndCapture(url, buttonText);
    } catch (_) {
      return null;
    }
  }

  Future<void> close() async {
    await _web.dispose();
    _client.close();
  }
}

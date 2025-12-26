import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/hltb_game_data.dart';
import 'hltb_scraper.dart';

/// Singleton service that manages HLTB WebView scraping
/// Uses a single persistent WebView to avoid bot detection
class HltbWebViewService {
  static final HltbWebViewService instance = HltbWebViewService._internal();

  HltbWebViewService._internal();

  InAppWebViewController? _controller;
  bool _isInitialized = false;
  final List<_SearchRequest> _requestQueue = [];
  bool _isProcessing = false;

  /// Initialize the service with a WebView controller
  Future<void> initialize(InAppWebViewController controller) async {
    _controller = controller;
    _isInitialized = true;

    // Process any queued requests
    _processQueue();
  }

  /// Search for a game on HLTB
  /// Returns HltbGameData if found, null otherwise
  Future<HltbGameData?> searchGame(String gameName) async {
    if (!_isInitialized || _controller == null) {
      // Add to queue and wait
      final completer = Completer<HltbGameData?>();
      _requestQueue.add(_SearchRequest(gameName, completer));

      // Wait up to 10 seconds for initialization
      final timeout = Future.delayed(const Duration(seconds: 10), () => null);
      return Future.any([completer.future, timeout]);
    }

    try {
      return await _performSearch(gameName);
    } catch (e) {
      return null;
    }
  }

  /// Perform the actual search operation
  Future<HltbGameData?> _performSearch(String gameName) async {
    if (_controller == null) return null;

    final encodedName = Uri.encodeComponent(gameName);
    final searchUrl = 'https://howlongtobeat.com/?q=$encodedName';

    try {
      // Navigate to search URL
      await _controller!.loadUrl(
        urlRequest: URLRequest(url: WebUri(searchUrl)),
      );

      // Wait for page load
      await _controller!.evaluateJavascript(
        source: 'new Promise(resolve => window.addEventListener("load", resolve))',
      );

      // Poll for results to load (SPA needs time to render)
      final resultsLoaded = await _waitForResults(gameName);

      if (!resultsLoaded) {
        return null;
      }

      // Extract game data
      final result = await _controller!.evaluateJavascript(
        source: HltbScraper.extractGameData(),
      );

      final gameData = HltbScraper.parseResponse(result?.toString());

      return gameData;
    } catch (e) {
      return null;
    }
  }

  /// Wait for search results to appear on page (with polling)
  Future<bool> _waitForResults(String gameName) async {
    if (_controller == null) return false;

    const maxAttempts = 40; // 40 * 100ms = 4 seconds max wait
    const pollInterval = Duration(milliseconds: 100);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final loaded = await _controller!.evaluateJavascript(
          source: HltbScraper.checkResultsLoaded(),
        );

        if (loaded == true) {
          return true;
        }

        await Future.delayed(pollInterval);
      } catch (e) {
        // Ignore polling errors
      }
    }

    return false;
  }

  /// Process queued requests after initialization
  void _processQueue() async {
    if (_isProcessing || _requestQueue.isEmpty) return;

    _isProcessing = true;

    while (_requestQueue.isNotEmpty) {
      final request = _requestQueue.removeAt(0);

      try {
        final result = await _performSearch(request.gameName);
        request.completer.complete(result);
      } catch (e) {
        request.completer.completeError(e);
      }

      // Rate limiting between queued requests
      if (_requestQueue.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    _isProcessing = false;
  }

  /// Clean up resources (navigate to blank page to reduce memory)
  Future<void> cleanup() async {
    if (_controller == null) return;

    try {
      await _controller!.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Reset the service (for testing/debugging)
  void reset() {
    _controller = null;
    _isInitialized = false;
    _requestQueue.clear();
    _isProcessing = false;
  }
}

/// Internal class to queue search requests
class _SearchRequest {
  final String gameName;
  final Completer<HltbGameData?> completer;

  _SearchRequest(this.gameName, this.completer);
}

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/hltb_webview_service.dart';

/// Hidden WebView container for HLTB scraping
/// This widget is invisible (1x1px) but maintains a persistent WebView
/// to avoid bot detection by acting like a real browser
class HltbWebViewContainer extends StatelessWidget {
  const HltbWebViewContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 1,
      child: InAppWebView(
        initialSettings: InAppWebViewSettings(
          // Act like a real browser
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',

          // Keep session/cookies (helps avoid detection)
          clearCache: false,
          incognito: false,

          // Performance optimizations for hidden view
          mediaPlaybackRequiresUserGesture: false,
          javaScriptEnabled: true,

          // Disable unnecessary features
          useOnLoadResource: false,
          useShouldOverrideUrlLoading: false,

          // Logging (disable in production)
          isInspectable: true, // Enable for debugging
        ),
        initialUrlRequest: URLRequest(
          url: WebUri('about:blank'), // Start with blank page
        ),
        onWebViewCreated: (controller) {
          // Register controller with service
          HltbWebViewService.instance.initialize(controller);
        },
        onReceivedError: (controller, request, error) {
          // Ignore ad/tracking script errors (ERR_BLOCKED_BY_ORB is expected)
          final url = request.url.toString();
          final isAdScript = url.contains('confiant') ||
                             url.contains('doubleclick') ||
                             url.contains('google-analytics') ||
                             url.contains('googlesyndication');

          // Only log non-ad errors
          if (!isAdScript && url.contains('howlongtobeat.com')) {
            debugPrint('[HltbWebView] ❌ Error: ${error.description}');
          }
        },
      ),
    );
  }
}

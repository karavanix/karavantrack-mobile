import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Shows the Telegram Login Widget in an in-app WebView.
/// On successful auth Telegram redirects to karavantrack://auth/telegram?...
/// The WebView intercepts that URL and returns the query params via [onAuthData].
class TelegramAuthWebView extends StatelessWidget {
  const TelegramAuthWebView({
    super.key,
    required this.widgetUrl,
    required this.onAuthData,
  });

  /// Full URL of the backend widget page, e.g.
  /// https://api.yool.live/api/v1/auth/telegram/widget?role=carrier
  final String widgetUrl;

  /// Called with the raw Telegram auth query params when auth completes.
  final void Function(Map<String, String> data) onAuthData;

  static const _deepLinkScheme = 'karavantrack://auth/telegram';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widgetUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
        ),
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final uri = navigationAction.request.url;
          if (uri == null) return NavigationActionPolicy.ALLOW;

          final url = uri.toString();
          if (url.startsWith(_deepLinkScheme)) {
            final params = uri.queryParameters;
            if (params.containsKey('id') && params.containsKey('hash')) {
              onAuthData(Map<String, String>.from(params));
              if (context.mounted) Navigator.of(context).pop();
            }
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}

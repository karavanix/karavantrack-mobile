import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import '../store/app_store.dart';
import 'debug_service.dart';

const String _clientId           = '8966637225';
const String _iosRedirectUri     = 'https://app3555230600-login.tg.dev';
const String _androidRedirectUri = 'https://app1451611780-login.tg.dev/tglogin';
// const String _androidRedirectUri = 'https://app3297224938-login.tg.dev/tglogin';

const _channel = MethodChannel('yool.live.app/telegram_auth');
final _log = DebugService.talker;

class TelegramAuthService {
  static AppStore? _store;

  /// Register the MethodChannel handler. Call ONCE from app.dart initState,
  /// before the first frame is rendered.
  static void init(AppStore store) {
    _store = store;
    _channel.setMethodCallHandler(_handleCallback);
    _log.info('[TG] MethodChannel handler registered');
  }

  static Future<void> _handleCallback(MethodCall call) async {
    if (call.method != 'onTelegramCallback') return;
    final args  = Map<String, dynamic>.from(call.arguments as Map);
    final code  = args['code']  as String;
    final state = args['state'] as String;
    _log.info('[TG] onTelegramCallback received · code=${code.length} chars state=$state');
    final redirectUri = Platform.isIOS ? _iosRedirectUri : _androidRedirectUri;
    await _store?.telegramSignInWithCode(code: code, state: state, redirectUri: redirectUri);
  }

  /// Requests PKCE params from the backend, then opens the Telegram OAuth URL.
  /// If Telegram is installed, opens it directly via a tg:// deeplink.
  /// Otherwise falls back to an in-app browser (Chrome Custom Tab / SFSafariVC).
  /// The auth result arrives asynchronously through the MethodChannel handler above.
  static Future<void> startAuth() async {
    final redirectUri = Platform.isIOS ? _iosRedirectUri : _androidRedirectUri;
    _log.info('[TG] startAuth() · redirectUri=$redirectUri');

    final pkce = await ApiService.instance.requestPkce();
    final state     = pkce['state']          as String;
    final challenge = pkce['code_challenge'] as String;
    _log.info('[TG] PKCE received · state=$state');

    // On Android we deliberately skip the tg:// cross-app shortcut. When
    // Telegram is installed, it opens the https redirect_uri inside its own
    // in-app webview, which never fires a system VIEW intent — so the verified
    // App Link is never triggered and control never returns to the app (the
    // user is left stranded inside Telegram). Going straight to the Custom Tab
    // web flow lets the verified App Link break out and reopen the app. See
    // https://github.com/tdlib/telegram-bot-api/issues/681 and #299.
    if (Platform.isIOS) {
      // Try to get a tg:// deeplink that opens Telegram directly (if installed).
      final crossAppUri = await _fetchCrossAppUri(
        state: state,
        challenge: challenge,
        redirectUri: redirectUri,
      );

      if (crossAppUri != null && await canLaunchUrl(crossAppUri)) {
        _log.info('[TG] launching cross-app URI — Telegram is installed');
        await launchUrl(crossAppUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Web flow via in-app browser (Chrome Custom Tab / SFSafariVC). On Android
    // this is the primary path. The verified App Link breaks out of the Custom
    // Tab and reopens the app; the redirect is delivered via onNewIntent /
    // onFlutterUiDisplayed.
    final webUri = Uri.https('oauth.telegram.org', '/auth', {
      'client_id':             _clientId,
      'redirect_uri':          redirectUri,
      'response_type':         'code',
      'scope':                 'openid profile phone',
      'state':                 state,
      'code_challenge':        challenge,
      'code_challenge_method': 'S256',
    });
    _log.info('[TG] launching web auth URI (in-app browser)');
    await launchUrl(webUri, mode: LaunchMode.inAppBrowserView);
  }

  // Calls Telegram's /crossapp endpoint, which returns {"url": "tg://..."} when
  // the request is valid. The tg:// URL opens the Telegram app directly to the
  // consent screen — no browser hop required.
  static Future<Uri?> _fetchCrossAppUri({
    required String state,
    required String challenge,
    required String redirectUri,
  }) async {
    try {
      final sdkParam = Platform.isIOS ? 'ios_sdk' : 'android_sdk';
      final uri = Uri.https('oauth.telegram.org', '/crossapp', {
        'client_id':             _clientId,
        'response_type':         'code',
        'redirect_uri':          redirectUri,
        'scope':                 'openid profile phone',
        'state':                 state,
        'code_challenge':        challenge,
        'code_challenge_method': 'S256',
        sdkParam:                '1',
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final url = data['url'] as String?;
        _log.info('[TG] /crossapp → url=$url');
        return url != null ? Uri.tryParse(url) : null;
      }
      _log.warning('[TG] /crossapp HTTP ${response.statusCode}');
    } catch (e) {
      _log.warning('[TG] /crossapp failed: $e');
    }
    return null;
  }
}

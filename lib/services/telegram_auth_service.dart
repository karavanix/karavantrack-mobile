import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import '../store/app_store.dart';
import 'debug_service.dart';

const String _clientId           = '8966637225';
const String _redirectUri = 'https://api.yool.live/api/v1/auth/telegram/callback';

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
    await closeInAppWebView();
    final args  = Map<String, dynamic>.from(call.arguments as Map);
    final code  = args['code']  as String;
    final state = args['state'] as String;
    _log.info('[TG] onTelegramCallback received · code=${code.length} chars state=$state');
    await _store?.telegramSignInWithCode(code: code, state: state, redirectUri: _redirectUri);
  }

  static Future<void> startAuth() async {
    final pkce      = await ApiService.instance.requestPkce();
    final state     = pkce['state']          as String;
    final challenge = pkce['code_challenge'] as String;

    final uri = Uri.https('oauth.telegram.org', '/auth', {
      'client_id':             _clientId,
      'redirect_uri':          _redirectUri,
      'response_type':         'code',
      'scope':                 'openid profile phone',
      'state':                 state,
      'code_challenge':        challenge,
      'code_challenge_method': 'S256',
    });
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }
}

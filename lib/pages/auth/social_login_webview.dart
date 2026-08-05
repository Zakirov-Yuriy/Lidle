import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/config/social_auth_config.dart';

/// Результат авторизации VK ID: одноразовый code, device_id и code_verifier.
/// Всё это уходит на бэк, который меняет код на токены (POST /v1/auth/social).
class SocialAuthResult {
  final String code;
  final String deviceId;
  final String codeVerifier;

  const SocialAuthResult({
    required this.code,
    required this.deviceId,
    required this.codeVerifier,
  });
}

/// Экран авторизации VK ID в WebView (OAuth 2.1 + PKCE).
///
/// Генерирует code_verifier/code_challenge и state, открывает
/// id.vk.ru/authorize (виджет «3 в 1»: ВК/ОК/Mail), ловит редирект на
/// redirect_uri?code=...&device_id=...&state=... и возвращает SocialAuthResult
/// через Navigator.pop. Сам код на токены НЕ меняет — это делает бэк.
class SocialLoginWebView extends StatefulWidget {
  /// Провайдер-метка (vk/ok/mail_ru). Флоу единый VK ID, метка идёт на бэк
  /// только для информации.
  final String provider;

  const SocialLoginWebView({super.key, required this.provider});

  @override
  State<SocialLoginWebView> createState() => _SocialLoginWebViewState();
}

class _SocialLoginWebViewState extends State<SocialLoginWebView> {
  late final WebViewController _controller;
  late final String _codeVerifier;
  late final String _state;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _codeVerifier = _randomString(64);
    _state = _randomString(24);
    final challenge = _codeChallenge(_codeVerifier);
    final url = SocialAuthConfig.authorizeUrl(
      codeChallenge: challenge,
      state: _state,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final result = _tryExtract(request.url);
            if (result != null && !_handled) {
              _handled = true;
              Navigator.of(context).pop(result);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  /// Достаёт code + device_id из redirect_uri?code=...&device_id=...&state=...
  /// Проверяет state (защита от подмены).
  SocialAuthResult? _tryExtract(String url) {
    if (!url.startsWith(SocialAuthConfig.redirectUri)) return null;
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];
    final deviceId = uri.queryParameters['device_id'];
    final returnedState = uri.queryParameters['state'];

    if (code == null || code.isEmpty) return null;
    if (deviceId == null || deviceId.isEmpty) return null;
    if (returnedState != null && returnedState != _state) return null;

    return SocialAuthResult(
      code: code,
      deviceId: deviceId,
      codeVerifier: _codeVerifier,
    );
  }

  static const String _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  String _randomString(int len) {
    final r = Random.secure();
    return List.generate(len, (_) => _chars[r.nextInt(_chars.length)]).join();
  }

  /// PKCE code_challenge = base64url(sha256(code_verifier)) без паддинга.
  String _codeChallenge(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryBackground,
      appBar: AppBar(
        backgroundColor: secondaryBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: textPrimary),
        title: const Text(
          'Вход через VK ID',
          style: TextStyle(color: textPrimary, fontSize: 16),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

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
///
/// Редирект ловим сразу на трёх хуках (onNavigationRequest, onPageStarted,
/// onUrlChange), потому что webview_flutter не всегда вызывает
/// onNavigationRequest на финальном 302-редиректе VK ID — без этого страница
/// lidle.ru успевает загрузиться и вход в приложении не завершается.
/// Параметры достаём и из query (?code=...), и из фрагмента (#code=...),
/// т.к. VK ID в части флоу возвращает их во фрагменте.
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
          // Основной перехват: до загрузки страницы.
          onNavigationRequest: (request) {
            if (_handleIfRedirect(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          // Подстраховка №1: страница начала грузиться (напр. финальный 302,
          // который onNavigationRequest пропустил). Успеваем забрать code и
          // закрыть WebView до фактической отрисовки сайта.
          onPageStarted: (url) => _handleIfRedirect(url),
          // Подстраховка №2: любое изменение URL (JS-редиректы и т.п.).
          onUrlChange: (change) {
            final u = change.url;
            if (u != null) _handleIfRedirect(u);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  /// Если url — это наш redirect с валидным результатом, забираем его и
  /// закрываем экран. Возвращает true, если редирект обработан.
  bool _handleIfRedirect(String url) {
    if (_handled) return false;
    final result = _tryExtract(url);
    if (result == null) return false;
    _handled = true;
    if (mounted) {
      Navigator.of(context).pop(result);
    }
    return true;
  }

  /// Достаёт code + device_id из redirect_uri (query ИЛИ фрагмент).
  /// Проверяет state (защита от подмены).
  SocialAuthResult? _tryExtract(String url) {
    if (!url.startsWith(SocialAuthConfig.redirectUri)) return null;
    final params = _paramsFrom(url);

    final code = params['code'];
    final deviceId = params['device_id'];
    final returnedState = params['state'];

    if (code == null || code.isEmpty) return null;
    if (deviceId == null || deviceId.isEmpty) return null;
    if (returnedState != null && returnedState != _state) return null;

    return SocialAuthResult(
      code: code,
      deviceId: deviceId,
      codeVerifier: _codeVerifier,
    );
  }

  /// Собирает параметры из query и из фрагмента (VK ID может вернуть их в
  /// любом из двух мест). Query имеет приоритет.
  Map<String, String> _paramsFrom(String url) {
    final uri = Uri.parse(url);
    final result = <String, String>{};

    // Фрагмент вида "#code=...&device_id=..." (или "#/?code=...").
    final frag = uri.fragment;
    if (frag.isNotEmpty) {
      final qIndex = frag.indexOf('?');
      final fragQuery = qIndex >= 0 ? frag.substring(qIndex + 1) : frag;
      if (fragQuery.contains('=')) {
        result.addAll(Uri.splitQueryString(fragQuery));
      }
    }

    // Query имеет приоритет над фрагментом.
    result.addAll(uri.queryParameters);
    return result;
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

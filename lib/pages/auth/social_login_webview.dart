import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/config/social_auth_config.dart';

/// Экран авторизации соцсети в WebView.
///
/// Открывает страницу авторизации провайдера (VK/ОК), ловит редирект на
/// redirect_uri?code=... и возвращает authorization code через
/// Navigator.pop(context, code). Сам код на токены НЕ меняет — это делает бэк
/// (POST /v1/auth/social). При отмене/закрытии возвращает null.
class SocialLoginWebView extends StatefulWidget {
  final String provider; // 'vk' | 'ok'

  const SocialLoginWebView({super.key, required this.provider});

  @override
  State<SocialLoginWebView> createState() => _SocialLoginWebViewState();
}

class _SocialLoginWebViewState extends State<SocialLoginWebView> {
  late final WebViewController _controller;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    final authUrl = SocialAuthConfig.authorizeUrl(widget.provider);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final code = _extractCode(request.url);
            if (code != null && !_handled) {
              _handled = true;
              Navigator.of(context).pop(code);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (authUrl != null) {
      _controller.loadRequest(Uri.parse(authUrl));
    }
  }

  /// Достаёт code из redirect_uri?code=... (или из fragment, на всякий случай).
  String? _extractCode(String url) {
    if (!url.startsWith(SocialAuthConfig.redirectUri)) return null;
    final uri = Uri.parse(url);

    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) return code;

    if (uri.fragment.isNotEmpty) {
      final frag = Uri.splitQueryString(uri.fragment);
      final f = frag['code'];
      if (f != null && f.isNotEmpty) return f;
    }
    return null;
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
          'Вход через соцсеть',
          style: TextStyle(color: textPrimary, fontSize: 16),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

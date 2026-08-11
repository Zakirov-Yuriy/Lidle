import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/core/config/social_auth_config.dart';
import 'package:lidle/pages/auth/vkid_auth_service.dart';

/// Общий блок быстрого входа/регистрации через соцсети.
///
/// Используется и на экране входа (`sign_in_screen.dart`), и на экране
/// регистрации (`register_screen.dart`). Флоу один и тот же: ВК/ОК открывают
/// WebView авторизации, получают authorization code и отдают его в AuthBloc
/// (SocialLoginEvent) — на бэке find-or-create, поэтому один и тот же блок
/// закрывает и вход, и регистрацию. Mail.ru и QR пока показывают уведомление,
/// Google — диалог о запрете иностранных сервисов в РФ.
class SocialAuthBlock extends StatefulWidget {
  /// Подпись в разделителе («Или продолжить через» / «Или зарегистрируйтесь
  /// через»).
  final String label;

  const SocialAuthBlock({super.key, this.label = 'Или продолжить через'});

  @override
  State<SocialAuthBlock> createState() => _SocialAuthBlockState();
}

class _SocialAuthBlockState extends State<SocialAuthBlock> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Разделитель с подписью по центру.
        Row(
          children: [
            const Expanded(child: Divider(color: textMuted, thickness: 0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                widget.label,
                style: const TextStyle(color: textMuted, fontSize: 14),
              ),
            ),
            const Expanded(child: Divider(color: textMuted, thickness: 0.5)),
          ],
        ),
        const SizedBox(height: 18),
        // Ряд иконок. ВК/ОК ведут в соцвход, Mail/QR — заглушка,
        // Google — уведомление о запрете иностранных сервисов.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _socialCircle(
              tooltip: 'ВКонтакте',
              onTap: () => _onSocialLogin('vk'),
              child: Image.asset('assets/socials/vk.png', width: 26, height: 26),
            ),
            _socialCircle(
              tooltip: 'Одноклассники',
              onTap: () => _onSocialLogin('ok'),
              child: Image.asset('assets/socials/ok.png', width: 26, height: 26),
            ),
            _socialCircle(
              tooltip: 'Mail.ru',
              onTap: () => _onSocialLogin('mail_ru'),
              child:
                  Image.asset('assets/socials/email.png', width: 26, height: 26),
            ),
            _socialCircle(
              tooltip: 'QR-код',
              onTap: () => _onSocialLogin('qr'),
              child: const Icon(Icons.qr_code_2, color: textPrimary, size: 28),
            ),
            _socialCircle(
              tooltip: 'Google',
              onTap: _onGoogleBlocked,
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFFEA4335),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Круглая кнопка-иконка соцсети (единый стиль для всего ряда).
  Widget _socialCircle({
    required Widget child,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: secondaryBackground,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  /// Соцвход через ВК/ОК: открываем WebView, получаем code, отдаём в AuthBloc.
  /// После AuthAuthenticated навигация срабатывает на том экране, где висит
  /// BlocConsumer (вход/регистрация). Mail.ru и QR пока в разработке.
  Future<void> _onSocialLogin(String provider) async {
    // ВК / ОК / Mail идут в единый VK ID (виджет «3 в 1»). QR пока отдельно.
    if (provider != 'vk' && provider != 'ok' && provider != 'mail_ru') {
      SnackBarHelper.showWarning(
        context,
        'Этот способ входа скоро будет доступен',
      );
      return;
    }

    if (!SocialAuthConfig.isConfigured) {
      SnackBarHelper.showWarning(
        context,
        'Вход через соцсеть ещё настраивается',
      );
      return;
    }

    // Нативный VK ID SDK (one tap / app-to-app). SDK возвращает authorization
    // code + device_id + redirect_uri; обмен на токены делает бэк по PKCE.
    final result = await VkIdAuthService.authorize(provider);

    if (result == null) {
      // Вход не удался. Отмену пользователем не показываем как ошибку, а на
      // реальную ошибку SDK выводим короткое уведомление (без тихого возврата).
      final err = VkIdAuthService.lastError ?? '';
      final cancelled =
          err.contains('AuthCancelledError') || err.contains('отмена');
      if (mounted && !cancelled) {
        SnackBarHelper.showWarning(
          context,
          'Не удалось войти через VK. Попробуйте ещё раз.',
        );
      }
      return;
    }
    if (!mounted) return;

    context.read<AuthBloc>().add(
      SocialLoginEvent(
        provider: provider,
        code: result.code,
        codeVerifier: result.codeVerifier,
        deviceId: result.deviceId,
        // ВАЖНО: redirect от SDK (vk<appid>://...), НЕ https://lidle.ru.
        // Бэк должен обменять код именно с этим redirect_uri.
        redirectUri: result.redirectUri,
      ),
    );
  }

  /// Google: по закону РФ вход/регистрация через иностранные сервисы
  /// запрещены. Как на Авито — показываем уведомление, вход не выполняем.
  void _onGoogleBlocked() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Войти через Google в России не получится',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'По закону на LIDLE нельзя входить и регистрироваться с помощью '
          'иностранных сервисов. Используйте другой способ или восстановите '
          'доступ по телефону.',
          style: TextStyle(color: textMuted, fontSize: 15, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Понятно',
              style: TextStyle(color: activeIconColor, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

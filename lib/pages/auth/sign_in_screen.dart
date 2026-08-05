import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/core/config/social_auth_config.dart';
import 'account_recovery.dart';
import 'register_screen.dart';
import 'register_verify_screen.dart';
import 'social_login_webview.dart';
import 'package:lidle/pages/profile_dashboard/profile_dashboard.dart';

// ============================================================
// "Главный экран входа в систему"
// ============================================================
class SignInScreen extends StatefulWidget {
  static const routeName = '/sign-in';

  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

// ============================================================
// "Состояние экрана входа"
// ============================================================
class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _obscure = true;

  // ============================================================
  // "Метод построения интерфейса с управлением состоянием"
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(
              context,
            ).pushReplacementNamed(ProfileDashboard.routeName);
          } else if (state is AuthEmailNotVerified) {
            // 📧 Email не верифицирован — перенаправляем на экран верификации
            Navigator.of(context).pushReplacementNamed(
              RegisterVerifyScreen.routeName,
              arguments: {'email': state.email},
            );
          } else if (state is AuthError) {
            // Показываем ошибку с сервера с типом error
            SnackBarHelper.showError(context, state.message);
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: primaryBackground,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18.0, left: 3),
                    child: const Header(),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
                      // ============================================================
                      // "Форма входа с валидацией"
                      // ============================================================
                      child: FormBuilder(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontSize: 24,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                ),
                                children: const [
                                  TextSpan(text: 'Вы уже почти с нами'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 11),
                            const Text(
                              'Введите личные данные',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 17),

                            const _FieldLabel('Электронная почта'),
                            const SizedBox(height: 9),
                            // ============================================================
                            // "Поле ввода электронной почты"
                            // ============================================================
                            FormBuilderTextField(
                              name: 'email',
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                              ),
                              decoration: _inputDecoration('Введите'),
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(
                                  errorText: 'Введите почту',
                                ),
                                FormBuilderValidators.email(
                                  errorText: 'Неверный формат почты',
                                ),
                              ]),
                            ),
                            const SizedBox(height: 9),

                            const _FieldLabel('Пароль'),
                            const SizedBox(height: 9),
                            // ============================================================
                            // "Поле ввода пароля с показом/скрытием"
                            // ============================================================
                            FormBuilderTextField(
                              name: 'password',
                              obscureText: _obscure,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                              ),
                              decoration: _inputDecoration('Введите').copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(
                                  errorText: 'Введите пароль',
                                ),
                                FormBuilderValidators.minLength(
                                  6,
                                  errorText: 'Минимум 6 символов',
                                ),
                              ]),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: _onForgotPassword,
                                  style: _linkStyle,
                                  child: const Text('Забыл пароль'),
                                ),
                                TextButton(
                                  onPressed: _onSignUp,
                                  style: _linkStyle,
                                  child: const Text('Регистрация'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ============================================================
                            // "Кнопка входа с индикацией загрузки"
                            // ============================================================
                            SizedBox(
                              width: double.infinity,
                              height: 53,
                              child: ElevatedButton(
                                onPressed: state is AuthLoading
                                    ? null
                                    : _onSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: state is AuthLoading
                                      ? Colors.grey
                                      : activeIconColor,
                                  foregroundColor: textPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  elevation: 0,
                                ),
                                child: state is AuthLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Войти',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                              ),
                            ),

                            // ============================================================
                            // "Быстрый вход через соцсети (VK ID: ВК, ОК, Mail.ru, QR)"
                            // Google — иконка-заглушка: по закону РФ регистрация
                            // через иностранные сервисы запрещена → показываем
                            // уведомление (как на Авито), сам вход не выполняем.
                            // ============================================================
                            const SizedBox(height: 24),
                            _buildSocialLogin(),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onForgotPassword() {
    Navigator.of(context).pushNamed(AccountRecovery.routeName);
  }

  void _onSignUp() {
    Navigator.of(context).pushNamed(RegisterScreen.routeName);
  }

  // ============================================================
  // "Блок быстрого входа через соцсети"
  // Разделитель «Или продолжить через» + ряд круглых кнопок.
  // Порядок как на макете/Авито: ВК, ОК, Mail.ru, QR, Google.
  // ============================================================
  Widget _buildSocialLogin() {
    return Column(
      children: [
        // Разделитель с подписью по центру.
        Row(
          children: const [
            Expanded(child: Divider(color: textMuted, thickness: 0.5)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Или продолжить через',
                style: TextStyle(color: textMuted, fontSize: 14),
              ),
            ),
            Expanded(child: Divider(color: textMuted, thickness: 0.5)),
          ],
        ),
        const SizedBox(height: 18),
        // Ряд иконок. ВК/ОК/Mail/QR ведут в VK ID (пока заглушка-хук),
        // Google — уведомление о запрете иностранных сервисов.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _socialCircle(
              tooltip: 'ВКонтакте',
              onTap: () => _onVkIdLogin('vk'),
              child: Image.asset('assets/socials/vk.png', width: 26, height: 26),
            ),
            _socialCircle(
              tooltip: 'Одноклассники',
              onTap: () => _onVkIdLogin('ok'),
              child: Image.asset('assets/socials/ok.png', width: 26, height: 26),
            ),
            _socialCircle(
              tooltip: 'Mail.ru',
              onTap: () => _onVkIdLogin('mail_ru'),
              child:
                  Image.asset('assets/socials/email.png', width: 26, height: 26),
            ),
            _socialCircle(
              tooltip: 'QR-код',
              onTap: () => _onVkIdLogin('qr'),
              child: const Icon(Icons.qr_code_2, color: textPrimary, size: 28),
            ),
            // Google — временная иконка (красная «G»), пока нет ассета.
            _socialCircle(
              tooltip: 'Google',
              onTap: _onGoogleBlocked,
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFFEA4335), // фирменный красный Google
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

  /// Хук быстрого входа через VK ID (ВК / ОК / Mail.ru / QR).
  /// ЭТАП 2: сюда подключается реальный VK ID флоу, когда придёт код от
  /// Александра. Ожидаемая логика:
  ///   провайдер → виджет VK ID → получаем code + device_id →
  ///   POST /v1/auth/vkid → AuthBloc.add(VkIdLoginEvent(...)) →
  ///   AuthAuthenticated → переход на ProfileDashboard (как обычный вход).
  /// Соцвход. Реализованы ВК и ОК: открываем WebView авторизации провайдера,
  /// получаем authorization code и отдаём его в AuthBloc (SocialLoginEvent).
  /// Бэк меняет код на токены и возвращает наши токены — навигация после
  /// AuthAuthenticated срабатывает автоматически (как обычный логин).
  /// Mail.ru и QR пока показывают уведомление.
  Future<void> _onVkIdLogin(String provider) async {
    if (provider != 'vk' && provider != 'ok') {
      SnackBarHelper.showWarning(
        context,
        'Этот способ входа скоро будет доступен',
      );
      return;
    }

    // Не настроен App ID (см. SocialAuthConfig) — вход ещё не готов.
    if (!SocialAuthConfig.isConfigured(provider)) {
      SnackBarHelper.showWarning(
        context,
        'Вход через соцсеть ещё настраивается',
      );
      return;
    }

    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SocialLoginWebView(provider: provider),
      ),
    );

    if (code == null || code.isEmpty) return;
    if (!mounted) return;

    context.read<AuthBloc>().add(
      SocialLoginEvent(
        provider: provider,
        code: code,
        redirectUri: SocialAuthConfig.redirectUri,
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

  // ============================================================
  // "Логика обработки отправки формы входа"
  // ============================================================
  void _onSubmit() {
    final formState = _formKey.currentState;
    final ok = formState?.validate() ?? false;

    if (!ok) {
      // Проверяем конкретные ошибки валидации
      final errors = formState?.fields;

      if (errors != null) {
        // Проверка почты
        if (errors['email'] != null && errors['email']!.hasError) {
          final emailError = errors['email']!.errorText ?? 'Ошибка в почте';
          SnackBarHelper.showError(context, emailError);
          return;
        }

        // Проверка пароля
        if (errors['password'] != null && errors['password']!.hasError) {
          final passwordError =
              errors['password']!.errorText ?? 'Ошибка в пароле';
          // Если это ошибка минимальной длины, показываем как warning
          if (passwordError.contains('Минимум')) {
            SnackBarHelper.showWarning(context, passwordError);
          } else {
            SnackBarHelper.showError(context, passwordError);
          }
          return;
        }
      }

      return;
    }

    formState?.save();
    final formData = formState?.value ?? {};

    context.read<AuthBloc>().add(
      LoginEvent(
        email: (formData['email'] as String?)?.trim() ?? '',
        password: (formData['password'] as String?)?.trim() ?? '',
        remember: true,
      ),
    );
  }

  // ============================================================
  // "Стилизация полей ввода"
  // ============================================================
  static InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textMuted),
      filled: true,
      fillColor: secondaryBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: activeIconColor, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  static final _linkStyle = TextButton.styleFrom(
    foregroundColor: activeIconColor,
    padding: EdgeInsets.zero,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
  );
}

// ============================================================
// "Виджет метки поля формы"
// ============================================================
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
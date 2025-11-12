/// Страница входа в аккаунт.
/// Позволяет пользователю ввести свои учетные данные (email и пароль)
/// для входа в приложение. Также предоставляет ссылки для восстановления пароля
/// и регистрации нового аккаунта.
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/header.dart';
import 'package:lidle/services/auth_service.dart';
import 'package:lidle/hive_service.dart';
import 'account_recovery.dart';
import 'register_screen.dart';
import 'profile_dashboard.dart';

/// `SignInScreen` - это StatefulWidget, который управляет состоянием
/// формы входа пользователя.
class SignInScreen extends StatefulWidget {
  /// Именованный маршрут для этой страницы.
  static const routeName = '/sign-in';

  /// Конструктор для `SignInScreen`.
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

/// Состояние для виджета `SignInScreen`.
class _SignInScreenState extends State<SignInScreen> {
  /// Глобальный ключ для управления состоянием формы.
  final _formKey = GlobalKey<FormState>();
  /// Контроллер для текстового поля "Электронная почта".
  final _emailCtrl = TextEditingController();
  /// Контроллер для текстового поля "Пароль".
  final _passCtrl = TextEditingController();
  /// Флаг для скрытия/отображения текста пароля.
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 76.0),
              child: const Header(),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(31, 0, 31, 0),
                child: Form(
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
                            TextSpan(text: 'Вы уже почти в  '),
                            TextSpan(
                              text: 'LIDLE',

                              style: TextStyle(
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'BebasNeue',
                                fontSize: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 11),
                      const Text(
                        'Выберите способ входа',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 24),

                      const _FieldLabel('Электронная почта'),
                      const SizedBox(height: 9),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                        ),
                        decoration: _inputDecoration('Введите'),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Введите почту';
                          final ok = RegExp(
                            r'^[^@]+@[^@]+\.[^@]+$',
                          ).hasMatch(s);
                          return ok ? null : 'Неверный формат почты';
                        },
                      ),
                      const SizedBox(height: 9),

                      const _FieldLabel('Пароль'),
                      const SizedBox(height: 9),
                      TextFormField(
                        controller: _passCtrl,
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
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Введите пароль';
                          if (s.length < 6) return 'Минимум 6 символов';
                          return null;
                        },
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

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 53,
                        child: ElevatedButton(
                          onPressed: _onSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeIconColor,
                            foregroundColor: textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Войти',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onForgotPassword() {
    Navigator.of(context).pushNamed(AccountRecovery.routeName);
  }

  void _onSignUp() {
    Navigator.of(context).pushNamed(RegisterScreen.routeName);
  }

  Future<void> _onSubmit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    try {
      final response = await AuthService.login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        remember: true,
      );

      // Проверяем успешный ответ с токеном
      if (response['access_token'] != null) {
        await HiveService.saveUserData('token', response['access_token']);
        // Переход на профиль пользователя
        Navigator.of(context).pushReplacementNamed(ProfileDashboard.routeName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка входа: неверные учетные данные')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка входа: $e')),
      );
    }
  }

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
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  );
}

/// Приватный виджет `_FieldLabel` для отображения заголовков полей ввода.
/// Используется для соблюдения принципов DRY/SOLID (повторного использования кода).
class _FieldLabel extends StatelessWidget {
  /// Текст заголовка поля.
  final String text;
  /// Конструктор для `_FieldLabel`.
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

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/header.dart';
import 'account_recovery.dart';
import 'register_screen.dart';
// import 'header.dart'; // если Header в отдельном файле

class SignInScreen extends StatefulWidget {
  static const routeName = '/sign-in';

  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
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
            // Верхний бар, как ты просил
            Padding(
              padding: const EdgeInsets.only(left: 41.0, bottom: 39.0),
              child: const Header(),
            ),

            // Контент со скроллом и отступами
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(31, 24, 31, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок
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

                      // Email
                      const _FieldLabel('Электронная почта'),
                      const SizedBox(height: 9),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 14, // Изменен размер текста
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

                      // Пароль
                      const _FieldLabel('Пароль'),
                      const SizedBox(height: 9),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(color: textPrimary, fontSize: 14), // Изменен размер текста
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

                      const SizedBox(height: 16),

                      // Ссылки
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

                      const SizedBox(height: 22),

                      // Кнопка входа
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

  // ——— actions ———
  void _onForgotPassword() {
    Navigator.of(context).pushNamed(AccountRecovery.routeName);
  }

  void _onSignUp() {
    Navigator.of(context).pushNamed(RegisterScreen.routeName);
  }

  void _onSubmit() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    // TODO: вызов API/репозитория авторизации
    // context.read<AuthCubit>().signIn(_emailCtrl.text.trim(), _passCtrl.text.trim());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Входим...')));
  }

  // Общий стиль для инпутов
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

// Небольшой виджет для заголовков полей (DRY/SOLID — переиспользуем)
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

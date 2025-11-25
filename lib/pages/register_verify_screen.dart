/// Страница верификации регистрации.
/// Пользователь вводит код, отправленный на его электронную почту или телефон,
/// для завершения процесса регистрации.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/pages/sign_in_screen.dart';

/// `RegisterVerifyScreen` - это StatefulWidget, который управляет состоянием
/// страницы верификации регистрации, включая таймеры для отправки кода
/// и поля ввода.
class RegisterVerifyScreen extends StatefulWidget {
  /// Именованный маршрут для этой страницы.
  static const routeName = '/register-verify';

  /// Конструктор для `RegisterVerifyScreen`.
  const RegisterVerifyScreen({super.key});

  @override
  State<RegisterVerifyScreen> createState() => _RegisterVerifyScreenState();
}

/// Состояние для виджета `RegisterVerifyScreen`.
class _RegisterVerifyScreenState extends State<RegisterVerifyScreen> {
  /// Глобальный ключ для управления состоянием формы.
  final _formKey = GlobalKey<FormState>();

  /// Контроллер для текстового поля "Код".
  final _codeCtrl = TextEditingController();

  /// Контроллер для текстового поля "Электронная почта".
  final _emailCtrl = TextEditingController();

  /// Контроллер для текстового поля "Телефон".
  final _phoneCtrl = TextEditingController();

  /// Продолжительность кулдауна перед повторной отправкой кода.
  static const _cooldown = Duration(seconds: 40);

  /// Таймер для отправки кода на электронную почту.
  Timer? _emailTimer;

  /// Таймер для отправки кода на телефон.
  Timer? _phoneTimer;

  /// Оставшееся время до возможности повторной отправки кода на почту.
  Duration _emailLeft = Duration.zero;

  /// Оставшееся время до возможности повторной отправки кода на телефон.
  Duration _phoneLeft = Duration.zero;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _emailTimer?.cancel();
    _phoneTimer?.cancel();
    super.dispose();
  }

  /// Отправляет код на электронную почту.
  void _sendEmailCode() {
    if (_emailCtrl.text.isEmpty) return;

    // Отправляем событие отправки кода в AuthBloc
    context.read<AuthBloc>().add(SendCodeEvent(email: _emailCtrl.text));
    _startEmailTimer();
  }

  /// Отправляет код на телефон.
  void _sendPhoneCode() {
    if (_phoneCtrl.text.isEmpty) return;

    // Отправляем событие отправки кода в AuthBloc
    context.read<AuthBloc>().add(
      SendCodeEvent(email: _phoneCtrl.text),
    ); // Note: API may not support phone, using as email for now
    _startPhoneTimer();
  }

  /// Запускает таймер для отправки кода на электронную почту.
  void _startEmailTimer() {
    _emailTimer?.cancel();
    setState(() => _emailLeft = _cooldown);
    _emailTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_emailLeft.inSeconds <= 1) {
        t.cancel();
        setState(() => _emailLeft = Duration.zero);
      } else {
        setState(() => _emailLeft -= const Duration(seconds: 1));
      }
    });
  }

  /// Запускает таймер для отправки кода на телефон.
  void _startPhoneTimer() {
    _phoneTimer?.cancel();
    setState(() => _phoneLeft = _cooldown);
    _phoneTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_phoneLeft.inSeconds <= 1) {
        t.cancel();
        setState(() => _phoneLeft = Duration.zero);
      } else {
        setState(() => _phoneLeft -= const Duration(seconds: 1));
      }
    });
  }

  /// Подтверждает код верификации.
  void _verify() {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите код')));
      return;
    }

    String email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите email')));
      return;
    }

    // Отправляем событие верификации в AuthBloc
    context.read<AuthBloc>().add(VerifyEmailEvent(email: email, code: code));
  }

  /// Форматирует объект [Duration] в строку "MM:SS".
  /// [d] - объект Duration для форматирования.
  /// Возвращает отформатированную строку.
  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '00:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthCodeSent) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Код отправлен')));
        } else if (state is AuthEmailVerified) {
          // Успешная верификация - переходим на экран входа
          Navigator.of(context).pushReplacementNamed(SignInScreen.routeName);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка: ${state.message}')));
        }
      },
      builder: (context, state) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // const SizedBox(height: 23),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => Navigator.maybePop(context),
                          borderRadius: BorderRadius.circular(24),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.chevron_left,
                                color: Color(0xFF60A5FA),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Назад',
                                style: TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.maybePop(context),
                          child: const Text(
                            'Отмена',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF60A5FA),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    const Text(
                      'Введите номер телефона или электронную почту\nдля отправки кода',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),

                    _CodeField(controller: _codeCtrl),
                    const SizedBox(height: 13),

                    _SendCodeField(
                      label: 'Электронная почта',
                      hint: 'Введите почту',
                      controller: _emailCtrl,
                      keyboard: TextInputType.emailAddress,
                      canSend: _emailLeft == Duration.zero,
                      onSend: _sendEmailCode,
                    ),
                    const SizedBox(height: 8),
                    _CooldownText(
                      visible: _emailLeft > Duration.zero,
                      text: _fmt(_emailLeft),
                    ),
                    const SizedBox(height: 12),

                    _SendCodeField(
                      label: 'Телефон',
                      hint: 'Введите телефон',
                      controller: _phoneCtrl,
                      keyboard: TextInputType.phone,
                      canSend: _phoneLeft == Duration.zero,
                      onSend: _sendPhoneCode,
                    ),
                    const SizedBox(height: 8),
                    _CooldownText(
                      visible: _phoneLeft > Duration.zero,
                      text: _fmt(_phoneLeft),
                    ),

                    // const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),

          bottomNavigationBar: Builder(
            builder: (context) {
              return AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(25, 12, 25, 48),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 53,
                    child: ElevatedButton(
                      onPressed: _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeIconColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        'Подтвердить',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Приватный виджет `_CodeField` для отображения поля ввода кода подтверждения.
/// Включает метку и текстовое поле.
class _CodeField extends StatelessWidget {
  /// Контроллер для управления текстом в поле.
  final TextEditingController controller;

  /// Конструктор для `_CodeField`.
  const _CodeField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _Labeled(
      label: 'Код подтверждения',
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Введите код с письма или смс',
          hintStyle: const TextStyle(color: textMuted),
          filled: true,
          fillColor: secondaryBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Приватный виджет `_SendCodeField` для поля ввода с кнопкой "Отправить код".
/// Используется для ввода электронной почты или номера телефона,
/// с возможностью отправки кода верификации.
class _SendCodeField extends StatelessWidget {
  /// Метка для текстового поля (например, "Электронная почта").
  final String label;

  /// Подсказка в поле ввода.
  final String hint;

  /// Контроллер для управления текстом в поле.
  final TextEditingController controller;

  /// Тип клавиатуры для ввода.
  final TextInputType keyboard;

  /// Флаг, указывающий, можно ли отправить код (таймер не активен).
  final bool canSend;

  /// Callback-функция для отправки кода.
  final VoidCallback onSend;

  /// Конструктор для `_SendCodeField`.
  const _SendCodeField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboard,
    required this.canSend,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final suffix = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: canSend ? onSend : null,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: canSend ? activeIconColor : Colors.white38,
        ),
        child: const Text('Отправить код', style: TextStyle(fontSize: 14)),
      ),
    );

    return _Labeled(
      label: label,
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: textMuted),
          filled: true,
          fillColor: secondaryBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide.none,
          ),
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
      ),
    );
  }
}

/// Приватный виджет `_CooldownText` для отображения текста обратного отсчета.
/// Используется для показа оставшегося времени до возможности повторной отправки кода.
class _CooldownText extends StatelessWidget {
  /// Флаг, указывающий, должен ли текст быть видимым.
  final bool visible;

  /// Текст для отображения (отформатированное время).
  final String text;

  /// Конструктор для `_CooldownText`.
  const _CooldownText({required this.visible, required this.text});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(height: 20);
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: textSecondary),
        children: [
          const TextSpan(text: 'Осталось: '),
          TextSpan(
            text: text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Приватный виджет `_Labeled` для обертки полей ввода с меткой.
/// Предоставляет стандартную структуру для заголовков полей.
class _Labeled extends StatelessWidget {
  /// Метка для поля ввода.
  final String label;

  /// Дочерний виджет (обычно TextField).
  final Widget child;

  /// Конструктор для `_Labeled`.
  const _Labeled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

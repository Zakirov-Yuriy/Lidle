import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'sign_in_screen.dart';

// ============================================================
// "Экран верификации email при регистрации"
// ============================================================
class RegisterVerifyScreen extends StatefulWidget {
  static const routeName = '/register-verify';

  const RegisterVerifyScreen({super.key});

  @override
  State<RegisterVerifyScreen> createState() => _RegisterVerifyScreenState();
}

// ============================================================
// "Состояние экрана верификации с таймерами"
// ============================================================
class _RegisterVerifyScreenState extends State<RegisterVerifyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _codeCtrl = TextEditingController();

  final _emailCtrl = TextEditingController();

  final _phoneCtrl = TextEditingController();

  static const _cooldown = Duration(seconds: 40);

  Timer? _emailTimer;

  Timer? _phoneTimer;

  Duration _emailLeft = Duration.zero;

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

  // ============================================================
  // "Отправка кода на email"
  // ============================================================
  void _sendEmailCode() {
    if (_emailCtrl.text.isEmpty) return;

    context.read<AuthBloc>().add(SendCodeEvent(email: _emailCtrl.text));
    _startEmailTimer();
  }

  // ============================================================
  // "Отправка кода на телефон"
  // ============================================================
  void _sendPhoneCode() {
    if (_phoneCtrl.text.isEmpty) return;

    context.read<AuthBloc>().add(
      SendCodeEvent(email: _phoneCtrl.text),
    );
    _startPhoneTimer();
  }

  // ============================================================
  // "Запуск таймера для email"
  // ============================================================
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

  // ============================================================
  // "Запуск таймера для телефона"
  // ============================================================
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

  // ============================================================
  // "Верификация введенного кода"
  // ============================================================
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

    context.read<AuthBloc>().add(VerifyEmailEvent(email: email, code: code));
  }

  // ============================================================
  // "Форматирование времени для отображения"
  // ============================================================
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
                              SizedBox(width: 0),
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

// ============================================================
// "Поле ввода кода верификации"
// ============================================================
class _CodeField extends StatelessWidget {
  final TextEditingController controller;

  const _CodeField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _Labeled(
      label: 'Пороль',
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

// ============================================================
// "Поле с кнопкой отправки кода"
// ============================================================
class _SendCodeField extends StatelessWidget {
  final String label;

  final String hint;

  final TextEditingController controller;

  final TextInputType keyboard;

  final bool canSend;

  final VoidCallback onSend;

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

// ============================================================
// "Текст отображения времени до повторной отправки"
// ============================================================
class _CooldownText extends StatelessWidget {
  final bool visible;

  final String text;

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

// ============================================================
// "Обертка с меткой для полей формы"
// ============================================================
class _Labeled extends StatelessWidget {
  final String label;

  final Widget child;

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

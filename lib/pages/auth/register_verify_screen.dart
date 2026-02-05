import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'sign_in_screen.dart';

// ============================================================
// "Экран верификации email при регистрации"
// ============================================================
class RegisterVerifyScreen extends StatefulWidget {
  static const routeName = '/register-verify';

  final String? email;

  const RegisterVerifyScreen({super.key, this.email});

  @override
  State<RegisterVerifyScreen> createState() => _RegisterVerifyScreenState();
}

// ============================================================
// "Состояние экрана верификации с таймерами"
// ============================================================
class _RegisterVerifyScreenState extends State<RegisterVerifyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _codeCtrl = TextEditingController();

  late String _email = '';

  static const _cooldown = Duration(seconds: 40);

  Timer? _resendTimer;

  Duration _resendLeft = Duration.zero;

  bool _canResendCode = false;

  @override
  void initState() {
    super.initState();
    // Получаем email из конструктора или из параметров маршрута
    if (widget.email != null && widget.email!.isNotEmpty) {
      _email = widget.email!;
    } else {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _email = args?['email'] ?? '';
    }

    // Отправляем код автоматически при открытии экрана
    if (_email.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.read<AuthBloc>().add(SendCodeEvent(email: _email));
        }
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // "Отправка кода повторно"
  // ============================================================
  void _resendCode() {
    if (_email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email не найден')));
      return;
    }

    context.read<AuthBloc>().add(SendCodeEvent(email: _email));
    _startResendTimer();
  }

  // ============================================================
  // "Запуск таймера для блокировки повторной отправки"
  // ============================================================
  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendLeft = _cooldown;
      _canResendCode = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendLeft.inSeconds <= 1) {
        t.cancel();
        setState(() => _resendLeft = Duration.zero);
      } else {
        setState(() => _resendLeft -= const Duration(seconds: 1));
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

    if (_email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email не найден')));
      return;
    }

    context.read<AuthBloc>().add(VerifyEmailEvent(email: _email, code: code));
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
          // Активируем кнопку "Отправить код повторно" при ошибке
          setState(() => _canResendCode = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: CustomErrorSnackBar(
                message: state.message,
                onClose: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
              backgroundColor: primaryBackground,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: primaryBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Header(),
                    const SizedBox(height: 10),
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
                                color: Color.fromARGB(255, 248, 248, 248),
                              ),
                              SizedBox(width: 0),
                              Text(
                                'Подтверждение пароля',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 249, 249, 250),
                                  fontSize: 20,
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

                    const SizedBox(height: 10),
                    const Text(
                      'Введите код с письма на электронной почте или смс на телефоне',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 9),

                    _CodeField(
                      controller: _codeCtrl,
                      canSend: _canResendCode && _resendLeft == Duration.zero,
                      onSend: _resendCode,
                    ),

                    _CooldownText(
                      visible: _resendLeft > Duration.zero,
                      text: _fmt(_resendLeft),
                    ),

                    SizedBox(
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
                    const SizedBox(height: 17),
                    const Text(
                      'На вашу почту или номер телефона был отправлен код',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// "Поле ввода кода верификации с кнопкой отправки повторно"
// ============================================================
class _CodeField extends StatelessWidget {
  final TextEditingController controller;

  final bool canSend;

  final VoidCallback onSend;

  const _CodeField({
    required this.controller,
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
        child: const Text(
          'Отправить код повторно',
          style: TextStyle(fontSize: 11),
        ),
      ),
    );

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Код с письма или смс',
        hintStyle: const TextStyle(color: textMuted),
        filled: true,
        fillColor: secondaryBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          // vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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

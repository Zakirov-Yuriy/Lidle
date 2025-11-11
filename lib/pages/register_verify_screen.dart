/// Страница верификации регистрации.
/// Пользователь вводит код, отправленный на его электронную почту или телефон,
/// для завершения процесса регистрации.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

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
  /// Контроллер для текстового поля "Пароль".
  final _passwordCtrl = TextEditingController();
  /// Контроллер для текстового поля "Электронная почта".
  final _emailCtrl = TextEditingController();
  /// Контроллер для текстового поля "Телефон".
  final _phoneCtrl = TextEditingController();

  /// Флаг для отображения/скрытия текста в поле "Пароль".
  bool _showPassword = false;

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
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _emailTimer?.cancel();
    _phoneTimer?.cancel();
    super.dispose();
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

  /// Форматирует объект [Duration] в строку "MM:SS".
  /// [d] - объект Duration для форматирования.
  /// Возвращает отформатированную строку.
  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '00:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 60, top: 44),
                  child: Row(
                    children: [
                      Image.asset(logoAsset, height: logoHeight),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: 38),

                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.maybePop(context),
                      borderRadius: BorderRadius.circular(24),
                      child: const Row(
                        children: [
                          Icon(Icons.chevron_left, color: Color(0xFF60A5FA)),
                          SizedBox(width: 8),
                          Text('Назад',
                              style: TextStyle(
                                  color: Color(0xFF60A5FA), fontSize: 16)),
                        ],
                      ),
                    ),
                    const Spacer(),
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
                const SizedBox(height: 52),

                const Text(
                  'Регистрация в LIDLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Введите номер телефона или электронную почту\nдля отправки кода',
                  style: TextStyle(color: textSecondary, fontSize: 16, height: 1.3),
                ),
                const SizedBox(height: 17),

                _PasswordField(
                  controller: _passwordCtrl,
                  show: _showPassword,
                  onToggle: () => setState(() => _showPassword = !_showPassword),
                ),
                const SizedBox(height: 18),

                _SendCodeField(
                  label: 'Электронная почта',
                  hint: 'Введите почту',
                  controller: _emailCtrl,
                  keyboard: TextInputType.emailAddress,
                  canSend: _emailLeft == Duration.zero,
                  onSend: _startEmailTimer,
                ),
                const SizedBox(height: 8),
                _CooldownText(
                  visible: _emailLeft > Duration.zero,
                  text: _fmt(_emailLeft),
                ),
                const SizedBox(height: 17),

                _SendCodeField(
                  label: 'Телефон',
                  hint: 'Введите телефон',
                  controller: _phoneCtrl,
                  keyboard: TextInputType.phone,
                  canSend: _phoneLeft == Duration.zero,
                  onSend: _startPhoneTimer,
                ),
                const SizedBox(height: 8),
                _CooldownText(
                  visible: _phoneLeft > Duration.zero,
                  text: _fmt(_phoneLeft),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: Builder(
        builder: (context) {
          final insets = MediaQuery.of(context).viewInsets.bottom;
          final safe = MediaQuery.of(context).padding.bottom;
          final bottomOffset = (insets > 0) ? insets + 16 : 66 + safe;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(32, 12, 32, bottomOffset),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: () {
                  },
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Приватный виджет `_PasswordField` для отображения поля ввода пароля.
/// Включает метку, текстовое поле с возможностью скрытия/отображения текста
/// и стилизацию.
class _PasswordField extends StatelessWidget {
  /// Контроллер для управления текстом в поле.
  final TextEditingController controller;
  /// Флаг, указывающий, виден ли текст пароля.
  final bool show;
  /// Callback-функция для переключения видимости пароля.
  final VoidCallback onToggle;

  /// Конструктор для `_PasswordField`.
  const _PasswordField({
    required this.controller,
    required this.show,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _Labeled(
      label: 'Пароль',
      child: TextField(
        controller: controller,
        obscureText: !show,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Введите пароль',
          hintStyle:
              const TextStyle(color: textMuted),
          filled: true,
          fillColor: secondaryBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide.none,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              show ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70,
            ),
            onPressed: onToggle,
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
          foregroundColor:
              canSend ? activeIconColor : Colors.white38,
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
          hintStyle:
              const TextStyle(color: textMuted),
          filled: true,
          fillColor: secondaryBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide.none,
          ),
          suffixIcon: suffix,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
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
        style: const TextStyle(
            fontSize: 14, color: textSecondary),
        children: [
          const TextSpan(text: 'Осталось: '),
          TextSpan(
            text: text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
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
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// Страница для установки нового пароля после успешного восстановления аккаунта.
/// Пользователь вводит и подтверждает новый пароль.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/auth_service.dart';

/// `AccountRecoveryNewPassword` - это StatefulWidget, который позволяет пользователю
/// установить новый пароль для своего аккаунта.
class AccountRecoveryNewPassword extends StatefulWidget {
  /// Именованный маршрут для этой страницы.
  static const routeName = '/account-recovery-new-password';

  /// Конструктор для `AccountRecoveryNewPassword`.
  const AccountRecoveryNewPassword({super.key});

  @override
  State<AccountRecoveryNewPassword> createState() =>
      _AccountRecoveryNewPasswordState();
}

/// Состояние для виджета `AccountRecoveryNewPassword`.
class _AccountRecoveryNewPasswordState
    extends State<AccountRecoveryNewPassword> {
  /// Контроллер для текстового поля "Новый пароль".
  final _newCtrl = TextEditingController();

  /// Контроллер для текстового поля "Повторите пароль".
  final _repeatCtrl = TextEditingController();

  /// Флаг для отображения/скрытия текста в поле "Новый пароль".
  bool _showNew = false;

  /// Флаг для отображения/скрытия текста в поле "Повторите пароль".
  bool _showRepeat = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _repeatCtrl.dispose();
    super.dispose();
  }

  /// Обработчик нажатия кнопки "Подтвердить".
  /// Выполняет валидацию введенных паролей и отправляет их на сервер.
  Future<void> _submit() async {
    final newPass = _newCtrl.text.trim();
    final repPass = _repeatCtrl.text.trim();

    String? error;
    if (newPass.isEmpty || repPass.isEmpty) {
      error = 'Заполните оба поля';
    } else if (newPass.length < 6) {
      error = 'Минимальная длина пароля — 6 символов';
    } else if (newPass != repPass) {
      error = 'Пароли не совпадают';
    }

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    final email = args['email']!;
    final token = args['token']!;

    try {
      await AuthService.resetPassword(
        email: email,
        password: newPass,
        passwordConfirmation: repPass,
        token: token,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пароль обновлён')));
      Navigator.of(context).pushReplacementNamed('/sign-in');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 41, bottom: 37),
                child: Row(
                  children: [
                    SvgPicture.asset(logoAsset, height: logoHeight),
                    const Spacer(),
                  ],
                ),
              ),

              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.maybePop(context),
                    child: Icon(
                      Icons.chevron_left,
                      color: textPrimary,
                      size: 28,
                    ),
                  ),

                  Expanded(
                    child: Text(
                      'Восстановление пароля',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF60A5FA),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                      ),
                    ),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Введите ваш новый пароль',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 9),

              _PasswordField(
                label: 'Новый пароль',
                controller: _newCtrl,
                visible: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
              ),
              const SizedBox(height: 10),

              _PasswordField(
                label: 'Повторите пароль',
                controller: _repeatCtrl,
                visible: _showRepeat,
                onToggle: () => setState(() => _showRepeat = !_showRepeat),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeIconColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  child: const Text('Подтвердить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Приватный виджет `_PasswordField` для отображения поля ввода пароля.
/// Включает текстовое поле с возможностью скрытия/отображения текста
/// и стилизацию в соответствии с макетом.
class _PasswordField extends StatelessWidget {
  /// Метка для текстового поля (например, "Новый пароль").
  final String label;

  /// Контроллер для управления текстом в поле.
  final TextEditingController controller;

  /// Флаг, указывающий, виден ли текст пароля.
  final bool visible;

  /// Callback-функция для переключения видимости пароля.
  final VoidCallback onToggle;

  /// Конструктор для `_PasswordField`.
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.visible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: Colors.white70,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: textMuted),
        isDense: true,
        filled: true,
        fillColor: formBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

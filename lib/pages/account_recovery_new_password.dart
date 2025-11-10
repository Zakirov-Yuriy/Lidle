import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class AccountRecoveryNewPassword extends StatefulWidget {
  static const routeName = '/account-recovery-new-password';

  const AccountRecoveryNewPassword({super.key});

  @override
  State<AccountRecoveryNewPassword> createState() =>
      _AccountRecoveryNewPasswordState();
}

class _AccountRecoveryNewPasswordState
    extends State<AccountRecoveryNewPassword> {
  final _newCtrl = TextEditingController();
  final _repeatCtrl = TextEditingController();

  bool _showNew = false;
  bool _showRepeat = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _repeatCtrl.dispose();
    super.dispose();
  }

  void _submit() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    // TODO: отправить новый пароль на сервер
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Пароль обновлён')),
    );
    Navigator.maybePop(context);
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
              // Логотип
              Padding(
                padding: const EdgeInsets.only(left: 45),
                child: Row(
                  children: [
                    Image.asset(logoAsset, height: logoHeight),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Хедер
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.maybePop(context),
                    child:
                        Icon(Icons.chevron_left, color: textPrimary, size: 28),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Восстановление пароля',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF60A5FA),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w400, fontSize: 16),
                    ),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Подзаголовок
              Text(
                'Введите ваш новый пароль',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              // Поле "Новый пароль"
              _PasswordField(
                label: 'Новый пароль',
                controller: _newCtrl,
                visible: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
              ),
              const SizedBox(height: 12),

              // Поле "Повторите пароль"
              _PasswordField(
                label: 'Повторите пароль',
                controller: _repeatCtrl,
                visible: _showRepeat,
                onToggle: () => setState(() => _showRepeat = !_showRepeat),
              ),
              const SizedBox(height: 16),

              // Кнопка "Подтвердить"
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _submit, // активна всегда
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeIconColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w400),
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

/// Поле пароля, как в макете (тёмное, с иконкой-глазом)
class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool visible;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.visible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: !visible,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: Colors.white70,
          decoration: InputDecoration(
            hintText: label, // как на скрине — тот же текст в hint
            hintStyle: const TextStyle(color: textMuted),
            isDense: true,
            filled: true,
            fillColor: formBackground, // Use the new form background color
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ),
      ],
    );
  }
}

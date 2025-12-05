import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_bloc.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_state.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_event.dart';

// ============================================================
// "Экран установки нового пароля"
// ============================================================
class AccountRecoveryNewPassword extends StatefulWidget {
  static const routeName = '/account-recovery-new-password';

  const AccountRecoveryNewPassword({super.key});

  @override
  State<AccountRecoveryNewPassword> createState() =>
      _AccountRecoveryNewPasswordState();
}

// ============================================================
// "Состояние экрана установки нового пароля"
// ============================================================
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

  // ============================================================
  // "Валидация и отправка нового пароля"
  // ============================================================
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
        SnackBar(
          content: CustomErrorSnackBar(
            message: error,
            onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
          backgroundColor: primaryBackground,
        ),
      );
      return;
    }

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    final email = args['email']!;
    final token = args['token']!;

    context.read<PasswordRecoveryBloc>().add(
      ResetPasswordEvent(
        email: email,
        password: newPass,
        passwordConfirmation: repPass,
        token: token,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<PasswordRecoveryBloc, PasswordRecoveryState>(
      listener: (context, state) {
        if (state is PasswordResetSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пароль обновлён')),
          );
          Navigator.of(context).pushReplacementNamed('/sign-in');
        } else if (state is PasswordRecoveryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: CustomErrorSnackBar(
                message: 'Ой, что-то пошло не так. Пожалуйста, попробуй ещё раз.',
                onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
              backgroundColor: primaryBackground,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
      backgroundColor: primaryBackground,
      body:SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical:28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              

              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(50),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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
              const SizedBox(height: 17),

              Text(
                'Введите ваш новый пароль',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 14),

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
              const SizedBox(height: 16),

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
      },
    );
  }
}

// ============================================================
// "Виджет поля пароля с переключением видимости"
// ============================================================
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

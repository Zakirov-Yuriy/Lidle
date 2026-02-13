import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_bloc.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_state.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_event.dart';
import 'account_recovery_code.dart';

// ============================================================
// "Экран восстановления пароля"
// ============================================================
class AccountRecovery extends StatelessWidget {
  static const routeName = '/account-recovery';

  const AccountRecovery({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PasswordRecoveryBloc, PasswordRecoveryState>(
      listener: (context, state) {
        if (state is RecoveryCodeSent) {
          Navigator.of(context).pushNamed(
            AccountRecoveryCode.routeName,
            arguments: {'email': state.email},
          );
        } else if (state is PasswordRecoveryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: CustomErrorSnackBar(
                message:
                    'Ой, что-то пошло не так. Пожалуйста, попробуй ещё раз.',
                onClose: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
              backgroundColor: primaryBackground,
            ),
          );
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);

        final isLoading = state is PasswordRecoveryLoading;
        final isProfileNotFound = state is ProfileNotFound;

        final subtitle = isProfileNotFound
            ? 'Введенный номер телефона или электронная\nпочта не найдена'
            : 'Для восстановления пароля введите номер\nтелефона или почту';

        const errorFill = Color(0xFF3A2020);
        const errorHint = Color(0xFFFF7272);
        final fill = isProfileNotFound ? errorFill : secondaryBackground;
        final hintColor = isProfileNotFound ? errorHint : textMuted;

        return Scaffold(
          backgroundColor: primaryBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 28),
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
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textSecondary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 15),

                  _RecoveryForm(
                    isLoading: isLoading,
                    isProfileNotFound: isProfileNotFound,
                    fill: fill,
                    hintColor: hintColor,
                  ),

                  const SizedBox(height: 12),

                  if (isProfileNotFound)
                    const Text(
                      'Профиля с этим номером или почтой не\nсуществует. Проверьте, нет ли ошибки.',
                      style: TextStyle(
                        color: Color(0xFFFF5A5A),
                        fontSize: 14,
                        height: 1.35,
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
// "Форма восстановления пароля"
// ============================================================
class _RecoveryForm extends StatefulWidget {
  final bool isLoading;
  final bool isProfileNotFound;
  final Color fill;
  final Color hintColor;

  const _RecoveryForm({
    required this.isLoading,
    required this.isProfileNotFound,
    required this.fill,
    required this.hintColor,
  });

  @override
  State<_RecoveryForm> createState() => _RecoveryFormState();
}

// ============================================================
// "Состояние формы восстановления пароля"
// ============================================================
class _RecoveryFormState extends State<_RecoveryForm> {
  final _controller = TextEditingController();
  bool _isValid = false;
  bool _isSubmitting = false; // Флаг для защиты от повторных нажатий

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_RecoveryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Сброс флага при завершении загрузки (состояние isLoading изменилось с true на false)
    if (oldWidget.isLoading && !widget.isLoading && _isSubmitting) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // "Валидация email или номера телефона"
  // ============================================================
  bool _isEmailOrPhone(String v) {
    final email = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    final digits = v.replaceAll(RegExp(r'\D'), '');
    final isPhone = RegExp(r'^\d{10,15}$').hasMatch(digits);
    return email.hasMatch(v) || isPhone;
  }

  void _onInputChanged(String v) {
    setState(() {
      _isValid = _isEmailOrPhone(v.trim());
    });
  }

  // ============================================================
  // "Отправка запроса на восстановление пароля"
  // ============================================================
  void _submit() {
    // Защита от повторных нажатий
    if (_isSubmitting || widget.isLoading) {
      return;
    }

    final input = _controller.text.trim();

    if (input.isEmpty || !_isValid) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    context.read<PasswordRecoveryBloc>().add(SendRecoveryCodeEvent(input));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          onChanged: _onInputChanged,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: Colors.white70,
          decoration: InputDecoration(
            hintText: 'Номер телефона или почта',
            hintStyle: TextStyle(color: widget.hintColor),
            isDense: true,
            filled: true,
            fillColor: widget.fill,
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
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 53,
          child: ElevatedButton(
            onPressed: (_isSubmitting || widget.isLoading) ? null : _submit,
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
            child: (_isSubmitting || widget.isLoading)
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Продолжить'),
          ),
        ),
      ],
    );
  }
}

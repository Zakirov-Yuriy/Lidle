/// Страница для ввода кода восстановления аккаунта.
/// Пользователь вводит код, полученный по электронной почте или SMS,
/// для продолжения процесса восстановления пароля.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_bloc.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_state.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_event.dart';
import 'package:lidle/pages/account_recovery_new_password.dart';

/// `AccountRecoveryCode` - это StatefulWidget, который позволяет пользователю
/// ввести код для восстановления аккаунта.
class AccountRecoveryCode extends StatefulWidget {
  /// Именованный маршрут для этой страницы.
  static const routeName = '/account-recovery-code';

  /// Конструктор для `AccountRecoveryCode`.
  const AccountRecoveryCode({super.key});

  @override
  State<AccountRecoveryCode> createState() => _AccountRecoveryCodeState();
}

/// Состояние для виджета `AccountRecoveryCode`.
class _AccountRecoveryCodeState extends State<AccountRecoveryCode> {
  /// Контроллер для текстового поля ввода кода.
  final _codeCtrl = TextEditingController();

  /// Флаг загрузки для кнопки повторной отправки.
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Автоматически отправляем код при входе на страницу
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendEmailCode();
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Отправляет код на электронную почту через BLoC.
  void _sendEmailCode() {
    if (_isResending) return;

    setState(() => _isResending = true);

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    final email = args['email']!;

    context.read<PasswordRecoveryBloc>().add(SendRecoveryCodeEvent(email));

    // Сброс флага через некоторое время
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isResending = false);
      }
    });
  }

  /// Обработчик нажатия кнопки "Продолжить".
  /// Отправляет событие верификации кода через BLoC.
  void _submit() {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите код')),
      );
      return;
    }
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    final email = args['email']!;

    context.read<PasswordRecoveryBloc>().add(
      VerifyRecoveryCodeEvent(email: email, code: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<PasswordRecoveryBloc, PasswordRecoveryState>(
      listener: (context, state) {
        if (state is RecoveryCodeSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Код отправлен на email')),
          );
        } else if (state is PasswordRecoveryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${state.message}')),
          );
        } else if (state is RecoveryCodeVerified) {
          // Переход на страницу нового пароля
          Navigator.of(context).pushNamed(
            AccountRecoveryNewPassword.routeName,
            arguments: {'email': state.email, 'token': state.token},
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
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

              const SizedBox(height: 16),
              Text(
                'Введите код с письма на  электронной почте или смс на телефоне',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: Colors.white70,
                decoration: InputDecoration(
                  hintText: 'Код с письма или смс',
                  hintStyle: const TextStyle(color: textMuted),
                  isDense: true,
                  filled: true,
                  fillColor: secondaryBackground,
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
                    borderSide: const BorderSide(
                      color: Color(0xFF334155),
                      width: 1,
                    ),
                  ),
                ),
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
                  child: const Text('Продолжить'),
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'На вашу почту или номер телефона был\nотправлен код',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 40,
                child: TextButton(
                  onPressed: _isResending ? null : _sendEmailCode,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF60A5FA),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  child: _isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
                          ),
                        )
                      : const Text('Отправить код повторно'),
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

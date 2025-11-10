import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/account_recovery_new_password.dart';

class AccountRecoveryCode extends StatefulWidget {
  static const routeName = '/account-recovery-code';

  const AccountRecoveryCode({super.key});

  @override
  State<AccountRecoveryCode> createState() => _AccountRecoveryCodeState();
}

class _AccountRecoveryCodeState extends State<AccountRecoveryCode> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    // TODO: сюда вашу проверку кода
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Проверяем код...')),
    );
    Navigator.of(context).pushNamed(AccountRecoveryNewPassword.routeName);
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
              // Верхняя строка с логотипом (как в остальных экранах)
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

              // Хедер: назад + заголовок + "Отмена"
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.maybePop(context),
                    child: Icon(Icons.chevron_left, color: textPrimary, size: 28),
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
                      textStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
                    ),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Подзаголовок
              Text(
                'Введите код с письма на  электронной почте или\nсмс на телефоне',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textSecondary,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              // Поле "Код с письма или смс"
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6), // при желании поменяйте длину
                ],
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: Colors.white70,
                decoration: InputDecoration(
                  hintText: 'Код с письма или смс',
                  hintStyle: const TextStyle(color: textMuted),
                  isDense: true,
                  filled: true,
                  fillColor: secondaryBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

              // Кнопка "Продолжить"
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _submit, // кнопка активна всегда — как в ваших требованиях
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeIconColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  child: const Text('Продолжить'),
                ),
              ),
              const SizedBox(height: 17),

              // Информационный текст
              const Text(
                'На вашу почту или номер телефона был\nотправлен код',
                style: TextStyle(color: Colors.white, fontSize: 16, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

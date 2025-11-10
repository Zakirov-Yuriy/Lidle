import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/account_recovery_code.dart';

class AccountRecovery extends StatefulWidget {
  static const routeName = '/account-recovery';

  const AccountRecovery({super.key});

  @override
  State<AccountRecovery> createState() => _AccountRecoveryState();
}

class _AccountRecoveryState extends State<AccountRecovery> {
  final _controller = TextEditingController();

  bool _isValid = false;     // валиден формат email/телефона
  bool _notFound = false;    // состояние «профиль не найден»

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // простая проверка email/телефона
  bool _isEmailOrPhone(String v) {
    final email = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    final digits = v.replaceAll(RegExp(r'\D'), '');
    final isPhone = RegExp(r'^\d{10,15}$').hasMatch(digits);
    return email.hasMatch(v) || isPhone;
  }

  void _onInputChanged(String v) {
    setState(() {
      _isValid = _isEmailOrPhone(v.trim());
      // как только пользователь правит ввод — уходим из режима «не найдено»
      _notFound = false;
    });
  }

  Future<void> _submit() async {
  final input = _controller.text.trim();

  // Если поле пустое — сразу показываем сообщение об ошибке
  if (input.isEmpty) {
    setState(() {
      _notFound = true;
    });
    return;
  }

  // Проверяем формат (телефон или почта)
  _isValid = _isEmailOrPhone(input);

  // Если формат неверный — тоже показываем ошибку
  if (!_isValid) {
    setState(() {
      _notFound = true;
    });
    return;
  }

  // TODO: здесь вызывайте ваш бэкенд.
  // Пример: final exists = await api.checkUser(input);
  // Для демо — эмулируем «не найдено»
  final exists = true;

  setState(() {
    _notFound = !exists;
  });

  if (exists) {
    // переход на следующий шаг восстановления
    if (!mounted) return;
    Navigator.of(context).pushNamed(AccountRecoveryCode.routeName);
  }
}


  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);

  final subtitle = _notFound
      ? 'Введенный номер телефона или электронная\nпочта не найдена'
      : 'Для восстановления пароля введите номер\nтелефона или почту';

  // Цвета при ошибке
  const errorFill = Color(0xFF3A2020); // фон поля
  const errorHint = Color(0xFFFF7272); // цвет hint при ошибке
  final fill = _notFound ? errorFill : secondaryBackground;
  final hintColor = _notFound ? errorHint : textMuted;

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
            const SizedBox(height: 37),

            // шапка
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.maybePop(context),
                  child: Icon(Icons.chevron_left, color: textPrimary, size: 28),
                ),
                const SizedBox(width: 11),
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
            const SizedBox(height: 16),

            // подзаголовок / сообщение об ошибке
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textSecondary,
                fontSize: 16,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),

            // поле ввода
            TextField(
              controller: _controller,
              onChanged: _onInputChanged,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.white70,
              decoration: InputDecoration(
                hintText: 'Номер телефона или почта',
                hintStyle: TextStyle(color: hintColor), // 👈 меняем цвет hint
                isDense: true,
                filled: true,
                fillColor: fill, // 👈 цвет фона в зависимости от ошибки
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide:
                      const BorderSide(color: Color(0xFF334155), width: 1),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // кнопка
            SizedBox(
              width: double.infinity,
              height: 53,
              child: ElevatedButton(
                onPressed: _submit, // всегда активна
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeIconColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w400),
                ),
                child: const Text('Продолжить'),
              ),
            ),

            const SizedBox(height: 12),

            // нижний красный текст
            if (_notFound)
              const Text(
                'Профиля с этим номером или почтой не\nсуществует. Проверьте, нет ли ошибки.',
                style: TextStyle(
                    color: Color(0xFFFF5A5A), fontSize: 14, height: 1.35),
              ),
          ],
        ),
      ),
    ),
  );
}
}

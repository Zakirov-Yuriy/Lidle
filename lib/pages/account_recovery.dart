/// Страница восстановления аккаунта.
/// Пользователь вводит свой номер телефона или адрес электронной почты
/// для начала процесса восстановления пароля.
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/account_recovery_code.dart';

/// `AccountRecovery` - это StatefulWidget, который управляет состоянием
/// ввода данных для восстановления аккаунта.
class AccountRecovery extends StatefulWidget {
  /// Именованный маршрут для этой страницы.
  static const routeName = '/account-recovery';

  /// Конструктор для `AccountRecovery`.
  const AccountRecovery({super.key});

  @override
  State<AccountRecovery> createState() => _AccountRecoveryState();
}

/// Состояние для виджета `AccountRecovery`.
class _AccountRecoveryState extends State<AccountRecovery> {
  /// Контроллер для текстового поля ввода номера телефона или почты.
  final _controller = TextEditingController();

  /// Флаг, указывающий, валиден ли формат введенных данных (email/телефон).
  bool _isValid = false;
  /// Флаг, указывающий, найден ли профиль пользователя.
  bool _notFound = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Простая функция для проверки формата введенной строки на соответствие
  /// email или номеру телефона.
  /// [v] - строка для проверки.
  /// Возвращает `true`, если строка соответствует формату email или телефона, иначе `false`.
  bool _isEmailOrPhone(String v) {
    final email = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    final digits = v.replaceAll(RegExp(r'\D'), '');
    final isPhone = RegExp(r'^\d{10,15}$').hasMatch(digits);
    return email.hasMatch(v) || isPhone;
  }

  /// Обработчик изменения текста в поле ввода.
  /// Обновляет состояние валидности ввода и сбрасывает флаг `_notFound`.
  /// [v] - текущее значение текстового поля.
  void _onInputChanged(String v) {
    setState(() {
      _isValid = _isEmailOrPhone(v.trim());
      _notFound = false;
    });
  }

  /// Обработчик нажатия кнопки "Продолжить".
  /// Выполняет валидацию ввода и эмулирует проверку пользователя на бэкенде.
  Future<void> _submit() async {
    final input = _controller.text.trim();

    if (input.isEmpty) {
      setState(() {
        _notFound = true;
      });
      return;
    }

    _isValid = _isEmailOrPhone(input);

    if (!_isValid) {
      setState(() {
        _notFound = true;
      });
      return;
    }

    final exists = true;

    setState(() {
      _notFound = !exists;
    });

    if (exists) {
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

    const errorFill = Color(0xFF3A2020);
    const errorHint = Color(0xFFFF7272);
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

              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textSecondary,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _controller,
                onChanged: _onInputChanged,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: Colors.white70,
                decoration: InputDecoration(
                  hintText: 'Номер телефона или почта',
                  hintStyle: TextStyle(color: hintColor),
                  isDense: true,
                  filled: true,
                  fillColor: fill,
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
                        borderRadius: BorderRadius.circular(5)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  child: const Text('Продолжить'),
                ),
              ),

              const SizedBox(height: 12),

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

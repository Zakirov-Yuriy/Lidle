import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class AccountRecovery extends StatelessWidget {
  static const routeName = '/account-recovery';

  const AccountRecovery({super.key});

  // Цвета, подобранные под макет
  static const Color _bg = Color(0xFF1F2A33);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF9CA3AF);
  static const Color _fieldFill = Color(0xFF12171D);
  static const Color _primary = Color(0xFF0EA5E9); // синий для кнопки

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Логотип
              Padding(
                padding: const EdgeInsets.only(left: 41.0),
                child: Row(
                  children: [
                    Image.asset(logoAsset, height: logoHeight),
                    const Spacer(),
                  ],
                ),
              ),

              const SizedBox(height: 37),

              // Кастомный app bar: стрелка назад, заголовок и "Отмена"
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.maybePop(context),
                    child: Icon(
                      Icons.chevron_left,
                      color: _textPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Восстановление пароля',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 24
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

              const SizedBox(height: 16),

              // Подсказка
              Text(
                'Для восстановления пароля введите номер\nтелефона или почту',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _textSecondary,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 10),

              // Поле ввода
              _RecoveryField(),

              const SizedBox(height: 16),

              // Кнопка Продолжить
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: обработка нажатия (отправка коду/переход)
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryField extends StatefulWidget {
  @override
  State<_RecoveryField> createState() => _RecoveryFieldState();
}

class _RecoveryFieldState extends State<_RecoveryField> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: Colors.white70,
      decoration: InputDecoration(
        hintText: 'Номер телефона или почта',
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        isDense: true,
        filled: true,
        fillColor: AccountRecovery._fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(5),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}

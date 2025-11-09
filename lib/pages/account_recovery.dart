import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class AccountRecovery extends StatefulWidget {
  static const routeName = '/account-recovery';

  const AccountRecovery({super.key});

  @override
  State<AccountRecovery> createState() => _AccountRecoveryState();
}

class _AccountRecoveryState extends State<AccountRecovery> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isValid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateInput(String? value) {
    if (value == null || value.isEmpty) {
      return 'Поле не может быть пустым';
    }

    // Проверка на email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (emailRegex.hasMatch(value)) {
      return null; // Валидный email
    }

    // Проверка на телефон (простая: только цифры, длина 10-15)
    final phoneRegex = RegExp(r'^\d{10,15}$');
    if (phoneRegex.hasMatch(value.replaceAll(RegExp(r'\D'), ''))) {
      return null; // Валидный телефон
    }

    return 'Введите корректный email или номер телефона';
  }

  void _onInputChanged() {
    setState(() {
      _isValid = _formKey.currentState?.validate() ?? false;
    });
  }

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

              // Форма с полем ввода
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _controller,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: Colors.white70,
                  decoration: InputDecoration(
                    hintText: 'Номер телефона или почта',
                    hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                    isDense: true,
                    filled: true,
                    fillColor: _fieldFill,
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
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red, width: 1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red, width: 1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: _validateInput,
                  onChanged: (_) => _onInputChanged(),
                ),
              ),

              const SizedBox(height: 16),

              // Кнопка Продолжить
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _isValid ? () {
                    // Логика обработки: валидация формы и переход
                    if (_formKey.currentState?.validate() ?? false) {
                      // TODO: отправка запроса на восстановление пароля
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Запрос на восстановление отправлен')),
                      );
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValid ? _primary : Colors.grey,
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

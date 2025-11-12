/// Страница регистрации нового пользователя.
/// Позволяет пользователю ввести свои данные, установить пароль
/// и согласиться с условиями использования.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/custom_checkbox.dart';
import 'package:lidle/services/auth_service.dart';
import 'register_verify_screen.dart';

/// `RegisterScreen` - это StatefulWidget, который управляет состоянием
/// формы регистрации пользователя.
class RegisterScreen extends StatefulWidget {
  /// Именованный маршрут для этой страницы.
  static const routeName = '/register';

  /// Конструктор для `RegisterScreen`.
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// Состояние для виджета `RegisterScreen`.
class _RegisterScreenState extends State<RegisterScreen> {
  /// Флаг согласия с условиями пользовательского соглашения и политики конфиденциальности.
  bool agreeTerms = false;

  /// Флаг согласия на рекламную и информационную рассылку.
  bool agreeMarketing = false;

  /// Флаг для отображения/скрытия текста в поле "Пароль".
  bool showPassword = false;

  /// Флаг для отображения/скрытия текста в поле "Повторите пароль".
  bool showRepeatPassword = false;

  /// Глобальный ключ для управления состоянием формы.
  final _formKey = GlobalKey<FormState>();

  /// Контроллер для текстового поля "Пароль".
  final _passwordController = TextEditingController();

  /// Контроллер для текстового поля "Повторите пароль".
  final _repeatPasswordController = TextEditingController();

  /// Контроллер для текстового поля "Имя".
  final _nameController = TextEditingController();

  /// Контроллер для текстового поля "Фамилия".
  final _surnameController = TextEditingController();

  /// Контроллер для текстового поля "Email".
  final _emailController = TextEditingController();

  /// Контроллер для текстового поля "Телефон".
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Обработчик нажатия кнопки "Войти" (или "Зарегистрироваться").
  /// Выполняет валидацию формы, отправляет данные на сервер и переходит на страницу верификации.
  Future<void> _trySubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || !agreeTerms) return;

    try {
      await AuthService.register(
        name: _nameController.text.trim(),
        lastName: _surnameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim(),
        passwordConfirmation: _repeatPasswordController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushNamed(RegisterVerifyScreen.routeName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка регистрации: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0EA5E9);

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 41.0,
                    top: 44.0,
                    bottom: 35.0,
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(logoAsset, height: logoHeight),
                      const Spacer(),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(24),
                      child: const Row(
                        children: [
                          Icon(Icons.chevron_left, color: Color(0xFF60A5FA)),
                          Text(
                            'Назад',
                            style: TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF60A5FA),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Вы уже почти в LIDLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 11),
                const Text(
                  'Выберите способ входа',
                  style: TextStyle(color: textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Ваше имя',
                  'Введите',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите ваше имя';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  'Ваша фамилия',
                  'Введите',
                  controller: _surnameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите вашу фамилию';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  'Электронная почта',
                  'Введите',
                  controller: _emailController,
                  keyboard: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Пожалуйста, введите корректный email';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  'Ваш номер телефона',
                  'Введите',
                  controller: _phoneController,
                  keyboard: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.length < 10) {
                      return 'Пожалуйста, введите корректный номер телефона';
                    }
                    return null;
                  },
                ),
                _buildPasswordField('Пароль', 'Введите', true),
                _buildPasswordField('Повторите пароль', 'Введите', false),
                const SizedBox(height: 27),
                _buildCheckBox(
                  value: agreeTerms,
                  text: RichText(
                    text: const TextSpan(
                      text: 'Я соглашаюсь с ',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      children: [
                        TextSpan(
                          text: 'Пользовательским \nсоглашением ',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: 'и ',
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextSpan(
                          text: 'Политикой \nконфиденциальности',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onChanged: (v) => setState(() => agreeTerms = v ?? false),
                ),
                const SizedBox(height: 16),
                _buildCheckBox(
                  value: agreeMarketing,
                  text: RichText(
                    text: const TextSpan(
                      text: 'Я соглашаюсь на ',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      children: [
                        TextSpan(
                          text: 'Рекламную ',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: 'и ',
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextSpan(
                          text: '\nИнформационную рассылку',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onChanged: (v) => setState(() => agreeMarketing = v ?? false),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: agreeTerms ? _trySubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      disabledBackgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: const Text(
                      'Войти',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 77),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Приватный метод для построения текстового поля ввода.
  /// [label] - метка поля.
  /// [hint] - подсказка в поле ввода.
  /// [controller] - контроллер для поля.
  /// [keyboard] - тип клавиатуры.
  /// [validator] - функция валидации ввода.
  Widget _buildTextField(
    String label,
    String hint, {
    TextEditingController? controller,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboard,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: textMuted),
              filled: true,
              fillColor: secondaryBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Приватный метод для построения поля ввода пароля.
  /// [label] - метка поля.
  /// [hint] - подсказка в поле ввода.
  /// [isFirst] - флаг, указывающий, является ли это первым полем пароля (для контроллера).
  Widget _buildPasswordField(String label, String hint, bool isFirst) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: isFirst
                ? _passwordController
                : _repeatPasswordController,
            obscureText: isFirst ? !showPassword : !showRepeatPassword,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Пожалуйста, введите пароль';
              }
              if (isFirst) {
                if (value.length < 6) {
                  return 'Пароль должен быть не менее 6 символов';
                }
              } else {
                if (value != _passwordController.text) {
                  return 'Пароли не совпадают';
                }
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: textMuted),
              filled: true,
              fillColor: secondaryBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  (isFirst ? showPassword : showRepeatPassword)
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () => setState(() {
                  if (isFirst) {
                    showPassword = !showPassword;
                  } else {
                    showRepeatPassword = !showRepeatPassword;
                  }
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Приватный метод для построения чекбокса с текстом.
  /// [value] - текущее значение чекбокса.
  /// [text] - виджет текста, отображаемого рядом с чекбоксом.
  /// [onChanged] - callback-функция при изменении состояния чекбокса.
  Widget _buildCheckBox({
    required bool value,
    required Widget text,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomCheckbox(value: value, onChanged: onChanged),
        const SizedBox(width: 11),
        Expanded(child: text),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/custom_checkbox.dart';
import 'register_verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  static const routeName = '/register';

  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool agreeTerms = false;
  bool agreeMarketing = false;
  bool showPassword = false;
  bool showRepeatPassword = false;

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _trySubmit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (isValid && agreeTerms) {
      Navigator.of(context).pushNamed(RegisterVerifyScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0EA5E9);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Логотип
                Padding(
                  padding: const EdgeInsets.only(left: 60.0, top: 44.0),
                  child: Row(
                    children: [
                      Image.asset(logoAsset, height: logoHeight),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Row(
                        children: [
                          Icon(Icons.chevron_left, color: Color(0xFF60A5FA)),
                          SizedBox(width: 10),
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
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(' ', style: TextStyle(color: Colors.white)),
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
                const SizedBox(height: 25),
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

  Widget _buildTextField(
    String label,
    String hint, {
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
            keyboardType: keyboard,
            style: const TextStyle(color: Colors.white),
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
            controller: isFirst ? _passwordController : null,
            obscureText: isFirst ? !showPassword : !showRepeatPassword,
            style: const TextStyle(color: Colors.white),
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

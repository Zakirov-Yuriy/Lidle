import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'register_verify_screen.dart';

// ============================================================
// "Экран регистрации пользователя"
// ============================================================
class RegisterScreen extends StatefulWidget {
  static const routeName = '/register';

  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// ============================================================
// "Состояние экрана регистрации"
// ============================================================
class _RegisterScreenState extends State<RegisterScreen> {
  bool agreeTerms = false;

  bool agreeMarketing = false;

  bool showPassword = false;

  bool showRepeatPassword = false;

  final _formKey = GlobalKey<FormBuilderState>();

  // ============================================================
  // "Логика обработки отправки формы регистрации"
  // ============================================================
  void _trySubmit() {
    final formState = _formKey.currentState;
    final isValid = formState?.validate() ?? false;
    if (!isValid || !agreeTerms) return;

    formState?.save();
    final formData = formState?.value ?? {};

    context.read<AuthBloc>().add(RegisterEvent(
      name: (formData['name'] as String?)?.trim() ?? '',
      lastName: (formData['lastName'] as String?)?.trim() ?? '',
      email: (formData['email'] as String?)?.trim() ?? '',
      phone: (formData['phone'] as String?)?.trim() ?? '',
      password: (formData['password'] as String?)?.trim() ?? '',
      passwordConfirmation: (formData['passwordConfirmation'] as String?)?.trim() ?? '',
    ));
  }

  // ============================================================
  // "Метод построения интерфейса регистрации"
  // ============================================================
  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0EA5E9);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthRegistered) {
          Navigator.of(context).pushNamed(RegisterVerifyScreen.routeName);
        } else if (state is AuthError) {
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
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
            child: FormBuilder(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(24),
                          child: const Row(
                            children: [
                              Icon(Icons.chevron_left_rounded, color: Color(0xFF60A5FA)),
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

                    const Text(
                      'Введите личные данные',
                      style: TextStyle(color: textSecondary, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      'name',
                      'Ваше имя',
                      'Введите',
                      validators: [
                        FormBuilderValidators.required(errorText: 'Пожалуйста, введите ваше имя'),
                      ],
                    ),
                    _buildTextField(
                      'lastName',
                      'Ваша фамилия',
                      'Введите',
                      validators: [
                        FormBuilderValidators.required(errorText: 'Пожалуйста, введите вашу фамилию'),
                      ],
                    ),
                    _buildTextField(
                      'email',
                      'Электронная почта',
                      'Введите',
                      keyboard: TextInputType.emailAddress,
                      validators: [
                        FormBuilderValidators.required(errorText: 'Пожалуйста, введите email'),
                        FormBuilderValidators.email(errorText: 'Пожалуйста, введите корректный email'),
                      ],
                    ),
                    _buildTextField(
                      'phone',
                      'Ваш номер телефона',
                      'Введите',
                      keyboard: TextInputType.phone,
                      validators: [
                        FormBuilderValidators.required(errorText: 'Пожалуйста, введите номер телефона'),
                        FormBuilderValidators.minLength(10, errorText: 'Пожалуйста, введите корректный номер телефона'),
                      ],                 
                    ),
                    _buildPasswordField('password', 'Пароль', 'Введите', true),
                    _buildPasswordField('passwordConfirmation', 'Повторите пароль', 'Введите', false),
                    const SizedBox(height:10),
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
                              text: 'Рекламную \n',
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
                              text: 'Информационную рассылку',
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
                        onPressed: (agreeTerms && state is! AuthLoading) ? _trySubmit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: state is AuthLoading ? primaryBlue : primaryBlue,
                          disabledBackgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: state is AuthLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Войти',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // "Виджет текстового поля формы"
  // ============================================================
  Widget _buildTextField(
    String name,
    String label,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    List<FormFieldValidator<String>>? validators,
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
          FormBuilderTextField(
            name: name,
            keyboardType: keyboard,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: FormBuilderValidators.compose(validators ?? []),
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

  // ============================================================
  // "Виджет поля пароля с показом/скрытием"
  // ============================================================
  Widget _buildPasswordField(String name, String label, String hint, bool isFirst) {
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
          FormBuilderTextField(
            name: name,
            obscureText: isFirst ? !showPassword : !showRepeatPassword,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'Пожалуйста, введите пароль'),
              FormBuilderValidators.minLength(6, errorText: 'Пароль должен быть не менее 6 символов'),
              if (!isFirst)
                (val) {
                  if (val != _formKey.currentState?.fields['password']?.value) {
                    return 'Пароли не совпадают';
                  }
                  return null;
                },
            ]),
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

  // ============================================================
  // "Виджет чекбокса с текстом"
  // ============================================================
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

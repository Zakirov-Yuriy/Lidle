import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/custom_checkbox.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
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
  final _formKey = GlobalKey<FormBuilderState>();

  /// Обработчик нажатия кнопки "Войти" (или "Зарегистрироваться").
  /// Выполняет валидацию формы и отправляет событие регистрации в AuthBloc.
  void _trySubmit() {
    final formState = _formKey.currentState;
    final isValid = formState?.validate() ?? false;
    if (!isValid || !agreeTerms) return;

    formState?.save();
    final formData = formState?.value ?? {};

    // Отправляем событие регистрации в AuthBloc
    context.read<AuthBloc>().add(RegisterEvent(
      name: (formData['name'] as String?)?.trim() ?? '',
      lastName: (formData['lastName'] as String?)?.trim() ?? '',
      email: (formData['email'] as String?)?.trim() ?? '',
      phone: (formData['phone'] as String?)?.trim() ?? '',
      password: (formData['password'] as String?)?.trim() ?? '',
      passwordConfirmation: (formData['passwordConfirmation'] as String?)?.trim() ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0EA5E9);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthRegistered) {
          // Успешная регистрация - переходим на страницу верификации
          Navigator.of(context).pushNamed(RegisterVerifyScreen.routeName);
        } else if (state is AuthError) {
          // Ошибка регистрации - показываем Snackbar с кнопкой повтора
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка регистрации: ${state.message}'),
              backgroundColor: Colors.redAccent,
              action: SnackBarAction(
                label: 'Повторить',
                textColor: Colors.white,
                onPressed: _trySubmit,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: primaryBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FormBuilder(
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
                        onPressed: (agreeTerms && state is! AuthLoading) ? _trySubmit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: state is AuthLoading ? Colors.grey : primaryBlue,
                          disabledBackgroundColor: Colors.grey,
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
      },
    );
  }

  /// Приватный метод для построения текстового поля ввода.
  /// [name] - имя поля для FormBuilder.
  /// [label] - метка поля.
  /// [hint] - подсказка в поле ввода.
  /// [keyboard] - тип клавиатуры.
  /// [validators] - список валидаторов для поля.
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

  /// Приватный метод для построения поля ввода пароля.
  /// [name] - имя поля для FormBuilder.
  /// [label] - метка поля.
  /// [hint] - подсказка в поле ввода.
  /// [isFirst] - флаг, указывающий, является ли это первым полем пароля (для контроллера).
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

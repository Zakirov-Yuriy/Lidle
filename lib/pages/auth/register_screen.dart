import 'package:flutter/material.dart';
import 'package:lidle/widgets/forms/required_check_hint.dart';
import 'package:lidle/widgets/forms/phone_prefix.dart';
import 'package:lidle/core/config/app_config.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'register_verify_screen.dart';
import 'widgets/social_auth_block.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/widgets/forms/phone_number_formatter.dart';

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
  /// Согласие на обработку персональных данных (19.10.2026, задача 86).
  ///
  /// Галочек стало ТРИ вместо двух: закон требует, чтобы согласие на
  /// обработку персональных данных человек давал отдельным действием, а не
  /// одной галочкой вместе с принятием условий. Смешанная галочка считается
  /// согласием, полученным с нарушением.
  bool agreePersonalData = false;

  /// Принятие пользовательского соглашения и оферты.
  bool agreeTerms = false;

  /// Человек пытался продолжить, не поставив обязательную галочку
  /// (16.10.2026). По ним под галочками показывается объяснение.
  bool _personalDataMissing = false;
  bool _termsMissing = false;

  /// Рекламная рассылка. Необязательная и по умолчанию пустая: согласие на
  /// рекламу нельзя получать молчанием.
  bool agreeMarketing = false;

  bool showPassword = false;

  bool showRepeatPassword = false;

  final _formKey = GlobalKey<FormBuilderState>();

  late TextEditingController _phoneController;
  late FocusNode _phoneFocusNode;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _phoneFocusNode = FocusNode();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneFocusNode.dispose();
    super.dispose();
  }

  /// Код +7 в пустом поле телефона.
  ///
  /// С 16.10.2026 правило живёт в `PhonePrefix` и применяется на всех
  /// экранах, где вводят номер. Здесь остался только вызов: раньше каждый
  /// экран нёс свою копию этого обработчика, и вели они себя по-разному.
  void _onPhoneFocusChange() => PhonePrefix.applyTo(
        _phoneFocusNode,
        _phoneController,
      );

  /// Удаляет форматирование из номера телефона для отправки в API
  String _removePhoneFormatting(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  // ============================================================
  // "Логика обработки отправки формы регистрации"
  // ============================================================
  void _trySubmit() {
    final formState = _formKey.currentState;
    final isValid = formState?.validate() ?? false;

    // Показываем, чего не хватает, а не молчим (16.10.2026). Обязательных
    // галочек теперь две, и подсказка встаёт под каждой непоставленной.
    setState(() {
      _personalDataMissing = !agreePersonalData;
      _termsMissing = !agreeTerms;
    });

    if (!isValid || !agreePersonalData || !agreeTerms) return;

    formState?.save();
    final formData = formState?.value ?? {};

    // Удаляем форматирование из номера телефона перед отправкой в API
    final unformattedPhone = _removePhoneFormatting(
      (formData['phone'] as String?)?.trim() ?? '',
    );

    context.read<AuthBloc>().add(
      RegisterEvent(
        name: (formData['name'] as String?)?.trim() ?? '',

        // Поля фамилии в форме больше нет, шлём пусто: сервер её теперь не
        // требует, а человек вписывает фамилию на экране контактных данных.
        lastName: '',
        email: (formData['email'] as String?)?.trim() ?? '',
        phone: unformattedPhone,
        password: (formData['password'] as String?)?.trim() ?? '',
        passwordConfirmation:
            (formData['passwordConfirmation'] as String?)?.trim() ?? '',
      ),
    );
  }

  // ============================================================
  // "Метод открытия ссылок в браузере"
  // ============================================================
  /// Открыть правовой документ во внешнем браузере.
  ///
  /// Документы лежат на lidle.ru — основном домене. Раньше здесь был
  /// lidle.io: ссылки работали, но вели на второстепенный домен, а Google
  /// Play при проверке открывает ссылку на политику конфиденциальности
  /// вручную и сверяет её с той, что указана в консоли.
  Future<void> _openURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть ссылку')),
          );
        }
      }
    } catch (e) {
      // log.d('❌ Ошибка при открытии ссылки: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при открытии ссылки')),
        );
      }
    }
  }

  // ============================================================
  // "Метод построения интерфейса регистрации"
  // ============================================================
  @override
  Widget build(BuildContext context) {
    // log.d('🏗️ RegisterScreen build() called');
    const primaryBlue = Color(0xFF0EA5E9);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        // log.d('🔍 RegisterScreen listener - New state: ${state.runtimeType}');
        // log.d('🔍 State details: $state');

        if (state is AuthRegistered) {
          // log.d('✅ AuthRegistered state received, email: ${state.email}');
          // Переходим на экран верификации с передачей email
          Navigator.of(context).pushReplacementNamed(
            RegisterVerifyScreen.routeName,
            arguments: {'email': state.email},
          );
        } else if (state is AuthAuthenticated) {
          // log.d('✅ AuthAuthenticated state received');
          Navigator.of(context).pushReplacementNamed('/profile-dashboard');
        } else if (state is AuthError) {
          // log.d('❌ AuthError state: ${state.message}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: CustomErrorSnackBar(
                // Показываем реальное сообщение от сервера (email занят, и т.д.)
                message: state.message.isNotEmpty
                    ? state.message
                    : 'Ой, что-то пошло не так. Пожалуйста, попробуй ещё раз.',
                onClose: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
              backgroundColor: primaryBackground,
            ),
          );
        }
      },
      builder: (context, state) {
        // log.d();
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
                              Icon(
                                Icons.chevron_left_rounded,
                                color: Color(0xFF60A5FA),
                              ),
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
                      'Ваше имя  ',
                      'Введите',
                      validators: [
                        FormBuilderValidators.required(
                          errorText: 'Пожалуйста, введите ваше имя',
                        ),
                      ],
                    ),
                    // Фамилии в форме регистрации НЕТ (16.09.2026, решение
                    // заказчика). Человек вписывает её позже, на экране
                    // контактных данных. Чем короче форма входа в продукт, тем
                    // больше людей до конца её доходит, а фамилия нужна только
                    // к моменту публикации объявления, где её и спрашивают.
                    _buildTextField(
                      'email',
                      'Электронная почта',
                      'Введите',
                      keyboard: TextInputType.emailAddress,
                      validators: [
                        FormBuilderValidators.required(
                          errorText: 'Пожалуйста, введите email',
                        ),
                        FormBuilderValidators.email(
                          errorText: 'Пожалуйста, введите корректный email',
                        ),
                      ],
                      subtitle: ' (скрыта от пользователей)',
                    ),
                    _buildPhoneField(),
                    _buildPasswordField('password', 'Пароль', 'Введите', true),
                    _buildPasswordField(
                      'passwordConfirmation',
                      'Повторите пароль',
                      'Введите',
                      false,
                    ),
                    const SizedBox(height: 10),
                    // Три отдельные галочки (19.10.2026, задача 86).
                    //
                    // Раньше согласие на обработку персональных данных,
                    // пользовательское соглашение и оферта стояли одной
                    // галочкой. Так нельзя: согласие на обработку данных
                    // человек должен давать отдельным действием, иначе оно
                    // считается полученным с нарушением. Ссылки на документы
                    // остались прежними, просто разошлись по своим строкам.
                    _buildCheckBox(
                      value: agreePersonalData,
                      text: RichText(
                        text: TextSpan(
                          text: 'Я даю ',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          children: [
                            TextSpan(
                              text: 'согласие',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 13,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openURL(AppConfig().consentUrl),
                            ),
                            const TextSpan(
                              text: ' на обработку моих персональных данных на условиях ',
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextSpan(
                              text: 'Политики конфиденциальности',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 13,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openURL(AppConfig().privacyPolicyUrl),
                            ),
                          ],
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        agreePersonalData = v ?? false;

                        if (agreePersonalData) _personalDataMissing = false;
                      }),
                    ),
                    RequiredCheckHint(visible: _personalDataMissing),
                    const SizedBox(height: 16),
                    _buildCheckBox(
                      value: agreeTerms,
                      text: RichText(
                        text: TextSpan(
                          text: 'Я принимаю условия ',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          children: [
                            TextSpan(
                              text: 'Пользовательского соглашения',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 13,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openURL(AppConfig().userAgreementUrl),
                            ),
                            const TextSpan(
                              text: ' и ',
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextSpan(
                              text: 'оферты',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 13,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openURL(AppConfig().publicOfferUrl),
                            ),
                          ],
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        agreeTerms = v ?? false;

                        // Галочку поставили: объяснение больше не нужно.
                        if (agreeTerms) _termsMissing = false;
                      }),
                    ),
                    RequiredCheckHint(visible: _termsMissing),
                    const SizedBox(height: 16),
                    _buildCheckBox(
                      value: agreeMarketing,
                      text: RichText(
                        text: TextSpan(
                          text: 'Я соглашаюсь получать ',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          children: [
                            TextSpan(
                              text: 'рекламную',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 13,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openURL(AppConfig().mailingUrl),
                            ),
                            const TextSpan(
                              text: ' и ',
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextSpan(
                              text: 'информационную рассылку',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 13,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openURL(AppConfig().mailingUrl),
                            ),
                            const TextSpan(
                              text: ' (необязательно)',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      onChanged: (v) =>
                          setState(() => agreeMarketing = v ?? false),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 53,
                      child: ElevatedButton(
                        // Кнопка нажимается и без галочки (16.10.2026):
                        // иначе человек жмёт в мёртвую кнопку и не понимает,
                        // чего от него хотят. Проверка переехала в
                        // `_trySubmit`, он же покажет объяснение.
                        onPressed: state is AuthLoading ? null : _trySubmit,
                        style: ElevatedButton.styleFrom(
                          // Активный цвет кнопки
                          backgroundColor: primaryBlue,
                          // Неактивный цвет (когда чекбокс не отмечен или кнопка disabled)
                          disabledBackgroundColor: const Color(0xFF0E71A0),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Войти',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Быстрая регистрация через соцсети (тот же блок, что на
                    // экране входа; на бэке find-or-create).
                    const SocialAuthBlock(
                      label: 'Или зарегистрируйтесь через',
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
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
            ],
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
  // "Виджет поля телефона с автоматическим префиксом +7 и форматированием"
  // ============================================================
  Widget _buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ваш номер телефона',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 6),
          FormBuilderTextField(
            name: 'phone',
            controller: _phoneController,
            focusNode: _phoneFocusNode,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            inputFormatters: [
              PhoneNumberFormatter(),
            ],
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(
                errorText: 'Пожалуйста, введите номер телефона',
              ),
              FormBuilderValidators.minLength(
                10,
                errorText:
                    'Пожалуйста, введите корректный номер телефона',
              ),
            ]),
            decoration: InputDecoration(
              hintText: 'Введите',
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
  Widget _buildPasswordField(
    String name,
    String label,
    String hint,
    bool isFirst,
  ) {
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
              FormBuilderValidators.required(
                errorText: 'Пожалуйста, введите пароль',
              ),
              FormBuilderValidators.minLength(
                6,
                errorText: 'Пароль должен быть не менее 6 символов',
              ),
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'account_recovery.dart';
import 'register_screen.dart';
import 'package:lidle/pages/profile_dashboard/profile_dashboard.dart';

// ============================================================
// "Главный экран входа в систему"
// ============================================================
class SignInScreen extends StatefulWidget {
  static const routeName = '/sign-in';

  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

// ============================================================
// "Состояние экрана входа"
// ============================================================
class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _obscure = true;

  // ============================================================
  // "Метод построения интерфейса с управлением состоянием"
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(
              context,
            ).pushReplacementNamed(ProfileDashboard.routeName);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: CustomErrorSnackBar(
                  message: state.message,
                  onClose: () =>
                      ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                ),
                backgroundColor: primaryBackground,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: primaryBackground,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18.0, left: 3),
                    child: const Header(),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
                      // ============================================================
                      // "Форма входа с валидацией"
                      // ============================================================
                      child: FormBuilder(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontSize: 24,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                ),
                                children: const [
                                  TextSpan(text: 'Вы уже почти с нами'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 11),
                            const Text(
                              'Введите личные данные',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 17),

                            const _FieldLabel('Электронная почта'),
                            const SizedBox(height: 9),
                            // ============================================================
                            // "Поле ввода электронной почты"
                            // ============================================================
                            FormBuilderTextField(
                              name: 'email',
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                              ),
                              decoration: _inputDecoration('Введите'),
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(
                                  errorText: 'Введите почту',
                                ),
                                FormBuilderValidators.email(
                                  errorText: 'Неверный формат почты',
                                ),
                              ]),
                            ),
                            const SizedBox(height: 9),

                            const _FieldLabel('Пароль'),
                            const SizedBox(height: 9),
                            // ============================================================
                            // "Поле ввода пароля с показом/скрытием"
                            // ============================================================
                            FormBuilderTextField(
                              name: 'password',
                              obscureText: _obscure,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                              ),
                              decoration: _inputDecoration('Введите').copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(
                                  errorText: 'Введите пароль',
                                ),
                                FormBuilderValidators.minLength(
                                  6,
                                  errorText: 'Минимум 6 символов',
                                ),
                              ]),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: _onForgotPassword,
                                  style: _linkStyle,
                                  child: const Text('Забыл пароль'),
                                ),
                                TextButton(
                                  onPressed: _onSignUp,
                                  style: _linkStyle,
                                  child: const Text('Регистрация'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ============================================================
                            // "Кнопка входа с индикацией загрузки"
                            // ============================================================
                            SizedBox(
                              width: double.infinity,
                              height: 53,
                              child: ElevatedButton(
                                onPressed: state is AuthLoading
                                    ? null
                                    : _onSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: state is AuthLoading
                                      ? Colors.grey
                                      : activeIconColor,
                                  foregroundColor: textPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  elevation: 0,
                                ),
                                child: state is AuthLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onForgotPassword() {
    Navigator.of(context).pushNamed(AccountRecovery.routeName);
  }

  void _onSignUp() {
    Navigator.of(context).pushNamed(RegisterScreen.routeName);
  }

  // ============================================================
  // "Логика обработки отправки формы входа"
  // ============================================================
  void _onSubmit() {
    final formState = _formKey.currentState;
    final ok = formState?.validate() ?? false;
    if (!ok) return;

    formState?.save();
    final formData = formState?.value ?? {};

    context.read<AuthBloc>().add(
      LoginEvent(
        email: (formData['email'] as String?)?.trim() ?? '',
        password: (formData['password'] as String?)?.trim() ?? '',
        remember: true,
      ),
    );
  }

  // ============================================================
  // "Стилизация полей ввода"
  // ============================================================
  static InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textMuted),
      filled: true,
      fillColor: secondaryBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: activeIconColor, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  static final _linkStyle = TextButton.styleFrom(
    foregroundColor: activeIconColor,
    padding: EdgeInsets.zero,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
  );
}

// ============================================================
// "Виджет метки поля формы"
// ============================================================
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

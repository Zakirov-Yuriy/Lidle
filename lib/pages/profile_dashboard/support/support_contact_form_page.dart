// ============================================================
// "Виджет: Форма обращения в поддержку"
// ============================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/services/support_mail_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/widgets/components/header.dart';

class SupportContactFormPage extends StatefulWidget {
  static const routeName = '/support-contact-form';

  const SupportContactFormPage({super.key});

  @override
  State<SupportContactFormPage> createState() => _SupportContactFormPageState();
}

class _SupportContactFormPageState extends State<SupportContactFormPage> {
  static const bgColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);
  static const textSecondary = Colors.white70;
  static const errorColor = Color(0xFFFF6B6B);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;
  String? _screenshotPath;
  final ImagePicker _imagePicker = ImagePicker();

  final SupportMailService _mailService = SupportMailService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Загрузить данные пользователя из API
  Future<void> _loadUserData() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      final profile = await UserService.getProfile(token: token);
      
      if (mounted) {
        setState(() {
          _nameController.text = profile.name;
          _emailController.text = profile.email;
        });
      }
    } catch (e) {
      // Ошибка загрузки - форма остается пустой, пользователь может заполнить вручную
      // log.e('❌ Ошибка загрузки данных пользователя: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Валидировать email
  String? _validateEmail(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Укажите email';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value!)) {
      return 'Некорректный email';
    }
    return null;
  }

  /// Выбрать скриншот из галереи
  Future<void> _pickScreenshot() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _screenshotPath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ошибка выбора файла: $e'),
          backgroundColor: errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Удалить выбранный скриншот
  void _removeScreenshot() {
    setState(() {
      _screenshotPath = null;
    });
  }

  /// Отправить форму
  Future<void> _submitForm() async {
    // Убрать сообщение об ошибке
    setState(() {
      _errorMessage = null;
      _isSuccess = false;
    });

    // Валидировать форму
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final result = await _mailService.sendSupportEmail(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      subject: _subjectController.text.trim(),
      message: _messageController.text.trim(),
      screenshotPath: _screenshotPath,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success']) {
      // ✅ Успех
      setState(() {
        _isSuccess = true;
        _errorMessage = null;
      });

      // Показать снекбар
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Письмо успешно отправлено!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Очистить форму
      _nameController.clear();
      _emailController.clear();
      _subjectController.clear();
      _messageController.clear();

      // Очистить скриншот
      _screenshotPath = null;

      // Вернуться через 2 секунды
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } else {
      // ❌ Ошибка
      setState(() => _errorMessage = result['message']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── Header ─────
              Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 23),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [const Header()],
                ),
              ),

              // ───── Заголовок ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Обратная связь',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ───── Форма ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 📝 Имя
                      _buildTextField(
                        label: 'Ваше имя',
                        controller: _nameController,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Укажите имя';
                          }
                          if ((value?.length ?? 0) < 2) {
                            return 'Имя слишком короткое';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // ✉️ Email
                      _buildTextField(
                        label: 'Ваш email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),

                      const SizedBox(height: 18),

                      // 🎯 Тема
                      _buildTextField(
                        label: 'Тема обращения',
                        controller: _subjectController,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Укажите тему';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // 💬 Сообщение
                      _buildTextField(
                        label: 'Ваше сообщение',
                        controller: _messageController,
                        maxLines: 6,
                        showSuffixIcon: true,
                        suffixIcon: Icons.image,
                        onSuffixIconTap: _pickScreenshot,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Напишите сообщение';
                          }
                          if ((value?.length ?? 0) < 10) {
                            return 'Минимум 10 символов';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // 📎 Превью скриншота
                      if (_screenshotPath != null) ...[
                        _buildScreenshotPreview(),
                        const SizedBox(height: 18),
                      ],

                      const SizedBox(height: 7),

                      // ───── Кнопка Отправить ─────
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            disabledBackgroundColor:
                                accentColor.withValues(alpha: 0.5),
                          ),
                          onPressed: _isLoading ? null : _submitForm,
                          child: _isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Отправка...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Отправить',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // ───── Текст помощи ─────
                      if (!_isSuccess)
                        // Text(
                        //   'Мы ответим вам в течение 24 часов',
                        //   textAlign: TextAlign.center,
                        //   style: TextStyle(
                        //     color: textSecondary,
                        //     fontSize: 12,
                        //   ),
                        // ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Построить текстовое поле
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? onSuffixIconTap,
    bool showSuffixIcon = false,
    IconData suffixIcon = Icons.image,
  }) {
    final textField = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: textSecondary,
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          filled: true,
          fillColor: formBackground,
          contentPadding: const EdgeInsets.all(15),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: const TextStyle(
            color: errorColor,
            fontSize: 12,
          ),
        ),
      ),
    );

    // Если нужна иконка в углу, оборачиваем в Stack
    if (showSuffixIcon) {
      return Stack(
        children: [
          textField,
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                onPressed: _isLoading ? null : onSuffixIconTap,
                icon: Icon(
                  suffixIcon,
                  color: _screenshotPath != null ? accentColor : textSecondary,
                  size: 20,
                ),
                splashRadius: 24,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minHeight: 24,
                  minWidth: 24,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return textField;
  }

  /// Построить превью скриншота
  Widget _buildScreenshotPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Image.file(
            File(_screenshotPath!),
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
          ),
          // Кнопка удаления в углу
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _removeScreenshot,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: errorColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          // Индикатор внизу
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Скриншот выбран',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Построить секцию с прикреплением скриншота (удалена, функция встроена в поле сообщения)
}

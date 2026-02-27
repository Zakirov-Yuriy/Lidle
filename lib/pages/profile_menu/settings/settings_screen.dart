// ============================================================
// "Виджет: Экран настроек"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_event.dart';
import 'package:lidle/blocs/profile/profile_state.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/contact_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/pages/auth/sign_in_screen.dart';

class SettingsScreen extends StatefulWidget {
  static const routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const dangerColor = Color(0xFFFF3B30);

  int? _mainPhoneId; // ID основного номера телефона для обновления
  String? _mainPhoneValue; // Значение основного телефона

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Загружаем профиль пользователя с принудительным обновлением
    // чтобы всегда показывались актуальные данные с API
    context.read<ProfileBloc>().add(LoadProfileEvent(forceRefresh: true));
    _loadMainPhoneId();
  }

  Future<void> _loadMainPhoneId() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token != null) {
        final phonesResponse = await ContactService.getPhones(token: token);
        if (phonesResponse.data.isNotEmpty) {
          setState(() {
            _mainPhoneId = phonesResponse.data.first.id;
            // Ensure phone is in correct format with +
            String phone = phonesResponse.data.first.phone;
            if (!phone.startsWith('+')) {
              phone = '+$phone';
            }
            _mainPhoneValue = phone; // save value
          });
        } else {
          setState(() {
            _mainPhoneValue = null;
          });
        }
      }
    } catch (e) {
      // print('Error loading main phone ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoggedOut) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            SignInScreen.routeName,
            (Route<dynamic> route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───── Header ─────
                Padding(
                  padding: const EdgeInsets.only(bottom: 30, right: 23),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [const Header()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Color.fromARGB(255, 255, 255, 255),
                          size: 16,
                        ),
                      ),
                      const Text(
                        'Настройки',
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ───── Profile ─────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          debugPrint('Photo tapped');
                          Navigator.pushNamed(context, '/change_photo');
                        },
                        behavior: HitTestBehavior.opaque,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(45),
                          child: BlocBuilder<ProfileBloc, ProfileState>(
                            builder: (context, state) {
                              if (state is ProfileLoaded &&
                                  state.profileImage != null) {
                                return buildProfileImage(
                                  state.profileImage,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: formBackground,
                                  borderRadius: BorderRadius.circular(45),
                                ),
                                child: Center(
                                  child: SvgPicture.asset(
                                    'assets/profile_dashboard/default-photo.svg',
                                    width: 40,
                                    height: 40,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocBuilder<ProfileBloc, ProfileState>(
                            builder: (context, state) {
                              final displayName = state is ProfileLoaded
                                  ? state.name
                                  : 'Vlad';
                              return Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'В сети',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(color: Colors.white24),

                // ───── Account info ─────
                BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    // Сначала используем значение, полученное из ContactService
                    final phoneValue =
                        _mainPhoneValue != null && _mainPhoneValue!.isNotEmpty
                        ? _mainPhoneValue!
                        : (state is ProfileLoaded && state.phone.isNotEmpty
                              ? state.phone
                              : '+7 949 545 54 45');
                    return _infoItem(
                      title: 'Аккаунт пользователя',
                      value: phoneValue,
                      valueColor: Colors.white,
                      hint: 'Нажмите, чтобы изменить номер телефона',
                      onTapHint: _showChangePhoneDialog,
                    );
                  },
                ),
                BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    return _infoItem(
                      title: state is ProfileLoaded ? state.username : 'Name',
                      value: 'Имя аккаунта',
                      onTap: () => Navigator.pushNamed(context, '/username'),
                    );
                  },
                ),
                BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    final aboutValue =
                        state is ProfileLoaded &&
                            state.about != null &&
                            state.about!.isNotEmpty
                        ? state.about!
                        : 'Напишите немного о себе';
                    return _infoItem(
                      title: 'О себе',
                      value: aboutValue,
                      valueColor:
                          (state is ProfileLoaded &&
                              state.about != null &&
                              state.about!.isNotEmpty)
                          ? Colors.white
                          : Colors.white38,
                      onTap: () => _showAboutDialog(
                        currentAbout: state is ProfileLoaded
                            ? state.about
                            : null,
                      ),
                    );
                  },
                ),

                const Divider(color: Colors.white24),

                // ───── QR block ─────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ваш qr-код',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      BlocBuilder<ProfileBloc, ProfileState>(
                        builder: (context, state) {
                          final qrCodeBase64 = state is ProfileLoaded
                              ? state.qrCode
                              : null;
                          return _qrBox(qrCodeBase64);
                        },
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white24),

                // ───── Settings list ─────
                _settingsItem(
                  SvgPicture.asset(
                    'assets/profile_menu/settings/message-text-square-02.svg',
                    color: Colors.white,
                    width: 21,
                    height: 21,
                  ),
                  'Настройка чатов',
                  onTap: () => Navigator.pushNamed(context, '/chat_settings'),
                ),
                _settingsItem(
                  SvgPicture.asset(
                    'assets/profile_menu/settings/layout-alt-02.svg',
                    color: Colors.white,
                    width: 21,
                    height: 21,
                  ),
                  'Конфиденциальность',
                  onTap: () =>
                      Navigator.pushNamed(context, '/privacy_settings'),
                ),
                _settingsItem(
                  SvgPicture.asset(
                    'assets/profile_menu/settings/image-user.svg',
                    color: Colors.white,
                    width: 21,
                    height: 21,
                  ),
                  'Контактные данные',
                  onTap: () => Navigator.pushNamed(context, '/contact_data'),
                ),
                _settingsItem(
                  SvgPicture.asset(
                    'assets/profile_menu/settings/volume-max.svg',
                    color: Colors.white,
                    width: 21,
                    height: 21,
                  ),
                  'Уведомления',
                  onTap: _showNotificationsDialog,
                ),
                _settingsItem(
                  SvgPicture.asset(
                    'assets/profile_menu/settings/monitor-03.svg',
                    color: Colors.white,
                    width: 21,
                    height: 21,
                  ),
                  'Устройства',
                  onTap: () => Navigator.pushNamed(context, '/devices'),
                ),
                _settingsItem(
                  SvgPicture.asset(
                    'assets/profile_menu/settings/globe-01.svg',
                    color: Colors.white,
                    width: 21,
                    height: 21,
                  ),
                  'Язык',
                  onTap: _showLanguageDialog,
                ),
                _settingsItem(
                  SvgPicture.asset(
                    'assets/profile_menu/settings/help-circle.svg',
                    color: Colors.white,
                    width: 21,
                    height: 21,
                  ),
                  'Вопросы о LIDLE',
                  onTap: () => Navigator.pushNamed(context, '/faq'),
                ),
                _settingsItem(
                  SvgPicture.asset(
                    'assets/profile_menu/settings/file-search-02.svg',
                    color: Colors.white,
                    width: 21,
                    height: 21,
                  ),
                  'Политика конфиденциальности',
                  onTap: () => Navigator.pushNamed(context, '/privacy_policy'),
                ),

                const SizedBox(height: 8),

                // ───── Delete account ─────
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/delete_account'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          'assets/profile_menu/settings/trash-02.svg',
                          color: dangerColor,
                          width: 21,
                          height: 21,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Удалить аккаунт',
                          style: TextStyle(
                            color: dangerColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ───── Logout ─────
                GestureDetector(
                  onTap: () =>
                      context.read<AuthBloc>().add(const LogoutEvent()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          'assets/profile_menu/settings/exit.svg',
                          color: dangerColor,
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Выйти из аккаунта',
                          style: TextStyle(
                            color: dangerColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 111),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INFO ITEM
  // ─────────────────────────────────────────────

  Widget _infoItem({
    required String title,
    required String value,
    Color? valueColor,
    String? hint,
    VoidCallback? onTapHint,
    VoidCallback? onTap,
  }) {
    Widget item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: valueColor ?? Colors.white38, fontSize: 16),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onTapHint,
              child: Text(
                hint,
                style: const TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      item = GestureDetector(onTap: onTap, child: item);
    }

    return item;
  }

  void _showChangePhoneDialog() {
    final phoneController = TextEditingController();
    bool isLoading = false;
    // Предзаполняем контроллер текущим основным телефоном если есть
    if (_mainPhoneValue != null) phoneController.text = _mainPhoneValue!;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF1F2C3A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    const Center(
                      child: Text(
                        'Номер регистрации\nаккаунта',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      textAlign: TextAlign.start,
                      text: const TextSpan(
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: 'Внимание: ',
                            style: TextStyle(
                              color: Colors.yellowAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text:
                                'для смены основного номера телефона введите новый номер и подтвердите',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Новый номер',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16202A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: phoneController,
                        style: const TextStyle(color: Colors.white),
                        enabled: !isLoading,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '+7 949 456 54 54',
                          hintStyle: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'Отмена',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (phoneController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Введите номер телефона'),
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() {
                                    isLoading = true;
                                  });

                                  try {
                                    final token =
                                        HiveService.getUserData('token')
                                            as String?;
                                    if (token == null) {
                                      throw Exception('Токен не найден');
                                    }

                                    if (_mainPhoneId != null) {
                                      // Обновляем существующий номер
                                      await ContactService.updatePhone(
                                        id: _mainPhoneId!,
                                        phone: phoneController.text,
                                        token: token,
                                      );
                                    } else {
                                      // Добавляем новый номер
                                      await ContactService.addPhone(
                                        phone: phoneController.text,
                                        token: token,
                                      );
                                    }

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Номер телефона успешно обновлен',
                                          ),
                                        ),
                                      );
                                      // Перезагружаем профиль для обновления на всех экранах
                                      context.read<ProfileBloc>().add(
                                        LoadProfileEvent(),
                                      );
                                      Navigator.pop(context);
                                      // Перезагружаем ID
                                      _loadMainPhoneId();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Ошибка: ${e.toString()}',
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    setDialogState(() {
                                      isLoading = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            side: const BorderSide(color: activeIconColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      activeIconColor,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Отправить',
                                  style: TextStyle(
                                    color: activeIconColor,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguageDialog() {
    String selectedLanguage = 'Русский';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const Center(
                      child: Text(
                        'Выбрать язык',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _languageOption(
                      'Русский',
                      selectedLanguage == 'Русский',
                      () => setDialogState(() => selectedLanguage = 'Русский'),
                    ),
                    const SizedBox(height: 16),
                    _languageOption(
                      'Английский',
                      selectedLanguage == 'Английский',
                      () =>
                          setDialogState(() => selectedLanguage = 'Английский'),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 193,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                setDialogState(() => isLoading = true);

                                try {
                                  final token =
                                      HiveService.getUserData('token')
                                          as String?;
                                  if (token == null) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Токен не найден. Пожалуйста, переautoritize.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  // Преобразуем выбранный язык в код локали
                                  final localeCode =
                                      selectedLanguage == 'Русский'
                                      ? 'ru'
                                      : 'en';

                                  // Вызываем API для изменения языка
                                  await UserService.changeLocale(
                                    locale: localeCode,
                                    token: token,
                                  );

                                  if (!mounted) return;

                                  // Показываем успешное сообщение
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Язык успешно изменен на $selectedLanguage',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );

                                  Navigator.pop(context);
                                } catch (e) {
                                  if (!mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Ошибка при изменении языка: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );

                                  setDialogState(() => isLoading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          side: const BorderSide(color: activeIconColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    activeIconColor,
                                  ),
                                ),
                              )
                            : const Text(
                                'Потвердить',
                                style: TextStyle(
                                  color: activeIconColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationsDialog() {
    String selectedNotification = 'Включить уведомления';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const Center(
                      child: Text(
                        'Уведомления',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _notificationOption(
                      'Включить уведомления',
                      selectedNotification == 'Включить уведомления',
                      () => setDialogState(
                        () => selectedNotification = 'Включить уведомления',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _notificationOption(
                      'Выключить уведомления',
                      selectedNotification == 'Выключить уведомления',
                      () => setDialogState(
                        () => selectedNotification = 'Выключить уведомления',
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 193,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Реализовать изменение настроек уведомлений
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          side: const BorderSide(color: activeIconColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Потвердить',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _languageOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 1.5),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: activeIconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _notificationOption(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 1.5),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: activeIconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SETTINGS ITEM
  // ─────────────────────────────────────────────

  Widget _settingsItem(Widget icon, String title, {VoidCallback? onTap}) {
    Widget item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );

    if (onTap != null) {
      item = GestureDetector(onTap: onTap, child: item);
    }

    return item;
  }

  // ─────────────────────────────────────────────
  // QR КОД
  // ─────────────────────────────────────────────

  Widget _qrBox(String? qrCodeBase64) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: qrCodeBase64 != null ? Colors.white : cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: qrCodeBase64 != null && qrCodeBase64.isNotEmpty
          ? Image.memory(
              base64Decode(qrCodeBase64),
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            )
          : const Icon(Icons.qr_code, color: Colors.white54),
    );
  }

  void _showAboutDialog({String? currentAbout}) {
    final aboutController = TextEditingController();
    bool isLoading = false;

    // Предзаполняем контроллер текущим значением "О себе" если есть
    if (currentAbout != null && currentAbout.isNotEmpty) {
      aboutController.text = currentAbout;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF1F2C3A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header с крестиком
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'О себе',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Text field для ввода текста
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16202A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: aboutController,
                        maxLines: 4,
                        maxLength: 250,
                        style: const TextStyle(color: Colors.white),
                        enabled: !isLoading,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Напишите немного о себе...',
                          hintStyle: TextStyle(color: Colors.white54),
                          counterText: '',
                        ),
                      ),
                    ),

                    // Счетчик символов
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: aboutController,
                          builder: (context, value, child) {
                            return Text(
                              '${value.text.length}/250',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'Отмена',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (aboutController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Введите информацию о себе',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (aboutController.text.length > 250) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Максимум 250 символов'),
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() {
                                    isLoading = true;
                                  });

                                  try {
                                    final token =
                                        HiveService.getUserData('token')
                                            as String?;
                                    if (token == null) {
                                      throw Exception('Токен не найден');
                                    }

                                    await UserService.updateAbout(
                                      about: aboutController.text,
                                      token: token,
                                    );

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Информация о себе успешно обновлена',
                                          ),
                                        ),
                                      );
                                      Navigator.pop(context);
                                      // Перезагружаем профиль
                                      context.read<ProfileBloc>().add(
                                        LoadProfileEvent(),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Ошибка: ${e.toString()}',
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    setDialogState(() {
                                      isLoading = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            side: const BorderSide(color: activeIconColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      activeIconColor,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Сохранить',
                                  style: TextStyle(
                                    color: activeIconColor,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


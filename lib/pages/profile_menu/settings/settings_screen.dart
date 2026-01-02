import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_event.dart';
import 'package:lidle/blocs/profile/profile_state.dart';

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

  @override
  void initState() {
    super.initState();
    // Загружаем профиль пользователя
    context.read<ProfileBloc>().add(LoadProfileEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(45),
                      child: Image.asset(
                        'assets/profile_dashboard/Ellipse.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Vlad',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'В сети',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white24),

              // ───── Account info ─────
              _infoItem(
                title: 'Аккаунт пользователя',
                value: '+7 949 545 54 45',
                hint: 'Нажмите, чтобы изменить номер телефона',
              ),
              _infoItem(title: '@Postroisam', value: 'Имя аккаунта'),
              _infoItem(title: 'О себе', value: 'Напишите немного о себе'),

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
                        String? qrData;
                        if (state is ProfileLoaded) {
                          // Кодируем данные профиля в JSON для QR-кода
                          qrData =
                              '{"name":"${state.name}","email":"${state.email}","userId":"${state.userId}","phone":"${state.phone}"}';
                        }
                        return _qrBox(qrData);
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
              ),
              _settingsItem(
                SvgPicture.asset(
                  'assets/profile_menu/settings/layout-alt-02.svg',
                  color: Colors.white,
                  width: 21,
                  height: 21,
                ),
                'Конфиденциальность',
              ),
              _settingsItem(
                SvgPicture.asset(
                  'assets/profile_menu/settings/image-user.svg',
                  color: Colors.white,
                  width: 21,
                  height: 21,
                ),
                'Контактные данные',
              ),
              _settingsItem(
                SvgPicture.asset(
                  'assets/profile_menu/settings/volume-max.svg',
                  color: Colors.white,
                  width: 21,
                  height: 21,
                ),
                'Уведомления',
              ),
              _settingsItem(
                SvgPicture.asset(
                  'assets/profile_menu/settings/monitor-03.svg',
                  color: Colors.white,
                  width: 21,
                  height: 21,
                ),
                'Устройства',
              ),
              _settingsItem(SvgPicture.asset(
                  'assets/profile_menu/settings/globe-01.svg',
                  color: Colors.white,
                  width: 21,
                  height: 21,
                ),'Язык'),
              _settingsItem(
                SvgPicture.asset(
                  'assets/profile_menu/settings/help-circle.svg',
                  color: Colors.white,
                  width: 21,
                  height: 21,
                ),
                'Вопросы о VSETUT',
              ),
              _settingsItem(
                SvgPicture.asset(
                  'assets/profile_menu/settings/file-search-02.svg',
                  color: Colors.white,
                  width: 21,
                  height: 21,
                ),
                'Политика конфиденциальности',
              ),

              const SizedBox(height: 8),

              // ───── Delete account ─────
              Padding(
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

              const SizedBox(height: 111),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INFO ITEM
  // ─────────────────────────────────────────────

  static Widget _infoItem({
    required String title,
    required String value,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint,
              style: const TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SETTINGS ITEM
  // ─────────────────────────────────────────────

  static Widget _settingsItem(Widget icon, String title) {
    return Padding(
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
  }

  // ─────────────────────────────────────────────
  // QR PLACEHOLDER
  // ─────────────────────────────────────────────

  Widget _qrBox(String? qrData) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: qrData != null ? Colors.white : cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: qrData != null
          ? QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 100.0,
              gapless: false,
            )
          : const Icon(Icons.qr_code, color: Colors.white54),
    );
  }
}

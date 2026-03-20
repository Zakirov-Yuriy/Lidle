// ============================================================
// "Виджет: Экран меню профиля"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/contact_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_state.dart';
import 'package:lidle/blocs/profile/profile_event.dart';
import 'package:lidle/pages/auth/sign_in_screen.dart';
import 'package:lidle/pages/profile_menu/invite_friends/invite_friends_screen.dart';
import 'package:lidle/pages/profile_menu/settings/settings_screen.dart';
import 'package:lidle/pages/profile_menu/support_service_screen.dart';

class ProfileMenuScreen extends StatefulWidget {
  static const routeName = '/profile-menu';

  const ProfileMenuScreen({super.key});
  
  /// 🧹 Очищает кеш профиля при logout
  /// Вызывается из AuthBloc при LogoutEvent
  static void clearCache() {
    _ProfileMenuScreenState._lastProfileLoadTime = null;
    _ProfileMenuScreenState._lastPhoneLoadTime = null;
    _ProfileMenuScreenState._cachedMainPhone = null;
    print('🧹 ProfileMenuScreen: кеш очищен при logout');
  }

  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  String? _mainPhoneValue;
  
  // 🚀 ОПТИМИЗАЦИЯ: Кеширование данных профиля на 10 минут
  // Это предотвращает ненужную перезагрузку при каждом переходе на экран
  static DateTime? _lastProfileLoadTime;
  static const Duration _profileCacheDuration = Duration(minutes: 10);
  
  // 🚀 ОПТИМИЗАЦИЯ: Кеширование телефонов отдельно (также 10 минут)
  static DateTime? _lastPhoneLoadTime;
  static const Duration _phoneCacheDuration = Duration(minutes: 10);
  static String? _cachedMainPhone;

  bool _shouldRefreshProfile() {
    if (_lastProfileLoadTime == null) {
      return true; // Первый запуск - загружаем обязательно
    }
    
    final now = DateTime.now();
    final timeSinceLastLoad = now.difference(_lastProfileLoadTime!);
    
    return timeSinceLastLoad.inMinutes >= _profileCacheDuration.inMinutes;
  }

  bool _shouldRefreshPhones() {
    if (_lastPhoneLoadTime == null) {
      return true; // Первый запуск - загружаем обязательно
    }
    
    final now = DateTime.now();
    final timeSinceLastLoad = now.difference(_lastPhoneLoadTime!);
    
    return timeSinceLastLoad.inMinutes >= _phoneCacheDuration.inMinutes;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 🧠 ОПТИМИЗАЦИЯ: Загружаем профиль только если кеш старше 10 минут
    // Это значительно снижает нагрузку на API и улучшает UX
    if (_shouldRefreshProfile()) {
      BlocProvider.of<ProfileBloc>(
        context,
      ).add(LoadProfileEvent(forceRefresh: true));
      _lastProfileLoadTime = DateTime.now();
      print('✅ ProfileMenuScreen: загружен профиль (кеш обновлен)');
    } else {
      final timeSinceLastLoad = DateTime.now().difference(_lastProfileLoadTime!);
      print('⏳ ProfileMenuScreen: используется кеш профиля (осталось ${_profileCacheDuration.inMinutes - timeSinceLastLoad.inMinutes} мин)');
    }
    
    // 🧠 ОПТИМИЗАЦИЯ: Загружаем телефоны только если кеш старше 10 минут
    if (_shouldRefreshPhones()) {
      _loadMainPhoneValue();
      _lastPhoneLoadTime = DateTime.now();
    } else {
      // Используем кешированный телефон
      if (_cachedMainPhone != null) {
        setState(() {
          _mainPhoneValue = _cachedMainPhone;
        });
        final timeSinceLastLoad = DateTime.now().difference(_lastPhoneLoadTime!);
        print('⏳ ProfileMenuScreen: используется кеш телефона (осталось ${_phoneCacheDuration.inMinutes - timeSinceLastLoad.inMinutes} мин)');
      }
    }
  }

  Future<void> _loadMainPhoneValue() async {
    try {
      final token = TokenService.currentToken;
      if (token != null) {
        final phonesResponse = await ContactService.getPhones(token: token);
        if (phonesResponse.data.isNotEmpty) {
          setState(() {
            // Ensure phone is in correct format with +
            String phone = phonesResponse.data.first.phone;
            if (!phone.startsWith('+')) {
              phone = '+$phone';
            }
            _mainPhoneValue = phone;
            // 💾 КЕШИРОВАНИЕ: Сохраняем телефон в статический кеш
            _cachedMainPhone = phone;
          });
          print('✅ ProfileMenuScreen: загружен телефон (кеш обновлен)');
        } else {
          setState(() {
            _mainPhoneValue = null;
          });
          _cachedMainPhone = null;
        }
      }
    } catch (e) {
      debugPrint('Error loading main phone: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial ||
            (state is AuthError && !(state is AuthAuthenticated))) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            SignInScreen.routeName,
            (route) => route.settings.name == '/' || route.isFirst,
          );
        }
      },
      child: Scaffold(
        backgroundColor: primaryBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Личная информация',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                _buildMainProfile(context),
                const SizedBox(height: 22),
                const Divider(color: Color(0x33FFFFFF)),
                const SizedBox(height: 18),

                _buildAccountsBlock(),
                const SizedBox(height: 16),

                const Divider(color: Color(0x33FFFFFF)),
                const SizedBox(height: 20),

                _buildMenuItem(
                  Image.asset(
                    'assets/profile_menu/Icon1.png',
                    width: 22,
                    height: 22,
                  ),
                  'QR код',
                  onTap: () => Navigator.pushNamed(context, '/user_qr'),
                ),
                _buildMenuItem(
                  Image.asset(
                    'assets/profile_menu/Icon2.png',
                    width: 22,
                    height: 22,
                  ),
                  'Ваши карты',
                ),
                _buildMenuItem(
                  Image.asset(
                    'assets/profile_menu/Icon3.png',
                    width: 22,
                    height: 22,
                  ),
                  'Контакты',
                  onTap: () => Navigator.pushNamed(context, '/contacts'),
                ),
                const SizedBox(height: 23),

                const Divider(color: Color(0x33FFFFFF)),

                _buildMenuItem(
                  Image.asset(
                    'assets/profile_menu/Icon4.png',
                    width: 22,
                    height: 22,
                  ),
                  'Настройки',
                  onTap: () =>
                      Navigator.pushNamed(context, SettingsScreen.routeName),
                ),

                const Divider(color: Color(0x33FFFFFF)),
                const SizedBox(height: 13),

                _buildMenuItem(
                  Image.asset(
                    'assets/profile_menu/Icon5.png',
                    width: 22,
                    height: 22,
                  ),
                  'Служба поддержки',
                  onTap: () => Navigator.pushNamed(
                    context,
                    SupportServiceScreen.routeName,
                  ),
                ),
                _buildMenuItem(
                  Image.asset(
                    'assets/profile_menu/Icon6.png',
                    width: 22,
                    height: 22,
                  ),
                  'Пригласить друзей',
                  onTap: () => Navigator.pushNamed(
                    context,
                    InviteFriendsScreen.routeName,
                  ),
                ),
                _buildMenuItem(
                  Image.asset(
                    'assets/profile_menu/Icon7.png',
                    width: 22,
                    height: 22,
                  ),
                  'Возможности LIDLE',
                  textWidget: Text.rich(
                    TextSpan(children: getCapabilitiesTitleSpans()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ------------------------ UI COMPONENTS ------------------------ */

  Widget _buildMainProfile(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        return InkWell(
          onTap: () => Navigator.pushNamed(context, SettingsScreen.routeName),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Аватар
              ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: state is ProfileLoaded && state.profileImage != null
                    ? buildProfileImage(
                        state.profileImage,
                        width: 102,
                        height: 102,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 102,
                        height: 102,
                        decoration: BoxDecoration(
                          color: formBackground,
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/profile_dashboard/default-photo.svg',
                            width: 50,
                            height: 50,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 23),

              // ИМЯ + ТЕЛЕФОН + НИК
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state is ProfileLoaded ? state.name : 'Name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        state is ProfileLoaded
                            ? (_mainPhoneValue != null &&
                                      _mainPhoneValue!.isNotEmpty
                                  ? _mainPhoneValue!
                                  : state.phone)
                            : '+7 000 00 00 00',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        state is ProfileLoaded ? '${state.username}' : '@Name',
                        style: const TextStyle(
                          color: Color(0xFF009EE2),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              Column(
                children: [
                  const Text(
                    'Покупатель',
                    style: TextStyle(
                      color: Color(0xFFEAEF00),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Padding(
              padding: EdgeInsets.only(left: 30.0),
              child: Text(
                'Владислав',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            Spacer(),
            Text(
              'Компания',
              style: TextStyle(color: Color(0xFF19D849), fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 30.0),
          child: const Text(
            'Бизнес аккаунт',
            style: TextStyle(color: Color(0xFF009EE2), fontSize: 14),
          ),
        ),
        const SizedBox(height: 23),

        // Добавить аккаунт
        GestureDetector(
          onTap: () => Navigator.pushNamedAndRemoveUntil(
            context,
            SignInScreen.routeName,
            (route) => route.settings.name == '/' || route.isFirst,
          ),
          child: Row(
            children: const [
              Icon(Icons.add, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'Добавить аккаунт',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(Widget leading, String text, {VoidCallback? onTap, Widget? textWidget}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            textWidget ?? Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

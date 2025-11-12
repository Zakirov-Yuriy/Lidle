import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/bottom_navigation.dart';
import 'package:lidle/hive_service.dart';

class ProfileDashboard extends StatefulWidget {
  static const routeName = '/profile-dashboard';

  const ProfileDashboard({super.key});

  @override
  State<ProfileDashboard> createState() => _ProfileDashboardState();
}

class _ProfileDashboardState extends State<ProfileDashboard> {
  /// Индекс выбранного элемента в нижней навигационной панели (4 = профиль).
  int _selectedIndex = 4;

  /// Обработчик выбора элемента в нижней навигационной панели.
  void _onItemSelected(int index) {
    if (index == 4) {
      // Уже находимся на профиле
      return;
    }
    if (index == 0) {
      // Переход на главный экран
      Navigator.of(context).pushReplacementNamed('/');
      return;
    }
    // Для других вкладок можно добавить навигацию позже
    setState(() => _selectedIndex = index);
  }

  /// Обработчик выхода из аккаунта.
  /// Удаляет токен авторизации и переходит на главную страницу.
  Future<void> _logout() async {
    await HiveService.deleteUserData('token');
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 31),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ЛОГО
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

              // Хедер профиля (аватар + имя + ID)
              _ProfileHeader(
                name: 'Влад Борман',
                userId: 'ID: 2342124342',
                avatarUrl: 'assets/profile_dashboard/Ellipse.png',
              ),
              const SizedBox(height: 29),

              // 3 быстрых карточки
              Row(
                children: [
                  _QuickCard(
                    iconPath: 'assets/profile_dashboard/heart-rounded.svg',
                    title: 'Избранное',
                    subtitle: '14 товаров',
                  ),
                  SizedBox(width: 10),
                  _QuickCard(
                    iconPath: 'assets/profile_dashboard/shopping-cart-01.svg',
                    title: 'Покупки',
                    subtitle: '2 товаров',
                  ),
                  SizedBox(width: 10),
                  _QuickCard(
                    iconPath: 'assets/profile_dashboard/eva_star-fill.svg',
                    title: 'Отзывы',
                    subtitle: '0 товаров',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Раздел «Ваши объявления»
              const _SectionTitle('Ваши объявления'),
              const SizedBox(height: 10),
              const _MenuItem(title: 'Активные / Неактивные', count: 4, trailingChevron: true),
              const Divider(color: Color(0xFF474747), height: 8),
              const _MenuItem(title: 'Отклики', count: 4, trailingChevron: true),
              const Divider(color: Color(0xFF474747), height: 8),
              const _MenuItem(title: 'Архив', trailingChevron: true),
              const Divider(color: Color(0xFF474747), height: 8),
              const SizedBox(height: 20),

              // Раздел «Сообщения»
              const _SectionTitle('Сообщения'),
              const SizedBox(height: 11),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 86, // <-- фиксируем высоту карточки
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  const items = [
                    ('Сообщения с юзерами', 'Сообщения: 134', false),
                    ('Сообщения с компаниями', 'Сообщения: 11', false),
                    ('Поддержка VSETUT', 'Сообщения: Нет', false),
                    ('Предложения цен', 'Сообщения: 2 + 1', true),
                  ];
                  final (title, subtitle, highlight) = items[index];
                  return _MessageCard(
                    title: title,
                    subtitle: subtitle,
                    highlight: highlight,
                  );
                },
              ),

              const SizedBox(height: 41),

              // Кнопка выхода нужна для тестов 
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Выйти',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              
            ],
          ),
        ),
      ),

      // Нижняя навигация
      bottomNavigationBar: BottomNavigation(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemSelected,
      ),
    );
  }
}

/* =========================  WIDGETS  ========================= */

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String userId;
  final String avatarUrl;

  const _ProfileHeader({
    required this.name,
    required this.userId,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Аватар с синей окантовкой
        Container(
          // padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: activeIconColor, width: 3),
          ),
          child: CircleAvatar(
            radius: 54.5,
            backgroundImage: AssetImage(avatarUrl),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 34),
            Text(
              userId,
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String iconPath;
  final String title;
  final String subtitle;

  const _QuickCard({
    required this.iconPath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 86,
        width: double.infinity,
        decoration: BoxDecoration(
          color: primaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF474747)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 13.0, left: 10.0, bottom: 2),
              child: Row(children: [SvgPicture.asset(iconPath, height: 24, color: Colors.white70)]),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Row(
                children: [
                  Text(
                    subtitle,
                    style: const TextStyle(color: textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final int? count;
  final bool trailingChevron;

  const _MenuItem({
    required this.title,
    this.count,
    this.trailingChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            if (count != null)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFF767676)),
                ),
                alignment: Alignment.center, // выравниваем текст по центру
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: const Color(0xFF767676),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

            if (trailingChevron) ...[
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool highlight;

  const _MessageCard({
    required this.title,
    required this.subtitle,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = highlight
        ? Border.all(color: const Color(0xFFE3E335), width: 1)
        : Border.all(color: const Color(0xFF474747));

    return Container(
      // УДАЛЯЕМ: constraints: const BoxConstraints(minHeight: 86),
      decoration: BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 7.0),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: highlight ? const Color(0xFFE3E335) : textSecondary,
                fontSize: 10,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

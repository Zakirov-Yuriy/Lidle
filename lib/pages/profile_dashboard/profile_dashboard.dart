import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_state.dart';
import 'package:lidle/blocs/profile/profile_event.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/pages/auth/sign_in_screen.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/pages/my_purchases_screen.dart'; // Import MyPurchasesScreen
import 'package:lidle/pages/profile_dashboard/offers/price_offers_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/user_messages/user_messages_list_screen.dart';
import 'package:lidle/pages/profile_dashboard/company_messages/company_messages_list_screen.dart';

class ProfileDashboard extends StatelessWidget {
  static const routeName = '/profile-dashboard';

  const ProfileDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Загружаем профиль при первом построении
    context.read<ProfileBloc>().add(LoadProfileEvent());

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial || state is AuthLoggedOut) {
          Navigator.of(context).pushReplacementNamed(SignInScreen.routeName);
        }
      },
      child: BlocListener<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoggedOut) {
            Navigator.of(context).pushReplacementNamed('/');
          }
        },
      child: BlocListener<NavigationBloc, NavigationState>(
        listener: (context, state) {
          if (state is NavigationToProfile || state is NavigationToHome || state is NavigationToFavorites || state is NavigationToMessages) {
            context.read<NavigationBloc>().executeNavigation(context);
          }
        },
        child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, navigationState) {
          return BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, profileState) {
            return Scaffold(
                extendBody: true,
                backgroundColor: primaryBackground,
                body: SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // // ЛОГО
                        // Padding(
                        //   padding: const EdgeInsets.only(
                        //     left: 41.0,
                        //     top: 44.0,
                        //     bottom: 35.0,
                        //   ),
                        //   child: Row(
                        //     children: [
                        //       SvgPicture.asset(logoAsset, height: logoHeight),
                        //       const Spacer(),
                        //     ],
                        //   ),
                        // ),

                        // Хедер профиля (аватар + имя + ID)
                        _ProfileHeader(
                          name: profileState is ProfileLoaded ? profileState.name : 'Загрузка...',
                          userId: profileState is ProfileLoaded ? profileState.userId : 'ID: ...',
                          avatarUrl: 'assets/profile_dashboard/Ellipse.png',
                        ),
                        const SizedBox(height: 29),

                        // 3 быстрых карточки
                        Row(
                          children: [
                            ValueListenableBuilder(
                              valueListenable: HiveService.settingsBox.listenable(keys: ['favorites']),
                              builder: (context, box, child) {
                                final favorites = HiveService.getFavorites();
                                final allListings = ListingsBloc.staticListings;
                                final favoritedCount = allListings.where((listing) => favorites.contains(listing.id)).length;
                                return _QuickCard(
                                  iconPath: 'assets/profile_dashboard/heart-rounded.svg',
                                  title: 'Избранное',
                                  subtitle: '$favoritedCount товаров',
                                  onTap: () => Navigator.of(context).pushNamed('/favorites'),
                                );
                              },
                            ),
                            SizedBox(width: 10),
                            _QuickCard(
                              iconPath: 'assets/profile_dashboard/shopping-cart-01.svg',
                              title: 'Покупки',
                              subtitle: '2 товаров',
                              onTap: () => Navigator.of(context).pushNamed(MyPurchasesScreen.routeName),
                            ),
                            SizedBox(width: 10),
                            _QuickCard(
                              iconPath: 'assets/profile_dashboard/eva_star-fill.svg',
                              title: 'Отзывы',
                              subtitle: '0 отзовов',
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
                          padding: EdgeInsets.zero,
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
                            final item = items[index];
                            final title = item.$1;
                            final subtitle = item.$2;
                            final highlight = item.$3;
                            return _MessageCard(
                              title: title,
                              subtitle: subtitle,
                              highlight: highlight,
                              onTap: index == 0 ? () => Navigator.of(context).pushNamed(UserMessagesListScreen.routeName) : index == 1 ? () => Navigator.of(context).pushNamed(CompanyMessagesListScreen.routeName) : index == 3 ? () => Navigator.of(context).pushNamed(PriceOffersEmptyPage.routeName) : null,
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Кнопка выхода нужна для тестов
                        SizedBox(
                          width: double.infinity,
                          // height: 53,
                          child: ElevatedButton(
                            onPressed: () => context.read<AuthBloc>().add(const LogoutEvent()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              minimumSize: Size(double.infinity, 44), // Fixed height
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
                  onItemSelected: (index) {
                    context.read<NavigationBloc>().add(SelectNavigationIndexEvent(index));
                  },
                ),
              );
            },
          );
        },
      ),
      ),
    ));
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
  final VoidCallback? onTap;

  const _QuickCard({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: 96,
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
    );

    return Expanded(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: card,
            )
          : card,
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
      borderRadius: BorderRadius.circular(5),
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
  final VoidCallback? onTap;

  const _MessageCard({
    required this.title,
    required this.subtitle,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = highlight
        ? Border.all(color: const Color(0xFFE3E335), width: 1)
        : Border.all(color: const Color(0xFF474747));

    final card = Container(
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

    return onTap != null
        ? GestureDetector(
            onTap: onTap,
            child: card,
          )
        : card;
  }
}

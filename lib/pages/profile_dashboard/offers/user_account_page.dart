import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/offer_model.dart';
import 'package:lidle/widgets/dialogs/reject_offer_dialog.dart';

class UserAccountPage extends StatelessWidget {
  final PriceOfferItem? offerItem;

  const UserAccountPage({super.key, this.offerItem});

  static const routeName = '/user-account';

  static const backgroundColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const dangerColor = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile ||
            state is NavigationToHome ||
            state is NavigationToFavorites ||
            state is NavigationToAddListing ||
            state is NavigationToMyPurchases ||
            state is NavigationToMessages ||
            state is NavigationToSignIn) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, navigationState) {
          return Scaffold(
            extendBody: true,
            backgroundColor: backgroundColor,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // ───── Header ─────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5, right: 23),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [const Header(), const Spacer()],
                      ),
                    ),

                    // ───── Back / Cancel ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            // Нажатие на всю строку, а не только на стрелку: попасть пальцем
                            // в иконку шириной 16 точек трудно, а заголовок рядом читается
                            // как часть той же кнопки «назад».
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.arrow_back_ios,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Аккаунт пользователя',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 255, 255, 255),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Назад',
                              style: TextStyle(
                                color: activeIconColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // const SizedBox(height: 16),

                    // ───── Content ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        children: [
                          _UserCard(),
                          const SizedBox(height: 16),
                          _OfferCard(),
                          // ───── Bottom space ─────
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: BottomNavigation(
              onItemSelected: (index) {
                if (index == 3) {
                  // Shopping cart icon
                  context.read<NavigationBloc>().add(
                    NavigateToMyPurchasesEvent(),
                  );
                } else {
                  context.read<NavigationBloc>().add(
                    SelectNavigationIndexEvent(index),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// USER CARD
// ─────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final offerItem = context
        .findAncestorWidgetOfExactType<UserAccountPage>()!
        .offerItem;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Аватар пользователя.
                //
                // Нет аватара, значит стандартная заглушка, как в списке
                // сообщений. Прежде рисовался цветной кружок с буквами, и
                // на экране это выглядело как сиреневое пятно (09.10.2026).
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white10,
                  backgroundImage:
                      (offerItem?.avatarUrl != null &&
                          offerItem!.avatarUrl!.startsWith('http'))
                      ? NetworkImage(offerItem.avatarUrl!)
                      : null,
                  child:
                      (offerItem?.avatarUrl == null ||
                          !offerItem!.avatarUrl!.startsWith('http'))
                      ? const Icon(Icons.person, color: Colors.white54, size: 32)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              offerItem?.name ?? 'Виталий Покрышкин',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // «В сети» убрано 09.10.2026: присутствия мы не
                          // отслеживаем, и надпись была просто нарисована.
                          // Вернуть можно, когда появится последний визит.
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offerItem?.subtitle ?? 'На Lidle с 12.12.2025',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // const Divider(color: Colors.white24, height: 1),
          // Контакты. Показываем только то, что у человека есть: пустая
          // строка с подставным значением хуже, чем её отсутствие
          // (09.10.2026, задача 15).
          if (offerItem?.nickname != null)
            _InfoRow(
              label: 'Ник в Lidle',
              value: offerItem!.nickname!,
              isLink: true,
            ),

          for (final phone in (offerItem?.phones ?? const <String>[]))
            _InfoRow(
              label: phone == offerItem!.phones.first ? 'Номер' : '',
              value: phone,
            ),

          for (final telegram in (offerItem?.telegrams ?? const <String>[]))
            _InfoRow(
              label: telegram == offerItem!.telegrams.first ? 'Телеграмм' : '',
              value: telegram.startsWith('@') ? telegram : '@$telegram',
              isLink: true,
            ),

          for (final whatsapp in (offerItem?.whatsapps ?? const <String>[]))
            _InfoRow(
              label: whatsapp == offerItem!.whatsapps.first ? 'WhatsApp' : '',
              value: whatsapp,
              isLink: true,
            ),

          for (final max in (offerItem?.maxes ?? const <String>[]))
            _InfoRow(
              label: max == offerItem!.maxes.first ? 'Max' : '',
              value: max.startsWith('@') ? max : '@$max',
              isLink: true,
            ),

          if (offerItem?.city != null) ...[
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Город',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    offerItem!.city!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Получает инициалы из имени пользователя
  String _getInitials(String name) {
    List<String> words = name.split(' ');
    String initials = '';
    for (var word in words) {
      if (word.isNotEmpty) {
        initials += word[0].toUpperCase();
      }
    }
    return initials.length > 2 ? initials.substring(0, 2) : initials;
  }
}

// ─────────────────────────────────────────────
// OFFER CARD
// ─────────────────────────────────────────────

class _OfferCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final offerItem = context
        .findAncestorWidgetOfExactType<UserAccountPage>()!
        .offerItem;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Предлагаемая цена',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  offerItem?.price ?? '0 ₽',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Сообщение',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  offerItem?.message ?? 'Нет сообщения',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: UserAccountPage.dangerColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const RejectOfferDialog(),
                  );
                },
                child: const Text(
                  'Отклонить',
                  style: TextStyle(
                    color: UserAccountPage.dangerColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INFO ROW
// ─────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLink;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          if (label.isNotEmpty) const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isLink ? UserAccountPage.accentColor : Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

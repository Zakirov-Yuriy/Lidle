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
                            child: const Icon(
                              Icons.arrow_back_ios,
                              color: Color.fromARGB(255, 255, 255, 255),
                              size: 16,
                            ),
                          ),
                          const Text(
                            'Аккаунт пользователя',
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
                // Аватар пользователя
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                  child: ClipOval(
                    child:
                        offerItem?.avatar != null &&
                            offerItem!.avatar.isNotEmpty
                        ? Image.network(
                            offerItem.avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.blue[600]!,
                                      Colors.blue[900]!,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _getInitials(offerItem.name),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.blue[600]!, Colors.blue[900]!],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(offerItem?.name ?? 'ВП'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                  ),
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
                          const SizedBox(width: 8),
                          Text(
                            'В сети',
                            style: TextStyle(
                              color: Colors.green[400],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
          _InfoRow(
            label: 'Ник в Lidle',
            value: offerItem?.nickname ?? '@user',
            isLink: true,
          ),
          _InfoRow(
            label: 'Номер',
            value: offerItem?.phone ?? '+7 000 000 00 00',
          ),
          // _InfoRow(label: '', value: '+7 949 456 78 76'),
          _InfoRow(label: 'Max', value: '@AndrawP', isLink: true),
          // _InfoRow(label: 'WhatsApp', value: '@AndrawP', isLink: true),
          _InfoRow(label: 'VK', value: '@AndrawP', isLink: true),

          const Divider(color: Colors.white24, height: 1),

          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Город',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                SizedBox(height: 6),
                Text(
                  'Мариуполь',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
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

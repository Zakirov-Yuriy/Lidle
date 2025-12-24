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
  final PriceOfferItem offerItem;

  const UserAccountPage({super.key, required this.offerItem});

  static const routeName = '/user-account';

  static const backgroundColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const dangerColor = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile || state is NavigationToHome || state is NavigationToFavorites || state is NavigationToAddListing || state is NavigationToMyPurchases || state is NavigationToMessages || state is NavigationToSignIn) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, navigationState) {
          return Scaffold(
            // extendBody: true,
            backgroundColor: backgroundColor,
            body: SafeArea(
              // bottom: false,
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
                            style: TextStyle(color: activeIconColor, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // const SizedBox(height: 16),

                  // ───── Content ─────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        children: [
                          _UserCard(),
                          const SizedBox(height: 16),
                          _OfferCard(),
                        ],
                      ),
                    ),
                  ),

                  // ───── Bottom space ─────
                  const SizedBox(height: 16),
                ],
              ),
            ),
            bottomNavigationBar: BottomNavigation(
              onItemSelected: (index) {
                if (index == 3) { // Shopping cart icon
                  context.read<NavigationBloc>().add(NavigateToMyPurchasesEvent());
                } else {
                  context.read<NavigationBloc>().add(SelectNavigationIndexEvent(index));
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
    final offerItem = context.findAncestorWidgetOfExactType<UserAccountPage>()!.offerItem;

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
                CircleAvatar(
                  radius: 28,
                  backgroundImage: AssetImage(offerItem.avatar),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offerItem.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        offerItem.subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'В сети',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24, height: 1),

          _InfoRow(label: 'Ник в Lidle', value: 'AndrawP', isLink: true),
          _InfoRow(label: 'Номер', value: '+7 949 456 78 76'),
          _InfoRow(label: '', value: '+7 949 456 78 76'),
          _InfoRow(label: 'Телеграмм', value: '@AndrawP', isLink: true),
          _InfoRow(label: 'WhatsApp', value: '@AndrawP', isLink: true),
          _InfoRow(label: 'VK', value: '@AndrawP', isLink: true),

          const Divider(color: Colors.white24, height: 1),

          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Город',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Мариуполь',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OFFER CARD
// ─────────────────────────────────────────────

class _OfferCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Предлагаемая цена',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '41 000 000 ₽',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Сообщение',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Готов предложить вам торг, так как вижу много косяков по ремонту',
                  style: TextStyle(
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
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          if (label.isNotEmpty) const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isLink
                  ? UserAccountPage.accentColor
                  : Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

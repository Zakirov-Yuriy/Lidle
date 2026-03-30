import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/no_internet_screen.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const inputColor = Color(0xFF1B2734);

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        // Screen will rebuild automatically when state changes
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(onRetry: () {
              context.read<ConnectivityBloc>().add(const CheckConnectivityEvent());
            });
          }

          return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ───── Header ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 5, right: 25),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [const Header(), const Spacer()],
              ),
            ),

            const SizedBox(height: 20),

            // ───── Back / Cancel ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_back_ios,
                          color: activeIconColor,
                          size: 16,
                        ),
                        const SizedBox(
                          width: 4,
                        ), // Небольшой отступ между иконкой и текстом
                        const Text(
                          'Назад',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ───── Back + User ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  Row(
                    children: [
                      // avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cardColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline_sharp,
                          color: Colors.white24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Егор Егоров',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'был(а) сегодня',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.more_vert, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 17),
            const Divider(color: Colors.white24, height: 1),

            // ───── Messages ─────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                children: const [
                  SizedBox(height: 16),

                  // date
                  Center(
                    child: Text(
                      '8 февраля',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),

                  SizedBox(height: 16),

                  // incoming
                  _IncomingMessage(
                    text:
                        'Для вопросов по заказам нажмите на нужный в списке ниже. '
                        'Если подходящего заказа не нашлось, нажмите кнопку Другого заказа.',
                    time: '20:21',
                  ),

                  SizedBox(height: 12),

                  // outgoing
                  _OutgoingMessage(text: 'Спасибо, понял', time: '20:22'),
                ],
              ),
            ),

            // ───── Input ─────
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 8, 25, 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Сообщение',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.send, color: accentColor),
                    ),
                  ],
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
}

// ─────────────────────────────────────────────
// INCOMING MESSAGE
// ─────────────────────────────────────────────

class _IncomingMessage extends StatelessWidget {
  final String text;
  final String time;

  const _IncomingMessage({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              time,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OUTGOING MESSAGE
// ─────────────────────────────────────────────

class _OutgoingMessage extends StatelessWidget {
  final String text;
  final String time;

  const _OutgoingMessage({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              time,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// "Экран: Вопросы по заказу"
// ============================================================
//
// Открывается кнопкой «Задать вопрос» на экране заказа (17.09.2026).
//
// Здесь короткие ответы на то, что человек спрашивает у продавца чаще всего:
// сколько заказ лежит, можно ли забрать не самому, что будет, если передумал.
// Список пока живёт в приложении, а не приходит с сервера: тексты одинаковы
// для всех заказов и меняются раз в полгода, и отдельная таблица ради них
// была бы дороже пользы. Когда у продавцов появятся свои условия, список
// переедет на сервер, и меняться будет только источник.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';

/// Вопрос и ответ на него.
class OrderQuestion {
  final String question;
  final String answer;

  const OrderQuestion(this.question, this.answer);
}

class OrderQuestionsScreen extends StatefulWidget {
  static const String routeName = '/order-questions';

  final OrderModel order;

  const OrderQuestionsScreen({super.key, required this.order});

  @override
  State<OrderQuestionsScreen> createState() => _OrderQuestionsScreenState();
}

class _OrderQuestionsScreenState extends State<OrderQuestionsScreen> {
  /// Какой вопрос раскрыт. Раскрыт всегда один: список коротких заголовков
  /// читается глазами целиком, а четыре раскрытых ответа превращают его в
  /// сплошной текст.
  int? _opened;

  static const List<OrderQuestion> _questions = [
    OrderQuestion(
      'Как продлить хранение?',
      'Вы можете обратиться к продавцу и обсудить с ним вопрос хранения '
          'вашего товара.',
    ),
    OrderQuestion(
      'Может ли заказ забрать другой человек?',
      'Да. Заказ выдают тому, кто назовёт продавцу код получения, поэтому '
          'передайте код тому, кто пойдёт за товаром вместо вас.',
    ),
    OrderQuestion(
      'Когда можно забрать заказ?',
      'Как только продавец соберёт его, статус заказа сменится на «Готов к '
          'выдаче». Приходите в часы работы точки, они указаны на экране '
          'заказа.',
    ),
    OrderQuestion(
      'Как отказаться от заказа?',
      'На экране заказа нажмите «Отказаться» и подтвердите отказ. Заказ '
          'отменится целиком, а товар вернётся в продажу.',
    ),
    OrderQuestion(
      'Что делать, если товар не подошёл?',
      'Обсудите возврат с продавцом: условия он устанавливает сам. Написать '
          'ему можно из карточки товара или из переписки.',
    ),
  ];

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
      child: Scaffold(
        extendBody: true,
        backgroundColor: primaryBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0, left: 8),
                child: Header(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _titleRow(context),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: _questions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _card(index),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigation(
          onItemSelected: (index) {
            if (index == 3) {
              context.read<NavigationBloc>().add(NavigateToMyPurchasesEvent());
            } else {
              context
                  .read<NavigationBloc>()
                  .add(SelectNavigationIndexEvent(index));
            }
          },
        ),
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text(
                'Вопросы',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Назад',
            style: TextStyle(color: activeIconColor, fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _card(int index) {
    final item = _questions[index];
    final isOpen = _opened == index;

    return Container(
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _opened = isOpen ? null : index),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.question,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isOpen ? Icons.expand_less : Icons.expand_more,
                    color: textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (isOpen) ...[
            const Divider(height: 1, color: Color(0xFF2C3A48), indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(
                item.answer,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

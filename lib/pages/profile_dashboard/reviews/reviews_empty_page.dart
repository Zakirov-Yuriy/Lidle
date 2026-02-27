import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/widgets/sort_dialog.dart';
import 'package:lidle/models/review_model.dart';
import 'package:lidle/widgets/cards/review_card.dart';

class ReviewsEmptyPage extends StatefulWidget {
  static const routeName = '/reviews-empty';

  const ReviewsEmptyPage({super.key});

  @override
  State<ReviewsEmptyPage> createState() => _ReviewsEmptyPageState();
}

class _ReviewsEmptyPageState extends State<ReviewsEmptyPage> {
  SortOption? _selectedSortOption;
  int _currentTab = 0;


  List<ReviewModel> _myReviews = [
    ReviewModel(
      id: '1',
      productImage: 'assets/home_page/studio.png',
      productName: 'Due Bambini Комплект \nдетский стол + стул,50x50x50см',
      reviewDate: '6 апреля',
      rating: 4.0,
      reviewText: 'Дочька в восторге ,очень удобный столик. правда нужно для него клеенку. Т.к краска любая в него прям въедается ( материал очень прочный ,поэтому мы спокойны',
      commentCount: 1,
      commentAuthor: 'Андрей Коломойский',
      commentDate: '6 апреля',
      commentText: 'Эмилия, Здравствуйте! Благодарим за выбор нашего бренда и высокую оценку! Нам очень приятно, что Ваши ожидания оправдались. Мы стараемся, чтобы наша продукция была не только практичной и функциональной, но и качественной. Нам важно, чтобы наши покупатели были довольны своим выбором. Спасибо, что выбрали нас, ждём Вас снова. С заботой о самых маленьких, команда Due Bambini',
      canEdit: true,
      canDelete: true,
    ),
  ];

  List<ReviewModel> _reviewsOnMyListings = [
    ReviewModel(
      id: '2',
      productImage: 'assets/home_page/studio.png',
      productName: 'Due Bambini Комплект \nдетский стол + стул,50x50x50см',
      reviewDate: '6 апреля',
      rating: 4.0,
      reviewText: 'Дочька в восторге ,очень удобный столик. правда нужно для него клеенку. Т.к краска любая в него прям въедается ( материал очень прочный ,поэтому мы спокойны',
      commentCount: 0,
      canEdit: true,
      canDelete: true,
    ),
  ];


  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile || state is NavigationToHome || state is NavigationToFavorites || state is NavigationToMessages) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, navigationState) {
          return Scaffold(
            extendBody: true,
            backgroundColor: primaryBackground,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ───── Header ─────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, right: 25),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Header(),
                        ),
                        const Spacer(),
                      ],
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
                          'Отзывы',
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          child: const Icon(Icons.swap_vert, color: Colors.white),
                          onTap: () async {
                            final selectedOption = await showDialog<SortOption>(
                              context: context,
                              builder: (BuildContext context) {
                                return SortDialog(initialSortOption: _selectedSortOption);
                              },
                            );
                            if (selectedOption != null) {
                              setState(() {
                                _selectedSortOption = selectedOption;
                              });
                              // TODO: Реализовать функцию сортировки на основе выбранного варианта
                              // print("Выбран вариант сортировки: $selectedOption");
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ───── Tabs ─────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _currentTab = 0),
                              child: Text(
                                'Мои отзывы',
                                style: TextStyle(
                                  color: _currentTab == 0 ? accentColor : Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () => setState(() => _currentTab = 1),
                              child: Text(
                                'Отзывы на мои объявления',
                                style: TextStyle(
                                  color: _currentTab == 1 ? accentColor : Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Stack(
                          children: [
                            Container(
                              height: 1,
                              width: double.infinity,
                              color: Colors.white24,
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              left: _currentTab == 0 ? 0 : 112,
                              child: Container(
                                height: 2,
                                width: _currentTab == 0 ? 90 : 205,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: _buildReviewContent(),
                  ),

                  const SizedBox(height: 80), // под bottom nav
                ],
              ),
            ),
            bottomNavigationBar: BottomNavigation(
              onItemSelected: (index) {
                context.read<NavigationBloc>().add(SelectNavigationIndexEvent(index));
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewContent() {
    List<ReviewModel> currentReviews;
    switch (_currentTab) {
      case 0:
        currentReviews = _myReviews;
        break;
      case 1:
        currentReviews = _reviewsOnMyListings;
        break;
      default:
        currentReviews = [];
    }

    if (currentReviews.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: currentReviews.length,
        itemBuilder: (context, index) {
          return ReviewCard(review: currentReviews[index], isMyListingsTab: _currentTab == 1);
        },
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/offers/Applications_for_me.png',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 24),
          const Text(
            'Due Bambini Комплект \nдетский стол + стул,50x50x50см',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
  }
}


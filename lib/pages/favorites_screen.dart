import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/widgets/header.dart';
import 'package:lidle/widgets/sort_filter_dialog.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import '../constants.dart';
import '../widgets/bottom_navigation.dart';
import '../models/home_models.dart';
import '../widgets/listing_card.dart';
import '../hive_service.dart';
import 'package:lidle/pages/home_page.dart';

class FavoritesScreen extends StatefulWidget {
  static const routeName = '/favorites';

  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Listing> _favoritedListings = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    final favoriteIds = HiveService.getFavorites();
    final allListings = ListingsBloc.staticListings;
    setState(() {
      _favoritedListings = allListings
          .where((listing) => favoriteIds.contains(listing.id))
          .toList();
    });
  }

  void _sortListings(Set<SortOption> options) {
    // Вспомогательная функция для парсинга цены из строки.
    double _parsePrice(String price) {
      try {
        // Удаляем все символы, кроме цифр, и преобразуем в число.
        return double.parse(price.replaceAll(RegExp(r'[^0-9]'), ''));
      } catch (e) {
        return 0.0; // Возвращаем 0 в случае ошибки.
      }
    }

    // Вспомогательная функция для парсинга даты. Предполагается формат "ДД.ММ.ГГГГ".
    DateTime _parseDate(String date) {
      try {
        final parts = date.split('.');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } catch (e) {
        // Обработка ошибок парсинга
      }
      // Возвращаем старую дату по умолчанию для некорректных форматов.
      return DateTime(1970);
    }

    // Приоритет сортировки: newest, oldest, mostExpensive, cheapest
    const priorityOrder = [
      SortOption.newest,
      SortOption.oldest,
      SortOption.mostExpensive,
      SortOption.cheapest,
    ];

    SortOption? selectedOption;
    for (final option in priorityOrder) {
      if (options.contains(option)) {
        selectedOption = option;
        break;
      }
    }

    if (selectedOption != null) {
      setState(() {
        switch (selectedOption!) {
          case SortOption.newest:
            _favoritedListings.sort(
              (a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)),
            );
            break;
          case SortOption.oldest:
            _favoritedListings.sort(
              (a, b) => _parseDate(a.date).compareTo(_parseDate(b.date)),
            );
            break;
          case SortOption.mostExpensive:
            _favoritedListings.sort(
              (a, b) => _parsePrice(b.price).compareTo(_parsePrice(a.price)),
            );
            break;
          case SortOption.cheapest:
            _favoritedListings.sort(
              (a, b) => _parsePrice(a.price).compareTo(_parsePrice(b.price)),
            );
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile ||
            state is NavigationToHome ||
            state is NavigationToFavorites) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: primaryBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 21, right: 23),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Header(),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: SvgPicture.asset(
                        'assets/home_page/marker-pin.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: const Text(
                        'г. Мариуполь. ДНР',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFAAAAAA),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacementNamed(HomePage.routeName);
                        }
                      },
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: textPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Мое избранное',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.swap_vert,
                        color: textPrimary,
                        size: 24,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) =>
                              SortFilterDialog(onSortChanged: _sortListings),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _favoritedListings.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: Text(
                            'Пока что здесь пусто',
                            style: TextStyle(color: textMuted, fontSize: 16),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 9,
                                mainAxisSpacing: 0,
                                mainAxisExtent: 263,
                              ),
                          itemCount: _favoritedListings.length,
                          itemBuilder: (context, index) {
                            return ListingCard(
                              listing: _favoritedListings[index],
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigation(
          onItemSelected: (index) {
            context.read<NavigationBloc>().add(
              SelectNavigationIndexEvent(index),
            );
          },
        ),
      ),
    );
  }
}

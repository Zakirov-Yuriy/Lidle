import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/listings/listings_state.dart';
import 'package:lidle/blocs/wishlist/wishlist_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart'; // Import SelectionDialog
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import '../constants.dart';
import '../widgets/navigation/bottom_navigation.dart';
import '../models/home_models.dart';
import '../widgets/cards/listing_card.dart';
import '../hive_service.dart';
import 'package:lidle/pages/home_page.dart';

class FavoritesScreen extends StatefulWidget {
  static const routeName = '/favorites';

  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Set<String> _selectedSortOptions = {}; // New state for selected sort options
  bool _wishlistLoadedOnce = false; // Флаг для предотвращения множественной загрузки

  @override
  void initState() {
    super.initState();
    _selectedSortOptions.add('Сначала новые'); // Default sort option
    
    // 📱 Загружаем wishlist при открытии экрана (только один раз)
    if (!_wishlistLoadedOnce) {
      _wishlistLoadedOnce = true; // Устанавливаем флаг ДО async операции
      Future.microtask(() {
        if (mounted) {
          context.read<WishlistBloc>().add(const LoadWishlistEvent());
          print('🔄 FavoritesScreen.initState: Загружаем wishlist');
        }
      });
    }
  }

  List<Listing> _getFavoritedListings(List<Listing> allListings, {Set<int>? wishlistIds}) {
    // Используем ID из WishlistBloc если предоставлены, иначе из Hive
    final ids = wishlistIds ?? HiveService.getFavorites().map((id) => int.parse(id)).toSet();
    
    // Фильтруем объявления, которые есть в избранном
    final favorited = allListings
        .where((listing) {
          // listing.id может быть String или int, приводим к String для сравнения
          final listingIdStr = listing.id.toString();
          return ids.any((id) => id.toString() == listingIdStr);
        })
        .toList();
    
    print('📊 FavoritesScreen._getFavoritedListings: Всего объявлений: ${allListings.length}, Избранных: ${favorited.length}, IDs избранного: $ids');
    
    return favorited;
  }

  List<Listing> _sortListingsFunc(
    Set<String> selectedOptions,
    List<Listing> listings,
  ) {
    // Вспомогательная функция для парсинга цены из строки.
    double _parsePrice(String price) {
      try {
        // Удаляем все символы, кроме цифр, и преобразуем в число.
        return double.parse(price.replaceAll(RegExp(r'[^0-9]'), ''));
      } catch (e) {
        return 0.0; // Возвращаем 0 в случае ошибки.
      }
    }

    // Вспомогательная функция для парсинга даты. API возвращает формат "DD.MM.YYYY".
    DateTime _parseDate(String date) {
      try {
        // Разбираем формат "DD.MM.YYYY"
        final parts = date.split('.');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } catch (e) {
        // Error parsing, return a very old date
      }
      return DateTime(1970);
    }

    SortOption? chosenSortOption;
    if (selectedOptions.contains('Сначала новые')) {
      chosenSortOption = SortOption.newest;
    } else if (selectedOptions.contains('Сначала старые')) {
      chosenSortOption = SortOption.oldest;
    } else if (selectedOptions.contains('Сначала дорогие')) {
      chosenSortOption = SortOption.mostExpensive;
    } else if (selectedOptions.contains('Сначала дешевые')) {
      chosenSortOption = SortOption.cheapest;
    }

    if (chosenSortOption != null) {
      switch (chosenSortOption) {
        case SortOption.newest:
          listings.sort(
            (a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)),
          );
          break;
        case SortOption.oldest:
          listings.sort(
            (a, b) => _parseDate(a.date).compareTo(_parseDate(b.date)),
          );
          break;
        case SortOption.mostExpensive:
          listings.sort(
            (a, b) => _parsePrice(b.price).compareTo(_parsePrice(a.price)),
          );
          break;
        case SortOption.cheapest:
          listings.sort(
            (a, b) => _parsePrice(a.price).compareTo(_parsePrice(b.price)),
          );
          break;
      }
    }

    return listings;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        if (connectivityState is ConnectedState) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.read<WishlistBloc>().add(const LoadWishlistEvent());
            }
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(onRetry: () {
              context.read<ConnectivityBloc>().add(const CheckConnectivityEvent());
            });
          }

          return MultiBlocListener(
            listeners: [
              BlocListener<NavigationBloc, NavigationState>(
                listener: (context, state) {
                  if (state is NavigationToProfile ||
                      state is NavigationToHome ||
                      state is NavigationToFavorites ||
                      state is NavigationToMessages) {
                    context.read<NavigationBloc>().executeNavigation(context);
                  }
                },
              ),
              BlocListener<ListingsBloc, ListingsState>(
                listener: (context, state) {
                  if (state is ListingsLoaded) {
                    // Обновляем favorites при изменении listings
                    setState(() {});
                  }
                },
              ),
              BlocListener<WishlistBloc, WishlistState>(
                listener: (context, state) {
                  // Когда wishlist обновляется, переотчитываемся
                  if (state is WishlistLoaded || 
                      state is WishlistItemAdded || 
                      state is WishlistItemRemoved) {
                    print('🔄 FavoritesScreen: WishlistBloc обновился, переотчитываемся');
                    setState(() {});
                  }
                },
              ),
            ],
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
                          Navigator.of(
                            context,
                          ).pushReplacementNamed(HomePage.routeName);
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
                    _buildFilterDropdown(
                      label: _selectedSortOptions.isEmpty
                          ? 'Сначала новые' // Default display if nothing selected
                          : _selectedSortOptions.join(', '),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return SelectionDialog(
                              title: 'Сортировать товар',
                              options: const [
                                'Сначала новые',
                                'Сначала старые',
                                'Сначала дорогие',
                                'Сначала дешевые',
                              ],
                              selectedOptions: _selectedSortOptions,
                              onSelectionChanged: (Set<String> selected) {
                                setState(() {
                                  _selectedSortOptions = selected;
                                  // Sorting will be applied in BlocBuilder
                                });
                              },
                              allowMultipleSelection:
                                  false, // Only one sort option at a time
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: BlocBuilder<WishlistBloc, WishlistState>(
                  builder: (context, wishlistState) {
                    return BlocBuilder<ListingsBloc, ListingsState>(
                      builder: (context, listingsState) {
                        if (listingsState is ListingsLoaded) {
                          // Получаем ID избранного из WishlistBloc если есть
                          Set<int>? wishlistIds;
                          if (wishlistState is WishlistLoaded) {
                            wishlistIds = wishlistState.wishlistIds;
                          }
                          
                          List<Listing> favoritedListings =
                              _getFavoritedListings(listingsState.listings, wishlistIds: wishlistIds);

                          // Применяем сортировку если выбрана
                          if (_selectedSortOptions.isNotEmpty) {
                            favoritedListings = _sortListingsFunc(
                              _selectedSortOptions,
                              List.from(favoritedListings), // Копируем список
                            );
                          }

                          if (favoritedListings.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Center(
                                child: Text(
                                  'Пока что здесь пусто',
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 9,
                                    mainAxisSpacing: 0,
                                    mainAxisExtent: 263,
                                  ),
                              itemCount: favoritedListings.length,
                              itemBuilder: (context, index) {
                                return ListingCard(
                                  listing: favoritedListings[index],
                                );
                              },
                            ),
                          );
                        } else {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Center(
                              child: Text(
                                'Загрузка...',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
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
      },
    ),
  );
}

  // Helper widget for building dropdowns, similar to real_estate_listings_screen.dart
  Widget _buildFilterDropdown({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(Icons.import_export, color: Colors.white, size: 25),
    );
  }
}

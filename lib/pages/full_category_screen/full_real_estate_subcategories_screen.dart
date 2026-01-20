import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/full_category_screen/full_real_estate_apartments_screen.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/catalog/catalog_bloc.dart';
import 'package:lidle/blocs/catalog/catalog_event.dart';
import 'package:lidle/blocs/catalog/catalog_state.dart';
import 'map_screen.dart';

// ============================================================
// "Экран подкатегорий недвижимости"
// ============================================================

class FullRealEstateSubcategoriesScreen extends StatefulWidget {
  const FullRealEstateSubcategoriesScreen({super.key});

  @override
  State<FullRealEstateSubcategoriesScreen> createState() =>
      _FullRealEstateSubcategoriesScreenState();
}

class _FullRealEstateSubcategoriesScreenState
    extends State<FullRealEstateSubcategoriesScreen> {
  bool _showAllActive = true;

  @override
  void initState() {
    super.initState();
    // Load real estate catalog (ID: 1) only if not already loaded
    final currentState = context.read<CatalogBloc>().state;
    if (!(currentState is CatalogLoaded && currentState.catalog.id == 1)) {
      context.read<CatalogBloc>().add(LoadCatalog(1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: primaryBackground,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: primaryBackground,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 20,
                        right: 23,
                        top: 20,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [const Header()],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.arrow_back_ios,
                              color: activeIconColor,
                              size: 16,
                            ),
                          ),
                          const Text(
                            'Назад',
                            style: TextStyle(
                              color: activeIconColor,
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
                              'Отмена',
                              style: TextStyle(
                                color: activeIconColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 25.0, right: 25),
                child: Text(
                  'Категория: Недвижимость',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(child: _buildContent(state)),
              Padding(
                padding: const EdgeInsets.only(right: 25, left: 25, bottom: 57),

                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 51,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showAllActive = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showAllActive
                              ? const Color(0xFF009EE2)
                              : primaryBackground,
                          side: _showAllActive
                              ? null
                              : const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          'Показать все',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 51,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showAllActive = false;
                          });
                          Navigator.pushNamed(context, MapScreen.routeName);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_showAllActive
                              ? const Color(0xFF009EE2)
                              : primaryBackground,
                          side: !_showAllActive
                              ? null
                              : const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          'Показать на карте',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(CatalogState state) {
    if (state is CatalogLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF009EE2)),
      );
    } else if (state is CatalogError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки: ${state.message}',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<CatalogBloc>().add(LoadCatalog(1));
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    } else if (state is CatalogLoaded) {
      final categories = state.catalog.categories;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: categories.length + 1,
          itemBuilder: (context, index) {
            if (index < categories.length) {
              final category = categories[index];
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      category.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullRealEstateApartmentsScreen(
                            category: category,
                          ),
                        ),
                      );
                    },
                  ),
                  if (index < categories.length - 1)
                    const Divider(color: Colors.white24, height: 1),
                ],
              );
            } else {
              return const Divider(color: Colors.white24, height: 1);
            }
          },
        ),
      );
    } else {
      return const Center(
        child: Text('Загрузка...', style: TextStyle(color: Colors.white)),
      );
    }
  }
}

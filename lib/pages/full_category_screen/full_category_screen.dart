import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/catalog/catalog_bloc.dart';
import 'package:lidle/blocs/catalog/catalog_event.dart';
import 'package:lidle/blocs/catalog/catalog_state.dart';
import 'package:lidle/main.dart';
import 'universal_browse_category_screen.dart';

// ============================================================
// "Экран всех категорий предложений"
// ============================================================

class FullCategoryScreen extends StatefulWidget {
  static const String routeName = '/full-category';

  const FullCategoryScreen({super.key});

  @override
  State<FullCategoryScreen> createState() => _FullCategoryScreenState();
}

class _FullCategoryScreenState extends State<FullCategoryScreen>
    with RouteAware {
  @override
  void initState() {
    super.initState();
    context.read<CatalogBloc>().add(LoadCatalogs());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    // Перезагружаем список каталогов при возврате на экран
    context.read<CatalogBloc>().add(LoadCatalogs());
  }

  @override
  Widget build(BuildContext context) {
    // Перезагружаем список каталогов, если состояние CatalogLoaded (от другого экрана)
    final state = context.read<CatalogBloc>().state;
    if (state is CatalogLoaded) {
      context.read<CatalogBloc>().add(LoadCatalogs());
    }
    return Scaffold(
      backgroundColor: const Color(0xFF1D2835),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20, right: 23, top: 20),
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
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12, left: 25, top: 7),
            child: Text(
              'Выберите категории публикации',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<CatalogBloc, CatalogState>(
              builder: (context, state) {
                if (state is CatalogLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is CatalogsLoaded) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: 25,
                      right: 25,
                      bottom: 106,
                      top: 0,
                    ),
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 120 / 83,
                          ),
                      itemCount: state.catalogs.length,
                      itemBuilder: (context, index) {
                        final catalog = state.catalogs[index];
                        return GestureDetector(
                          onTap: () {
                            // Универсальный экран для ВСЕХ каталогов, включая недвижимость
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UniversalBrowseCategoryScreen(
                                      catalogId: catalog.id,
                                      catalogName: catalog.name,
                                    ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Stack(
                              children: [
                                catalog.thumbnail != null &&
                                        catalog.thumbnail!.isNotEmpty &&
                                        catalog.thumbnail!.startsWith('http')
                                    ? Image.network(
                                        catalog.thumbnail!,
                                        height: 83,
                                        width: 120,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                height: 83,
                                                width: 120,
                                                color: Colors.grey[700],
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation(
                                                            Colors.white,
                                                          ),
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                height: 83,
                                                width: 120,
                                                color: const Color(0xFF2A3A4F),
                                                child: Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        color: Colors.white70,
                                                        size: 24,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        catalog.name,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                      )
                                    : Container(
                                        height: 83,
                                        width: 120,
                                        color: const Color(0xFF2A3A4F),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.category,
                                                color: Colors.white70,
                                                size: 24,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                catalog.name,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                ),
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
                } else if (state is CatalogError) {
                  return Center(
                    child: Text(
                      'Ошибка: ${state.message}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_item.dart';
import 'package:lidle/pages/products/cart_screen.dart';
import 'package:lidle/pages/products/product_details_screen.dart';
import 'package:lidle/services/cart_service.dart';
import 'package:lidle/services/products_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/products/product_tile.dart';

/// Витрина товаров.
///
/// Категория здесь НЕ обязательна, в отличие от объявлений: товаров на порядки
/// меньше, и «показать всё» осмысленно. Витрина должна открываться без единого
/// фильтра, поэтому первый экран это просто список.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, this.categoryId, this.categoryName});

  /// Открыть сразу в разделе. Пусто — вся витрина.
  final int? categoryId;
  final String? categoryName;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ProductCategory> _categories = const [];
  final List<ProductItem> _products = [];

  int? _categoryId;
  String? _categoryName;
  String _sort = 'new';
  bool _inStockOnly = false;

  int _page = 1;
  bool _hasMore = false;

  bool _isLoading = true;
  bool _isLoadingMore = false;

  int _cartCount = 0;

  /// Поиск не дёргаем на каждую букву: человек печатает быстрее, чем отвечает
  /// сервер, и без задержки список дёргался бы на каждом символе.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();

    _categoryId = widget.categoryId;
    _categoryName = widget.categoryName;

    _scrollController.addListener(_onScroll);

    _load();
    _loadCategories();
    _refreshCartCount();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final tree = await ProductsService.catalogs();

    if (!mounted) return;

    // Разделы показываем плоской лентой первого уровня: в витрине это
    // навигация, а не дерево. За глубиной человек проваливается внутрь.
    final flat = <ProductCategory>[];
    for (final catalog in tree) {
      flat.addAll(catalog.children);
    }

    setState(() => _categories = flat);
  }

  Future<void> _refreshCartCount() async {
    final result = await CartService.show();

    if (!mounted || !result.isOk) return;

    setState(() => _cartCount = result.cart?.itemsCount ?? 0);
  }

  Future<void> _load({bool more = false}) async {
    if (more && (!_hasMore || _isLoadingMore)) return;

    setState(() {
      if (more) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _page = 1;
      }
    });

    final page = await ProductsService.list(
      categoryId: _categoryId,
      search: _searchController.text,
      inStockOnly: _inStockOnly,
      sort: _sort,
      page: more ? _page + 1 : 1,
    );

    if (!mounted) return;

    setState(() {
      if (more) {
        _products.addAll(page.items);
        _isLoadingMore = false;
      } else {
        _products
          ..clear()
          ..addAll(page.items);
        _isLoading = false;
      }

      _page = page.currentPage;
      _hasMore = page.hasMore;
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.pixels > position.maxScrollExtent - 400) {
      _load(more: true);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () => _load());
  }

  Future<void> _addToCart(ProductItem product) async {
    final result = await CartService.add(product.id);

    if (!mounted) return;

    if (!result.isOk) {
      SnackBarHelper.showError(context, result.error!);
      return;
    }

    setState(() => _cartCount = result.cart?.itemsCount ?? _cartCount);
    SnackBarHelper.showSuccess(context, 'Товар в корзине');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            _buildTopBar(),
            _buildSearch(),
            if (_categories.isNotEmpty) _buildCategories(),
            _buildSortRow(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: activeIconColor),
                    )
                  : _buildGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              children: [
                Icon(Icons.arrow_back_ios, color: activeIconColor, size: 16),
                SizedBox(width: 4),
                Text(
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
          const Spacer(),
          GestureDetector(
            onTap: _openCart,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    color: Colors.white, size: 26),
                if (_cartCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: activeIconColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_cartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
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
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _categoryName ?? 'Товары',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Поиск по товарам',
              hintStyle: const TextStyle(color: textMuted, fontSize: 15),
              prefixIcon: const Icon(Icons.search, color: textMuted, size: 20),
              filled: true,
              fillColor: formBackground,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
        children: [
          _categoryChip(null, 'Все'),
          ..._categories.map((c) => _categoryChip(c, c.name)),
        ],
      ),
    );
  }

  Widget _categoryChip(ProductCategory? category, String label) {
    final isSelected = _categoryId == category?.id;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _categoryId = category?.id;
            _categoryName = category?.name;
          });
          _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? activeIconColor : formBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : textSecondary,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 4, 25, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _sortChip('new', 'Сначала новые'),
                  _sortChip('price_asc', 'Дешевле'),
                  _sortChip('price_desc', 'Дороже'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _inStockOnly = !_inStockOnly);
              _load();
            },
            child: Row(
              children: [
                Icon(
                  _inStockOnly
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: _inStockOnly ? activeIconColor : textMuted,
                  size: 20,
                ),
                const SizedBox(width: 4),
                const Text(
                  'В наличии',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String value, String label) {
    final isSelected = _sort == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: isSelected
            ? null
            : () {
                setState(() => _sort = value);
                _load();
              },
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeIconColor : textMuted,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Здесь пока ничего нет. Попробуйте другой раздел или поиск.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 15),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: activeIconColor,
      onRefresh: () => _load(),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(25, 4, 25, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        itemCount: _products.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _products.length) {
            return const Center(
              child: CircularProgressIndicator(color: activeIconColor),
            );
          }

          final product = _products[index];

          return ProductTile(
            product: product,
            onTap: () => _openProduct(product),
            onAdd: () => _addToCart(product),
          );
        },
      ),
    );
  }

  Future<void> _openProduct(ProductItem product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(productId: product.id),
      ),
    );

    if (mounted) _refreshCartCount();
  }

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );

    if (mounted) _refreshCartCount();
  }
}

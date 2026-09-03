import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_item.dart';
import 'package:lidle/pages/products/cart_screen.dart';
import 'package:lidle/services/cart_service.dart';
import 'package:lidle/services/products_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Карточка товара.
class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final PageController _pageController = PageController();

  ProductItem? _product;
  bool _isLoading = true;
  bool _isAdding = false;

  int _quantity = 1;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final product = await ProductsService.details(widget.productId);

    if (!mounted) return;

    setState(() {
      _product = product;
      _isLoading = false;
    });
  }

  Future<void> _addToCart() async {
    final product = _product;
    if (product == null || _isAdding) return;

    setState(() => _isAdding = true);

    final result = await CartService.add(product.id, quantity: _quantity);

    if (!mounted) return;

    setState(() => _isAdding = false);

    if (!result.isOk) {
      SnackBarHelper.showError(context, result.error!);
      return;
    }

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
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: activeIconColor),
                    )
                  : _product == null
                      ? const Center(
                          child: Text(
                            'Товар не найден',
                            style: TextStyle(color: textMuted, fontSize: 15),
                          ),
                        )
                      : _buildBody(_product!),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _product == null ? null : _buildBottomBar(_product!),
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ProductItem product) {
    final images = product.images.isNotEmpty
        ? product.images
        : (product.image != null ? [product.image!] : <String>[]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 24),
      children: [
        if (images.isNotEmpty) _buildGallery(images),
        const SizedBox(height: 16),
        Text(
          product.priceLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          product.name,
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        const SizedBox(height: 12),
        _buildStock(product),
        if (product.shop != null) ...[
          const SizedBox(height: 12),
          _buildShop(product.shop!),
        ],
        if (product.cookingTimeMinutes != null) ...[
          const SizedBox(height: 12),
          _card(
            child: Row(
              children: [
                const Icon(Icons.schedule, color: textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Готовят примерно ${product.cookingTimeMinutes} мин',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
        if (product.description != null && product.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Описание',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description!,
                  style: const TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGallery(List<String> images) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 280,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentImage = index),
              itemCount: images.length,
              itemBuilder: (context, index) => Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: secondaryBackground,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: textMuted, size: 40),
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentImage ? activeIconColor : textMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStock(ProductItem product) {
    if (!product.inStock) {
      return _card(
        child: const Text(
          'Нет в наличии',
          style: TextStyle(color: textMuted, fontSize: 15),
        ),
      );
    }

    return _card(
      child: Row(
        children: [
          Text(
            'В наличии: ${product.stockQuantity} шт.',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const Spacer(),
          _stepper(product),
        ],
      ),
    );
  }

  /// Счётчик ограничен остатком: предлагать взять больше, чем есть, значит
  /// обещать то, чего мы не выполним, а отказ придёт только при оформлении.
  Widget _stepper(ProductItem product) {
    return Row(
      children: [
        _stepButton(Icons.remove, _quantity > 1, () {
          setState(() => _quantity--);
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '$_quantity',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _stepButton(Icons.add, _quantity < product.stockQuantity, () {
          setState(() => _quantity++);
        }),
      ],
    );
  }

  Widget _stepButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: enabled ? Colors.white : textMuted, size: 18),
      ),
    );
  }

  Widget _buildShop(ShopBrief shop) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Где забрать',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            shop.name,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          if (shop.address != null && shop.address!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              shop.address!,
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'Доставки нет: заказ забирают в точке по коду получения.',
            style: TextStyle(color: textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ProductItem product) {
    final canBuy = product.inStock;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 8, 25, 12),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canBuy ? activeIconColor : secondaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: canBuy && !_isAdding ? _addToCart : null,
            child: Text(
              canBuy ? 'Добавить в корзину' : 'Нет в наличии',
              style: TextStyle(
                color: canBuy ? Colors.white : textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

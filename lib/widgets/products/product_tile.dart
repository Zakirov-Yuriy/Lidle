import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_item.dart';
import 'package:lidle/services/cart_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';

/// Карточка товара в витрине.
///
/// Товара без остатка НЕ прячем: карточка всё равно интересна, а спрятать её
/// значит потерять товар из выдачи и из поиска. Вместо этого гасим её и
/// подписываем «нет в наличии», чтобы человек видел причину.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.onAdd,
  });

  final ProductItem product;
  final VoidCallback onTap;

  /// Быстрое добавление в корзину прямо из списка. Не показываем, если товара
  /// нет: кнопка, которая всегда отказывает, только раздражает.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final available = product.inStock;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Картинка занимает ОСТАТОК высоты, а не квадрат.
            //
            // Так было: квадратная картинка плюс текст с кнопкой не влезали в
            // ячейку сетки, и снизу вылезала жёлто-чёрная полоса переполнения.
            // Причём на сколько именно — зависело от длины названия, то есть
            // подобрать соотношение сторон раз и навсегда невозможно. Теперь
            // подпись занимает столько, сколько ей нужно, а картинка забирает
            // всё, что осталось.
            Expanded(
              child: Opacity(
                opacity: available ? 1 : 0.45,
                child: SizedBox(
                  width: double.infinity,
                  child: _image(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.priceLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  if (product.shop != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.shop!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                  // Оценка товара (15.09.2026): звезда, значение и число
                  // оценок, как на карточке главной. Показываем только когда
                  // отзывы есть: «0,0 · 0 оценок» отпугивает сильнее, чем
                  // отсутствие строки.
                  if (product.rating != null && product.reviewsCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFB800), size: 14),
                        const SizedBox(width: 3),
                        Text(
                          product.rating!.toStringAsFixed(1).replaceAll('.', ','),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '· ${product.reviewsCount}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: textMuted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Дата появления на витрине (15.09.2026): такая же подпись,
                  // как на карточке главной, чтобы товар в разделе и товар в
                  // ленте читались одинаково.
                  if (product.date.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.date,
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 8),
                  if (!available)
                    const Text(
                      'Нет в наличии',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    )
                  else if (onAdd != null)
                    _CartControl(product: product, onAdd: onAdd!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image() {
    final url = product.image;

    if (url == null || url.isEmpty) {
      return Container(
        color: secondaryBackground,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: textMuted, size: 32),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => Container(
        color: secondaryBackground,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined,
            color: textMuted, size: 32),
      ),
    );
  }
}

/// Кнопка «В корзину», которая превращается в счётчик (14.09.2026).
///
/// Пока товара в корзине нет — обычная кнопка. Как только он там оказался, на
/// её месте встают минус, число и плюс: ровно так это устроено в магазинах, к
/// которым человек привык, и по-другому он ищет, где поменять количество, и
/// не находит.
///
/// Количество берётся из общего состояния корзины (`CartService.quantities`),
/// а не из своего поля: товар могли положить или убрать на другом экране, и
/// собственная память плитки разошлась бы с правдой.
class _CartControl extends StatefulWidget {
  const _CartControl({required this.product, required this.onAdd});

  final ProductItem product;
  final VoidCallback onAdd;

  @override
  State<_CartControl> createState() => _CartControlState();
}

class _CartControlState extends State<_CartControl> {
  /// Запрос ушёл, ответа нет. Кнопки на это время гасим: два быстрых нажатия
  /// на плюс отправили бы два запроса, и второй перезаписал бы первый.
  bool _isBusy = false;

  Future<void> _set(int quantity) async {
    if (_isBusy) return;

    setState(() => _isBusy = true);

    final result = quantity <= 0
        ? await CartService.remove(widget.product.id)
        : await CartService.setQuantity(widget.product.id, quantity);

    if (!mounted) return;

    setState(() => _isBusy = false);

    if (!result.isOk) SnackBarHelper.showError(context, result.error!);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<int, int>>(
      valueListenable: CartService.quantities,
      builder: (context, quantities, _) {
        final inCart = quantities[widget.product.id] ?? 0;

        return SizedBox(
          width: double.infinity,
          height: 34,
          child: inCart == 0 ? _addButton() : _stepper(inCart),
        );
      },
    );
  }

  Widget _addButton() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: activeIconColor),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: _isBusy ? null : widget.onAdd,
      child: const Text(
        'В корзину',
        style: TextStyle(color: activeIconColor, fontSize: 13),
      ),
    );
  }

  Widget _stepper(int inCart) {
    // Больше остатка не даём набрать: оформление всё равно откажет, и лучше
    // сказать об этом погасшим плюсом, чем отказом на последнем шаге.
    final canAdd = inCart < widget.product.stockQuantity;

    return Container(
      decoration: BoxDecoration(
        color: activeIconColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _step(Icons.remove, onTap: () => _set(inCart - 1)),
          Expanded(
            child: Center(
              child: Text(
                '$inCart',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _step(Icons.add, onTap: canAdd ? () => _set(inCart + 1) : null),
        ],
      ),
    );
  }

  /// Минус и плюс: на всю высоту кнопки, чтобы попадать пальцем, а не целиться.
  Widget _step(IconData icon, {VoidCallback? onTap}) {
    final disabled = onTap == null || _isBusy;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 34,
        child: Icon(
          icon,
          size: 18,
          color: disabled ? Colors.white38 : Colors.white,
        ),
      ),
    );
  }
}

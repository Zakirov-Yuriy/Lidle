import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_item.dart';

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
                  const SizedBox(height: 8),
                  if (!available)
                    const Text(
                      'Нет в наличии',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    )
                  else if (onAdd != null)
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: activeIconColor),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onAdd,
                        child: const Text(
                          'В корзину',
                          style: TextStyle(color: activeIconColor, fontSize: 13),
                        ),
                      ),
                    ),
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

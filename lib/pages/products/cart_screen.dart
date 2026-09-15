// `PathOperation` нужен вырезу под галочку. Явно, а не надеясь на реэкспорт
// из material: вырез перестал бы собираться от смены версии Flutter.
import 'dart:ui' show PathOperation;

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/cart_snapshot.dart';
import 'package:lidle/pages/products/checkout_screen.dart';
import 'package:lidle/services/cart_service.dart';
import 'package:lidle/services/product_favorites_service.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Корзина.
///
/// Разложена по точкам продавца, потому что товары разных точек станут РАЗНЫМИ
/// заказами: у каждого свой код получения и своя выдача. Человек должен
/// увидеть это до оформления, а не после.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.preselectedProductIds});

  /// Что отметить галочкой сразу при открытии (15.09.2026).
  ///
  /// Приходит с карточки товара: человек нажал зелёную «В корзине» и попал
  /// сюда ради ЭТОЙ вещи. Искать её галочку среди десятка других — лишний
  /// шаг там, где намерение уже высказано.
  final Set<int>? preselectedProductIds;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  CartSnapshot? _cart;
  bool _isLoading = true;
  bool _isBusy = false;

  /// Номера отмеченных товаров.
  ///
  /// Галочки видны ВСЕГДА (15.09.2026). До этого они появлялись по долгому
  /// нажатию, и о таком способе человек не догадывался: он видел корзину без
  /// единой галочки и не понимал, чем отличается «оформить» от «оформить
  /// выбранное». Теперь выбор виден сразу, прямо на снимках товаров.
  final Set<int> _picked = <int>{};

  /// Начальную отметку ставим один раз. Иначе каждое перечитывание корзины
  /// возвращало бы галочку, которую человек только что снял.
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final result = await CartService.show();

    if (!mounted) return;

    setState(() {
      _cart = result.cart ?? CartSnapshot.empty();
      _isLoading = false;

      if (!_seeded) {
        _seeded = true;

        final wanted = widget.preselectedProductIds ?? const <int>{};
        final available = _availableProductIds();

        _picked.addAll(wanted.where(available.contains));
      }

      // Из выбора убираем то, чего в корзине больше нет: позицию могли
      // удалить или купить, а её номер остался бы отмеченным и ушёл в
      // следующий заказ.
      _picked.removeWhere((id) => !_productIds().contains(id));
    });
  }

  /// Номера всех позиций корзины.
  Set<int> _productIds() {
    final cart = _cart;

    if (cart == null) return <int>{};

    return cart.shops
        .expand((shop) => shop.items)
        .map((line) => line.productId)
        .toSet();
  }

  /// Номера позиций, которые можно купить прямо сейчас.
  ///
  /// «Выбрать все» отмечает именно их: недоступную позицию оформить нельзя, и
  /// галочка на ней означала бы обещание, которого мы не сдержим.
  Set<int> _availableProductIds() {
    final cart = _cart;

    if (cart == null) return <int>{};

    return cart.shops
        .expand((shop) => shop.items)
        .where((line) => line.isAvailable)
        .map((line) => line.productId)
        .toSet();
  }

  void _toggle(int productId) {
    setState(() {
      if (!_picked.remove(productId)) _picked.add(productId);
    });
  }

  void _toggleAll() {
    setState(() {
      final all = _availableProductIds();

      // Отмечено всё — снимаем всё. Так одна кнопка работает в обе стороны,
      // и не нужна вторая, «Снять выделение».
      if (_picked.length >= all.length) {
        _picked.clear();
      } else {
        _picked
          ..clear()
          ..addAll(all);
      }
    });
  }

  /// Любое действие возвращает корзину целиком, поэтому местное состояние не
  /// пересчитываем, а заменяем: склеивать своё представление с ответом значит
  /// однажды разойтись с сервером в количестве.
  Future<void> _apply(Future<CartResult> Function() action) async {
    if (_isBusy) return;

    setState(() => _isBusy = true);

    final result = await action();

    if (!mounted) return;

    setState(() {
      _isBusy = false;
      if (result.isOk) _cart = result.cart;
    });

    if (!result.isOk) SnackBarHelper.showError(context, result.error!);
  }

  @override
  Widget build(BuildContext context) {
    final cart = _cart;

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
                  : (cart == null || cart.isEmpty)
                      ? _buildEmpty()
                      : _buildList(cart),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          (cart == null || cart.isEmpty) ? null : _buildBottomBar(cart),
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
          if (_cart != null && !_cart!.isEmpty)
            GestureDetector(
              onTap: () => _apply(CartService.clear),
              child: const Text(
                'Очистить',
                style: TextStyle(color: textMuted, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Корзина пуста.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textMuted, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildList(CartSnapshot cart) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 24),
      children: [
        const Text(
          'Корзина',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if (cart.shops.length > 1)
          const Text(
            'Товары из разных точек станут отдельными заказами: каждый забирают '
            'в своей точке и по своему коду.',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        const SizedBox(height: 12),
        _buildPickBar(cart),
        ...cart.shops.map(_buildShopGroup),
      ],
    );
  }

  /// Строка «Выбрать все» над первой точкой.
  Widget _buildPickBar(CartSnapshot cart) {
    final all = _availableProductIds();
    final allPicked = all.isNotEmpty && _picked.length >= all.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CustomCheckbox(
            value: allPicked,
            onChanged: (_) => _toggleAll(),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _toggleAll,
            child: Text(
              allPicked ? 'Снять выбор' : 'Выбрать все',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          Text(
            _picked.isEmpty ? 'Ничего не выбрано' : 'Выбрано: ${_picked.length}',
            style: const TextStyle(color: textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildShopGroup(CartShopGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _money(group.total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (group.address != null && group.address!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              group.address!,
              style: const TextStyle(color: textMuted, fontSize: 13),
            ),
          ],
          if (!group.shopIsActive) ...[
            const SizedBox(height: 6),
            const Text(
              'Точка временно не принимает заказы.',
              style: TextStyle(color: Color(0xFFE0A63C), fontSize: 13),
            ),
          ],
          if (group.cookingTimeMinutes != null) ...[
            const SizedBox(height: 6),
            Text(
              'Готовят примерно ${group.cookingTimeMinutes} мин',
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          ...group.items.map(_buildLine),
        ],
      ),
    );
  }

  /// Позиция корзины (переделана 15.09.2026).
  ///
  /// Снимок слева, галочка — В УГЛУ снимка, а не отдельным столбиком перед
  /// ним: столбик забирал ширину у названия и уезжал от товара тем дальше,
  /// чем длиннее строка. В углу картинки галочка всегда рядом с тем, что
  /// отмечает.
  ///
  /// Снизу одна строка действий: сердечко, удаление и счётчик. Раньше
  /// удаление стояло справа от счётчика и читалось как «минус до нуля», то
  /// есть как часть счётчика. Теперь удаление слева, рядом с сердечком: оба
  /// про судьбу позиции, а не про её количество.
  Widget _buildLine(CartLine line) {
    final picked = _picked.contains(line.productId);

    return GestureDetector(
      // Нажатие по всей карточке отмечает: целиться строго в квадратик 24 на
      // 24 пальцем неудобно.
      onTap: line.isAvailable ? () => _toggle(line.productId) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(10),

          // Выбранную позицию обводим: галочка маленькая, а решение важное, и
          // человек должен видеть выбор, скользя глазами по списку.
          border: Border.all(
            color: picked ? activeIconColor : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhoto(line, picked),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Сумму недоступной позиции гасим и перечёркиваем.
                      //
                      // Так было: она рисовалась ровно так же, как у
                      // доступной, то есть белым и жирным. Человек видел
                      // «1 290 ₽» у товара и «0 ₽» в итоге и считал, что
                      // корзина не умеет складывать. Перечёркнутая цена сразу
                      // говорит, что эти деньги в счёт не идут.
                      Text(
                        _money(line.sum),
                        style: TextStyle(
                          color: line.isAvailable ? Colors.white : textMuted,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          decoration: line.isAvailable
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                          decorationColor: textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        line.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: line.isAvailable ? Colors.white : textMuted,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),

                      // «красный, 46»: какой именно вариант лежит в корзине.
                      // Две строки «Куртка Nika» по 4900 без подписи выглядят
                      // как задвоение, и человек удаляет нужную.
                      if (line.variantLabel.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          line.variantLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],

                      // Причина приходит готовой с сервера: «товара сегодня
                      // нет», «осталось только 2 шт.». Не переписываем её
                      // своими словами, они будут менее точными.
                      if (!line.isAvailable &&
                          line.unavailableReason != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          line.unavailableReason!,
                          style: const TextStyle(
                            color: Color(0xFFE0A63C),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildLineActions(line),
          ],
        ),
      ),
    );
  }

  /// Снимок товара с галочкой в ВЫРЕЗАННОМ углу (15.09.2026).
  ///
  /// Галочка не лежит поверх фотографии, а стоит в вырезе: у снимка срезан
  /// левый верхний угол ровно под неё. Поверх снимка галочка всегда спорила
  /// бы с тем, что под ней нарисовано, — на светлом кадре пропадала, на
  /// тёмном закрывала товар. В вырезе она стоит на фоне карточки и читается
  /// одинаково на любой фотографии.
  Widget _buildPhoto(CartLine line, bool picked) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: const _NotchedPhotoClipper(radius: 8, notch: 30),
              child: Opacity(
                opacity: line.isAvailable ? 1 : 0.45,
                child: line.image == null || line.image!.isEmpty
                    ? Container(
                        color: formBackground,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined,
                            color: textMuted, size: 24),
                      )
                    : Image.network(
                        line.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: formBackground,
                          alignment: Alignment.center,
                          child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: textMuted,
                              size: 24),
                        ),
                      ),
              ),
            ),
          ),
          // Ровно в вырезе: вырез 30, галочка 24, по 3 с каждой стороны.
          Positioned(
            left: 3,
            top: 3,
            child: _PhotoCheckbox(
              value: picked,
              // Недоступную позицию отметить нельзя: её всё равно не
              // оформить, и галочка обещала бы несбыточное.
              onTap: line.isAvailable ? () => _toggle(line.productId) : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Сердечко, удаление и счётчик.
  Widget _buildLineActions(CartLine line) {
    return Row(
      children: [
        // Сердечко (15.09.2026): передумал брать сейчас — сохрани, чтобы не
        // искать заново. Без него единственный выход из корзины — удаление, и
        // товар теряется совсем.
        _CartFavoriteButton(modelId: line.modelId),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: () => _apply(() => CartService.remove(line.productId)),
          behavior: HitTestBehavior.opaque,
          child: const Icon(Icons.delete_outline, color: textMuted, size: 22),
        ),
        const Spacer(),
        _stepButton(
          Icons.remove,
          () => _apply(
            () => CartService.setQuantity(line.productId, line.quantity - 1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '${line.quantity}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _stepButton(
          Icons.add,
          line.quantity < line.stockQuantity
              ? () => _apply(
                    () => CartService.setQuantity(
                        line.productId, line.quantity + 1),
                  )
              : null,
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: onTap == null ? textMuted : Colors.white, size: 16),
      ),
    );
  }

  Widget _buildBottomBar(CartSnapshot full) {
    // Считаем ТОЛЬКО отмеченное: галочки видны всегда, и итог обязан
    // отвечать именно им.
    final cart = full.onlyProducts(_picked);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 8, 25, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Итого',
                  style: TextStyle(color: textSecondary, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  _money(cart.total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            // Объясняем расхождение цифр словами, а не оставляем человека
            // гадать. Числа приходят с сервера готовыми: считать их на
            // клиенте значит однажды разойтись с сайтом.
            const SizedBox(height: 4),
            Text(
              _picked.isEmpty
                  ? 'Отметьте галочками то, что берёте сейчас. Остальное '
                      'останется в корзине.'
                  : 'В заказ пойдёт ${_positions(cart.availableItemsCount)}. '
                      'Остальное останется в корзине.',
              style: const TextStyle(color: textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeIconColor,
                  disabledBackgroundColor: secondaryBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Кнопку гасим, когда оформлять нечего. Раньше она была живой
                // и вела на экран оформления с нулевой суммой, где заказ
                // всё равно отклонял сервер.
                //
                // В режиме выбора без единой галочки кнопку НЕ гасим: она
                // должна ответить словами «отметьте, что берёте», а не молча
                // не нажиматься. Погашенная кнопка ничего не объясняет.
                onPressed: _isBusy || !full.canCheckout ? null : _openCheckout,
                child: Text(
                  _checkoutLabel(full, cart),
                  style: TextStyle(
                    color: _isBusy || !full.canCheckout
                        ? textMuted
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Что написать на кнопке.
  String _checkoutLabel(CartSnapshot full, CartSnapshot selected) {
    if (!full.canCheckout) return 'Нечего оформлять';

    return _picked.isEmpty
        ? 'Выберите товары'
        : 'Оформить ${_positions(selected.availableItemsCount)}';
  }

  Future<void> _openCheckout() async {
    final cart = _cart;

    if (cart == null) return;

    // Ничего не отмечено — не оформляем. Требование заказчика от 14.09.2026:
    // корзина не заказывается целиком сама собой, человек отмечает то, что
    // берёт сейчас. Заказ всей корзины делается кнопкой «Выбрать все», это
    // одно нажатие, зато человек видит, за что платит.
    if (_picked.isEmpty) {
      SnackBarHelper.showWarning(
        context,
        'Отметьте товары, которые берёте сейчас. '
        'Можно выбрать все одной кнопкой сверху.',
      );

      return;
    }

    final selected = cart.onlyProducts(_picked);

    if (!selected.canCheckout) {
      SnackBarHelper.showWarning(
        context,
        'Из отмеченного сейчас купить нечего',
      );

      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cart: selected,

          // Серверу шлём номера отмеченного. Сюда мы попадаем только с
          // непустым выбором: пустой список и отсутствующий для сервера
          // разные вещи, первый означает «ничего не беру».
          productIds: _picked.toList(),
        ),
      ),
    );

    if (!mounted) return;

    // Перечитываем корзину ВСЕГДА, а не только когда оформление вернуло
    // признак успеха.
    //
    // Так было: экран оформления уходил на «Заказ оформлен» через
    // pushReplacement, и кнопка «Готово» возвращалась сюда вообще без
    // значения. Признак терялся по дороге, корзина не перечитывалась, и
    // человек видел в ней товар, который только что купил. Пропадал он
    // только после ручного обновления.
    //
    // Полагаться на возвращённое значение здесь и не стоит: путей назад
    // несколько, и каждый новый пришлось бы не забыть научить его
    // возвращать. Лишний запрос к корзине стоит дешевле такой забывчивости.
    _load();
  }

  /// «1 позиция», «2 позиции», «5 позиций».
  ///
  /// Слово согласуем с числом: «в заказ пойдёт 2 позиция» читается как
  /// недоделка, даже если смысл понятен.
  String _positions(int count) {
    final tens = count % 100;
    final ones = count % 10;

    if (tens >= 11 && tens <= 14) return '$count позиций';
    if (ones == 1) return '$count позиция';
    if (ones >= 2 && ones <= 4) return '$count позиции';

    return '$count позиций';
  }

  String _money(double value) {
    final whole = value.truncate().toString();

    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }

    return '${buffer.toString()} ₽';
  }
}

/// Вырез под галочку в левом верхнем углу снимка (15.09.2026).
///
/// Скруглённый прямоугольник, из которого вычтен скруглённый квадрат в углу.
/// Вычитание, а не рисование поверх: поверх пришлось бы класть плашку цвета
/// карточки, и она рассыпалась бы при любой смене фона, а вырез есть форма
/// самой картинки.
class _NotchedPhotoClipper extends CustomClipper<Path> {
  const _NotchedPhotoClipper({required this.radius, required this.notch});

  /// Скругление углов снимка.
  final double radius;

  /// Сторона выреза.
  final double notch;

  @override
  Path getClip(Size size) {
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    // Квадрат выреза выведен ЗА края снимка на скругление: наружные его углы
    // не видны, а внутренний, единственный видимый, получается скруглённым —
    // иначе вырез выглядел бы вырубленным ножницами.
    final cut = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(-radius, -radius, notch, notch),
          Radius.circular(radius),
        ),
      );

    return Path.combine(PathOperation.difference, body, cut);
  }

  @override
  bool shouldReclip(covariant _NotchedPhotoClipper old) =>
      old.radius != radius || old.notch != notch;
}

/// Галочка в вырезе снимка (15.09.2026).
///
/// Своя, а не общий `CustomCheckbox`: тому нужен размер под вырез и галочка
/// внутри, а не залитый квадратик. Стоит она на фоне карточки, а не на
/// фотографии, поэтому подложка ей не нужна — нужна только рамка.
class _PhotoCheckbox extends StatelessWidget {
  const _PhotoCheckbox({required this.value, required this.onTap});

  final bool value;

  /// Пусто у позиции, которую нельзя купить: отмечать нечего.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: value ? activeIconColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value ? activeIconColor : Colors.white54,
            width: 1.5,
          ),
        ),
        child: value
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }
}

/// Сердечко на позиции корзины (15.09.2026).
///
/// Живёт на МОДЕЛИ, а не на варианте: в корзине лежит красная 46-го, а в
/// избранном человек ждёт увидеть куртку. Состояние общее с витриной
/// (`ProductFavoritesService`), поэтому сердечко, зажжённое здесь, горит и на
/// главной.
class _CartFavoriteButton extends StatelessWidget {
  const _CartFavoriteButton({required this.modelId});

  final int modelId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<int, int?>>(
      valueListenable: ProductFavoritesService.items,
      builder: (context, favorites, _) {
        final isFavorite = favorites.containsKey(modelId);

        return GestureDetector(
          onTap: () async {
            final error = await ProductFavoritesService.toggle(modelId);

            if (error != null && context.mounted) {
              SnackBarHelper.showError(context, error);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : textMuted,
            size: 22,
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/cart_snapshot.dart';
import 'package:lidle/pages/products/checkout_screen.dart';
import 'package:lidle/services/cart_service.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Корзина.
///
/// Разложена по точкам продавца, потому что товары разных точек станут РАЗНЫМИ
/// заказами: у каждого свой код получения и своя выдача. Человек должен
/// увидеть это до оформления, а не после.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  CartSnapshot? _cart;
  bool _isLoading = true;
  bool _isBusy = false;

  /// Режим выбора: слева от картинок появились галочки (14.09.2026).
  ///
  /// Включается долгим нажатием на позицию — так же, как выбор сообщений в
  /// мессенджерах, и человеку не надо ничему учиться. Второй вход в режим —
  /// «Оформить заказ» без единой галочки: тогда мы не оформляем, а сначала
  /// показываем галочки и просим отметить.
  bool _picking = false;

  /// Номера отмеченных товаров.
  final Set<int> _picked = <int>{};

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

      // Из выбора убираем то, чего в корзине больше нет: позицию могли
      // удалить или купить, а её номер остался бы отмеченным и ушёл в
      // следующий заказ.
      _picked.removeWhere((id) => !_productIds().contains(id));

      if (_picked.isEmpty) _picking = false;
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

  /// Долгое нажатие: включить выбор и сразу отметить эту позицию.
  void _startPicking(int productId, bool isAvailable) {
    if (!isAvailable) return;

    setState(() {
      _picking = true;
      _picked.add(productId);
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
  ///
  /// Показывается только в режиме выбора: пока человек ничего не отмечал,
  /// корзина заказывается целиком, и строка предлагала бы сделать то, что и
  /// так сделано.
  Widget _buildPickBar(CartSnapshot cart) {
    if (!_picking) return const SizedBox.shrink();

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
          GestureDetector(
            onTap: () => setState(() {
              _picking = false;
              _picked.clear();
            }),
            child: const Text(
              'Отменить',
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
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

  Widget _buildLine(CartLine line) {
    return GestureDetector(
      // Долгое нажатие по всей строке, а не по картинке: попасть в картинку
      // пальцем труднее, а намерение одно и то же.
      onLongPress: () => _startPicking(line.productId, line.isAvailable),

      // В режиме выбора обычное нажатие тоже отмечает: тыкать строго в
      // квадратик 22 на 22 неудобно.
      onTap: _picking && line.isAvailable
          ? () => _toggle(line.productId)
          : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_picking) ...[
            Padding(
              padding: const EdgeInsets.only(top: 17),
              child: CustomCheckbox(
                value: _picked.contains(line.productId),
                // Недоступную позицию отметить нельзя: её всё равно не
                // оформить, и галочка обещала бы несбыточное.
                onChanged: line.isAvailable
                    ? (_) => _toggle(line.productId)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              height: 56,
              child: line.image == null || line.image!.isEmpty
                  ? Container(
                      color: secondaryBackground,
                      child: const Icon(Icons.image_outlined,
                          color: textMuted, size: 20),
                    )
                  : Image.network(
                      line.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: secondaryBackground,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: textMuted, size: 20),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: line.isAvailable ? Colors.white : textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                // Сумму недоступной позиции гасим и перечёркиваем.
                //
                // Так было: она рисовалась ровно так же, как у доступной, то
                // есть белым и жирным. Человек видел «1 290 ₽» у товара и
                // «0 ₽» в итоге и считал, что корзина не умеет складывать.
                // Перечёркнутая цена сразу говорит, что эти деньги в счёт не
                // идут.
                Text(
                  _money(line.sum),
                  style: TextStyle(
                    color: line.isAvailable ? Colors.white : textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: line.isAvailable
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                    decorationColor: textMuted,
                  ),
                ),
                // Причину приходит готовой с сервера: «товара сегодня нет»,
                // «осталось только 2 шт.». Не переписываем её своими словами,
                // они будут менее точными.
                if (!line.isAvailable && line.unavailableReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    line.unavailableReason!,
                    style: const TextStyle(
                        color: Color(0xFFE0A63C), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                _buildStepper(line),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStepper(CartLine line) {
    return Row(
      children: [
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
        const Spacer(),
        GestureDetector(
          onTap: () => _apply(() => CartService.remove(line.productId)),
          child: const Icon(Icons.delete_outline, color: textMuted, size: 20),
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: onTap == null ? textMuted : Colors.white, size: 16),
      ),
    );
  }

  Widget _buildBottomBar(CartSnapshot full) {
    // Пока выбор не включён, показываем корзину целиком: человек ничего не
    // отмечал, значит берёт всё.
    final cart = _picking ? full.onlyProducts(_picked) : full;

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
            if (_picking) ...[
              const SizedBox(height: 4),
              Text(
                _picked.isEmpty
                    ? 'Отметьте галочками то, что берёте сейчас. Остальное '
                        'останется в корзине.'
                    : 'В заказ пойдёт ${_positions(cart.availableItemsCount)}. '
                        'Остальное останется в корзине.',
                style: const TextStyle(color: textMuted, fontSize: 12),
              ),
            ] else if (cart.unavailableItemsCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                cart.canCheckout
                    ? 'В заказ пойдёт ${_positions(cart.availableItemsCount)} '
                        'из ${cart.itemsCount}. Остальное сейчас купить нельзя, '
                        'в сумму оно не входит.'
                    : 'Сейчас купить нечего: всё, что лежит в корзине, '
                        'недоступно. Позиции оставили, чтобы вы видели, что '
                        'именно отвалилось.',
                style: const TextStyle(color: textMuted, fontSize: 12),
              ),
            ],
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
    if (_picking) {
      return _picked.isEmpty
          ? 'Выберите товары'
          : 'Оформить ${_positions(selected.availableItemsCount)}';
    }

    return full.canCheckout ? 'Оформить заказ' : 'Нечего оформлять';
  }

  Future<void> _openCheckout() async {
    final cart = _cart;

    if (cart == null) return;

    // Нажали «Оформить заказ», ничего не отмечая. Это НЕ значит «беру всё»:
    // требование заказчика от 14.09.2026 — сначала показать галочки и ждать
    // выбора. Заказ всей корзины делается кнопкой «Выбрать все», и это одно
    // нажатие, зато человек видит, за что платит.
    if (!_picking) {
      setState(() => _picking = true);

      SnackBarHelper.showWarning(
        context,
        'Отметьте товары, которые берёте сейчас. '
        'Можно выбрать все одной кнопкой сверху.',
      );

      return;
    }

    if (_picked.isEmpty) {
      SnackBarHelper.showWarning(context, 'Отметьте хотя бы один товар');

      return;
    }

    final selected = _picking ? cart.onlyProducts(_picked) : cart;

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

          // Серверу шлём номера ТОЛЬКО когда человек выбирал сам. Пустой
          // список и отсутствующий для сервера разные вещи: первый означает
          // «ничего не беру».
          productIds: _picking ? _picked.toList() : null,
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

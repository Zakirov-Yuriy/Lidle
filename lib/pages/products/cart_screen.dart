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
import 'package:lidle/widgets/dialogs/cart_folder_dialogs.dart';

/// Корзина.
///
/// Разложена по точкам продавца, потому что товары разных точек станут РАЗНЫМИ
/// заказами: у каждого свой код получения и своя выдача. Человек должен
/// увидеть это до оформления, а не после.
class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    this.preselectedProductIds,
    this.selectAllOnOpen = false,
  });

  /// Что отметить галочкой сразу при открытии (15.09.2026).
  ///
  /// Приходит с карточки товара: человек нажал зелёную «В корзине» и попал
  /// сюда ради ЭТОЙ вещи. Искать её галочку среди десятка других — лишний
  /// шаг там, где намерение уже высказано.
  final Set<int>? preselectedProductIds;

  /// Отметить ВСЁ доступное при открытии (15.09.2026).
  ///
  /// Так корзина открывается из нижнего меню витрины: человек шёл не за
  /// конкретной вещью, а «посмотреть корзину», и там его ждёт готовый к
  /// оформлению список. Снять лишнее одним нажатием проще, чем отметить всё
  /// по одному.
  ///
  /// НЕ везде: с карточки товара отмечается только тот товар, ради которого
  /// человек пришёл, а по умолчанию корзина открывается вовсе без отметок —
  /// требование заказчика от 14.09.2026, чтобы заказ не оформлялся целиком
  /// сам собой.
  final bool selectAllOnOpen;

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

  /// Какие папки человек раскрыл или свернул руками (18.09.2026).
  ///
  /// По умолчанию пустая папка свёрнута, а непустая раскрыта: пустая полка
  /// занимает пол-экрана и ничего не сообщает. Здесь лежат только те папки,
  /// решение по которым человек принял сам, и оно важнее умолчания.
  final Map<int?, bool> _expanded = <int?, bool>{};

  /// Какая плитка подсвечена в карусели. Пусто — основная.
  int? _activeFolderId;

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

        final available = _availableProductIds();

        if (widget.selectAllOnOpen) {
          _picked.addAll(available);
        } else {
          final wanted = widget.preselectedProductIds ?? const <int>{};

          _picked.addAll(wanted.where(available.contains));
        }
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
                  // Пустой считаем корзину без товаров И без папок: если
                  // человек завёл полку, а вещи с неё разобрал, он должен
                  // видеть свою полку, а не «Корзина пуста».
                  : (cart == null || (cart.isEmpty && cart.folders.isEmpty))
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
              onTap: _clearCart,
              child: const Text(
                'Очистить',
                style: TextStyle(color: textMuted, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  /// Пустая корзина.
  ///
  /// С 21.09.2026 здесь есть «Создать папку»: полки заводят и заранее, до
  /// первой покупки («К 1 сентября», «Подарки»). Раньше создать папку можно
  /// было только из карусели, а карусель в пустой корзине не показывается.
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Корзина пуста.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 16),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _createFolder,
              icon: const Icon(Icons.create_new_folder_outlined, size: 20),
              label: const Text('Создать папку'),
              style: OutlinedButton.styleFrom(
                foregroundColor: activeIconColor,
                side: const BorderSide(color: activeIconColor),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
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

        // Папки (18.09.2026). Карусель полок, под ней товары без папки
        // обычным списком, ниже сами полки.
        _buildFoldersStrip(cart),
        const SizedBox(height: 14),
        _buildPickBar(cart),
        ..._buildLooseLines(cart),
        ...cart.folders.map((folder) => _buildFolderBlock(cart, folder)),
      ],
    );
  }

  /// Товары, не разложенные по папкам.
  ///
  /// Показываем их просто списком, без заголовка и без своей полки (правка
  /// заказчика 18.09.2026): «основной папки» не существует, и придумывать ей
  /// название значит показать человеку полку, которую он не заводил.
  List<Widget> _buildLooseLines(CartSnapshot cart) {
    return _linesOf(cart, null)
        .map((row) => _buildLine(row.line, shopName: row.shopName))
        .toList();
  }

  // ── Папки (18.09.2026) ──────────────────────────────────────────────

  /// Позиции папки вместе с названием точки, из которой они приехали.
  ///
  /// Название точки нужно в строке товара: корзина теперь разложена по
  /// папкам, а не по магазинам, и человек должен видеть, у кого он это берёт.
  /// Разными заказами товары разных точек от этого быть не перестали.
  List<_FolderLine> _linesOf(CartSnapshot cart, int? folderId) {
    final out = <_FolderLine>[];

    for (final shop in cart.shops) {
      for (final line in shop.items) {
        if (line.folderId == folderId) {
          out.add(_FolderLine(line: line, shopName: shop.shopName));
        }
      }
    }

    return out;
  }

  bool _isExpanded(CartFolderInfo folder, int count) =>
      _expanded[folder.id] ?? count > 0;

  /// Карусель папок: плитки и «плюс» в конце.
  ///
  /// Пока папок нет, в ней стоит один «плюс»: место, где их заводят, должно
  /// быть видно и тому, кто про папки ещё не знает.
  Widget _buildFoldersStrip(CartSnapshot cart) {
    final folders = cart.folders;

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: folders.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == folders.length) return _buildAddFolderTile();

          return _buildFolderTile(cart, folders[index]);
        },
      ),
    );
  }

  Widget _buildFolderTile(CartSnapshot cart, CartFolderInfo folder) {
    final isActive = folder.id == _activeFolderId;
    final count = _linesOf(cart, folder.id).length;

    return GestureDetector(
      // Нажатие раскрывает эту полку и подсвечивает плитку: человек нажал на
      // папку, чтобы увидеть, что в ней.
      onTap: () => setState(() {
        _activeFolderId = folder.id;
        _expanded[folder.id] = !_isExpanded(folder, count);
      }),

      // Удаление долгим нажатием, как у групп товаров в кабинете.
      onLongPress: () => _deleteFolder(folder),
      child: SizedBox(
        width: 116,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 84,
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? activeIconColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  // Обложка на всю плитку (21.09.2026). Без неё значок
                  // папки: плитка должна выглядеть полкой, а не сломанной
                  // картинкой.
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  child: folder.hasImage
                      ? Image.network(
                          folder.image!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 84,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.folder_outlined,
                            color: textMuted,
                            size: 24,
                          ),
                        )
                      : const Icon(Icons.folder_outlined,
                          color: textMuted, size: 24),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: GestureDetector(
                    onTap: () => _renameFolder(folder),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(Icons.edit_outlined,
                        color: activeIconColor, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Две строки и мелкий шрифт: «Купить к 1 сентября» в одну строку
            // на плитке шириной 116 точек не помещается никак, а обрезать
            // название папки, которое человек сам придумал, нельзя.
            Text(
              folder.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? Colors.white : textSecondary,
                fontSize: 11,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFolderTile() {
    return SizedBox(
      width: 116,
      child: GestureDetector(
        onTap: _createFolder,
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_circle_outline,
              color: textSecondary, size: 24),
        ),
      ),
    );
  }

  Future<void> _createFolder() async {
    final form = await showCreateFolderDialog(context);

    if (form == null || !mounted) return;

    await _apply(
      () => CartService.createFolder(form.name, imagePath: form.imagePath),
    );
  }

  /// Правка папки: название и обложка в одном окне (21.09.2026).
  ///
  /// Запросов бывает до двух: название уходит своим, картинка своим. Шлём
  /// только то, что человек действительно поменял, иначе нажатие «Готово»
  /// без правок гоняло бы на сервер пустую работу.
  Future<void> _renameFolder(CartFolderInfo folder) async {
    final id = folder.id;

    if (id == null) return;

    final form = await showCreateFolderDialog(
      context,
      title: 'Изменить папку',
      notice: 'Название и обложку увидите только вы',
      initial: folder.name,
      initialImage: folder.image,
      canDelete: true,
    );

    if (form == null || !mounted) return;

    // «Удалить папку» из окна правки (21.09.2026). Подтверждение то же, что
    // и раньше: товары остаются в корзине, но спросить всё равно надо.
    if (form.delete) {
      await _deleteFolder(folder);

      return;
    }

    if (form.name != folder.name) {
      await _apply(() => CartService.renameFolder(id, form.name));
    }

    final imagePath = form.imagePath;

    if (imagePath != null && mounted) {
      await _apply(() => CartService.setFolderImage(id, imagePath));
    } else if (form.removeImage && mounted) {
      await _apply(() => CartService.removeFolderImage(id));
    }
  }

  Future<void> _deleteFolder(CartFolderInfo folder) async {
    final id = folder.id;

    if (id == null) return;

    final ok = await showCartConfirmDialog(
      context,
      title: 'Удалить папку',
      notice: 'если вы хотите удалить папку «${folder.name}»',
      hint: 'Товары из неё останутся в корзине общим списком, а не удалятся.',
    );

    if (!ok || !mounted) return;

    await _apply(() => CartService.deleteFolder(id));
  }

  /// Блок папки: заголовок с галочкой и шевроном, внутри товары.
  Widget _buildFolderBlock(CartSnapshot cart, CartFolderInfo folder) {
    final lines = _linesOf(cart, folder.id);
    final expanded = _isExpanded(folder, lines.length);

    final available = lines
        .where((row) => row.line.isAvailable)
        .map((row) => row.line.productId)
        .toSet();

    final allPicked =
        available.isNotEmpty && available.every(_picked.contains);

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
              CustomCheckbox(
                value: allPicked,
                onChanged: available.isEmpty
                    ? null
                    : (_) => setState(() {
                          if (allPicked) {
                            _picked.removeAll(available);
                          } else {
                            _picked.addAll(available);
                          }
                        }),
              ),
              const SizedBox(width: 10),

              // Маленькая обложка слева от названия (21.09.2026), если
              // человек её выбирал. Без обложки место не занимаем.
              if (folder.hasImage) ...[
                ClipOval(
                  child: Image.network(
                    folder.image!,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 28,
                      height: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _activeFolderId = folder.id;
                    _expanded[folder.id] = !expanded;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    folder.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _expanded[folder.id] = !expanded;
                }),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: Text(
                    'Папка пуста',
                    style: TextStyle(color: textMuted, fontSize: 14),
                  ),
                ),
              )
            else
              ...lines.map((row) => _buildLine(row.line, shopName: row.shopName)),
          ],
        ],
      ),
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

          // Перенос и удаление отмеченного (18.09.2026). Ровно там же, где
          // человек ставил галочки: выбрал несколько вещей — и сразу решил,
          // что с ними делать.
          GestureDetector(
            onTap: () => _moveLines({..._picked}, null),
            behavior: HitTestBehavior.opaque,
            child: const Text(
              'В папку',
              style: TextStyle(color: activeIconColor, fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _removePicked,
            behavior: HitTestBehavior.opaque,
            child: const Text(
              'Удалить',
              style: TextStyle(color: Color(0xFFE05B5B), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Убрать одну позицию, спросив подтверждение (18.09.2026).
  Future<void> _removeLine(CartLine line) async {
    final ok = await showCartConfirmDialog(
      context,
      title: 'Удаление товара',
      notice: 'если вы хотите удалить товар из корзины',
    );

    if (!ok || !mounted) return;

    await _apply(() => CartService.remove(line.productId));
  }

  /// Убрать отмеченные позиции.
  Future<void> _removePicked() async {
    if (_picked.isEmpty) {
      SnackBarHelper.showWarning(
        context,
        'Отметьте галочками то, что хотите убрать.',
      );

      return;
    }

    final ok = await showCartConfirmDialog(
      context,
      title: 'Удаление товара',
      notice: 'если вы хотите удалить товары из корзины',
    );

    if (!ok || !mounted) return;

    final ids = {..._picked};

    await _apply(() => CartService.removeMany(ids));

    if (mounted) setState(() => _picked.removeAll(ids));
  }

  /// Очистить корзину целиком.
  Future<void> _clearCart() async {
    final ok = await showCartConfirmDialog(
      context,
      title: 'Очистить корзину',
      notice: 'если вы хотите очистить корзину',
    );

    if (!ok || !mounted) return;

    await _apply(CartService.clear);

    if (mounted) setState(_picked.clear);
  }

  /// Переложить позиции в другую папку.
  Future<void> _moveLines(Set<int> productIds, int? currentFolderId) async {
    if (productIds.isEmpty) {
      SnackBarHelper.showWarning(
        context,
        'Отметьте галочками то, что переносите.',
      );

      return;
    }

    final folder = await showFolderPicker(
      context,
      selectedId: currentFolderId,
    );

    if (folder == null || !mounted) return;

    await _apply(
      () => CartService.moveToFolder(productIds, folderId: folder.id),
    );
  }

  // Блок точки продаж убран 18.09.2026: корзина теперь разложена по папкам
  // человека, а не по магазинам. Название точки переехало в строку товара —
  // разными заказами товары разных точек от этого быть не перестали.

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
  Widget _buildLine(CartLine line, {String? shopName}) {
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

                      // Название точки (18.09.2026). Корзина разложена по
                      // папкам, а не по магазинам, но товары разных точек
                      // по-прежнему станут разными заказами, и человек
                      // должен видеть, у кого он берёт эту вещь.
                      if ((shopName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          shopName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],

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
          onTap: () => _removeLine(line),
          behavior: HitTestBehavior.opaque,
          child: const Icon(Icons.delete_outline,
              color: Color(0xFFE05B5B), size: 22),
        ),
        const SizedBox(width: 14),

        // Переложить вещь на другую полку (18.09.2026). Рядом с удалением:
        // оба про судьбу позиции, а не про её количество.
        GestureDetector(
          onTap: () => _moveLines({line.productId}, line.folderId),
          behavior: HitTestBehavior.opaque,
          child: const Icon(Icons.drive_file_move_outline,
              color: activeIconColor, size: 22),
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
            // Разбивка по папкам (18.09.2026). Человек отложил вещи на
            // разные полки, и перед оплатой честно показать, сколько стоит
            // взятое с каждой, а не одно общее число.
            ..._buildFolderTotals(full),

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

  /// Строки «папка — сумма отмеченного в ней».
  ///
  /// Папки без единой отмеченной вещи не показываем: в итоге их нет, и нули
  /// под кнопкой оплаты только отвлекают.
  List<Widget> _buildFolderTotals(CartSnapshot cart) {
    final rows = <Widget>[];

    final parts = <CartFolderInfo>[
      const CartFolderInfo(id: null, name: 'Без папки', isMain: true),
      ...cart.folders,
    ];

    for (final folder in parts) {
      var sum = 0.0;

      for (final row in _linesOf(cart, folder.id)) {
        if (!row.line.isAvailable) continue;
        if (!_picked.contains(row.line.productId)) continue;

        sum += row.line.sum;
      }

      if (sum <= 0) continue;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
              Text(
                _money(sum),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Одна строка — разбивать нечего: она повторила бы итог слово в слово.
    if (rows.length < 2) return const [];

    return [
      const Padding(
        padding: EdgeInsets.only(bottom: 6),
        child: Text(
          'Ваша корзина',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      ...rows,
      const SizedBox(height: 6),
    ];
  }

  /// Что написать на кнопке.
  /// Свежая корзина перед оформлением. `false` значит «не идём дальше».
  ///
  /// Отмеченное, чего в корзине больше нет, снимаем с отметки и говорим об
  /// этом человеку, а на оформление в этот раз не ведём: пусть сначала
  /// увидит, что изменилось. Если сервер не ответил, оформляем по тому, что
  /// на экране: сервер всё равно проверит заказ сам.
  Future<bool> _refreshBeforeCheckout() async {
    setState(() => _isBusy = true);

    final result = await CartService.show();

    if (!mounted) return false;

    final fresh = result.isOk ? result.cart : null;

    if (fresh == null) {
      setState(() => _isBusy = false);

      return true;
    }

    final present = <int>{
      for (final shop in fresh.shops)
        for (final line in shop.items) line.productId,
    };

    final gone = _picked.where((id) => !present.contains(id)).length;

    setState(() {
      _isBusy = false;
      _cart = fresh;
      _picked.retainWhere(present.contains);
    });

    if (gone > 0) {
      SnackBarHelper.showWarning(
        context,
        'Корзина изменилась: часть отмеченного больше не в корзине. '
        'Проверьте состав и нажмите «Оформить» ещё раз.',
      );

      return false;
    }

    return true;
  }

  String _checkoutLabel(CartSnapshot full, CartSnapshot selected) {
    if (!full.canCheckout) return 'Нечего оформлять';

    return _picked.isEmpty
        ? 'Выберите товары'
        : 'Оформить ${_positions(selected.availableItemsCount)}';
  }

  Future<void> _openCheckout() async {
    if (_cart == null) return;

    // Перед оформлением перечитываем корзину с сервера (21.09.2026).
    //
    // Экран корзины мог пролежать открытым полдня, а корзину тем временем
    // поменяли на другом устройстве или продавец убрал товар с витрины.
    // Оформление показывало бы то, чего уже нет, и сервер отказал бы на
    // последнем шаге, когда человек уже заполнил контакты.
    if (!await _refreshBeforeCheckout()) return;

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

/// Позиция корзины вместе с названием точки, из которой она приехала.
///
/// Отдельным типом, а не парой: пара из строки и товара в коде экрана
/// читается как «что здесь первое», и один раз их обязательно перепутают.
class _FolderLine {
  const _FolderLine({required this.line, required this.shopName});

  final CartLine line;
  final String shopName;
}

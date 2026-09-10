// ============================================================
// Экран «Добавить товар»: сводка публикации перед выходом на витрину.
// ============================================================
//
// Третий экран потока (макет 10.09.2026). Человек попадает сюда с экрана
// групп кнопкой «Сохранить» и видит всё заведённое одним списком: раздел,
// бренд, группы с позициями, а ниже блоки доставки, сотрудников и оплаты.
//
// Зачем отдельный экран. Заведение идёт вглубь — раздел, бренд, группы,
// позиции, — и к моменту публикации человек уже не помнит, что именно у него
// получилось. Здесь он видит это целиком и отсюда же публикует.
//
// Блоки «Доставка», «Сотрудники» и «Оплата» нарисованы и намеренно
// неактивны: экранов за ними ещё нет. Показать кнопку, которая ничего не
// делает, честнее, чем спрятать её и потом переделывать вёрстку. Выдуманных
// строк в них тоже нет: список сотрудников из ниоткуда человек примет за
// свой и будет искать, откуда он взялся.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_delivery.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/products/add_product/product_delivery_option_screen.dart';
import 'package:lidle/pages/products/add_product/product_delivery_screen.dart';
import 'package:lidle/pages/products/add_product/product_staff_member_screen.dart';
import 'package:lidle/pages/products/add_product/product_staff_screen.dart';
import 'package:lidle/pages/products/add_product/product_items_screen.dart';
import 'package:lidle/pages/products/add_product/product_position_screen.dart';
import 'package:lidle/pages/products/products_screen.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/services/api/products_delivery_api.dart';
import 'package:lidle/services/api/products_staff_api.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/custom_switch.dart';
import 'package:lidle/widgets/components/header.dart';

/// Что делает человек с отмеченными позициями.
enum _PickMode { none, delete, edit }

class ProductReviewScreen extends StatefulWidget {
  const ProductReviewScreen({super.key, required this.publication});

  final ProductPublication publication;

  @override
  State<ProductReviewScreen> createState() => _ProductReviewScreenState();
}

class _ProductReviewScreenState extends State<ProductReviewScreen> {
  late ProductPublication _publication = widget.publication;

  /// Какие группы раскрыты. Номера, а не объекты: после обновления с сервера
  /// объекты новые, а раскрытое человеком должно остаться раскрытым.
  final Set<int> _open = {};

  List<ProductBrand> _brands = const [];

  /// Доставка публикации: те же группы и карточки, что на своём экране, но
  /// показанные списком.
  PublicationDelivery _delivery = const PublicationDelivery();

  final Set<int> _openDeliveryGroups = {};

  /// Выбор способов доставки: устроен так же, как выбор позиций.
  int? _pickDeliveryGroupId;
  _PickMode _pickDeliveryMode = _PickMode.none;
  final Set<int> _pickedDelivery = {};

  /// Сотрудники публикации и такой же выбор в них.
  PublicationStaff _staff = const PublicationStaff();

  final Set<int> _openStaffGroups = {};

  int? _pickStaffGroupId;
  _PickMode _pickStaffMode = _PickMode.none;
  final Set<int> _pickedStaff = {};

  /// Выбор позиций внутри одной группы: чекбоксы появляются по нажатию на
  /// «Удалить» или «Изменить» и живут только в этой группе. Одновременно
  /// выбирать в двух группах незачем: удаление и правка идут по одной папке.
  int? _pickGroupId;
  _PickMode _pickMode = _PickMode.none;
  final Set<int> _picked = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Первую группу раскрываем сразу: свёрнутый список выглядит пустым, и
    // человек решает, что его позиции пропали.
    if (_publication.groups.isNotEmpty) _open.add(_publication.groups.first.id);

    _reload();
    _loadBrands();
    _reloadDelivery();
    _reloadStaff();
  }

  Future<void> _reload() async {
    try {
      final fresh = await ProductsCabinetApi.publication(_publication.id);

      if (!mounted) return;

      setState(() {
        _publication = fresh;

        if (_open.isEmpty && fresh.groups.isNotEmpty) {
          _open.add(fresh.groups.first.id);
        }
      });
    } catch (e) {
      log.d('Публикация не обновилась: $e');
    }
  }

  Future<void> _reloadDelivery() async {
    try {
      final fresh = await ProductsDeliveryApi.load(_publication.id);

      if (!mounted) return;

      setState(() {
        _delivery = fresh;

        if (_openDeliveryGroups.isEmpty && fresh.groups.isNotEmpty) {
          _openDeliveryGroups.add(fresh.groups.first.id);
        }
      });
    } catch (e) {
      log.d('Доставка не обновилась: $e');
    }
  }

  Future<void> _reloadStaff() async {
    try {
      final fresh = await ProductsStaffApi.load(_publication.id);

      if (!mounted) return;

      setState(() {
        _staff = fresh;

        if (_openStaffGroups.isEmpty && fresh.groups.isNotEmpty) {
          _openStaffGroups.add(fresh.groups.first.id);
        }
      });
    } catch (e) {
      log.d('Сотрудники не обновились: $e');
    }
  }

  Future<void> _loadBrands() async {
    try {
      final brands = await ProductsCabinetApi.myBrands(
        categoryId: _publication.categoryId,
      );

      if (mounted) setState(() => _brands = brands);
    } catch (e) {
      log.d('Бренды не пришли: $e');
    }
  }

  // ── Раздел и бренд ──────────────────────────────────────────────

  /// «Изменить» у раздела: возвращаемся к выбору категории.
  ///
  /// Раздел определяет характеристики всех позиций, поэтому меняется он не
  /// здесь, а там же, где выбирался. Закрываем сводку и экран групп за ней.
  void _changeCategory() {
    Navigator.pop(context);
    Navigator.pop(context);
  }

  Future<void> _changeBrand() async {
    final chosen = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: primaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(defaultPadding, 20, defaultPadding, 12),
              child: Text(
                'Бренд',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _brands.length,
                itemBuilder: (context, index) {
                  final brand = _brands[index];

                  return ListTile(
                    title: Text(
                      brand.name,
                      style: const TextStyle(color: textPrimary, fontSize: 15),
                    ),
                    subtitle: Text(
                      brand.productsCount == 0
                          ? 'Пока без товаров'
                          : 'Товаров: ${brand.productsCount}',
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                    trailing: brand.id == _publication.brandId
                        ? const Icon(Icons.check,
                            color: activeIconColor, size: 20)
                        : null,
                    onTap: () => Navigator.pop(context, brand),
                  );
                },
              ),
            ),
            const Divider(color: Color(0xFF2A3744), height: 1),
            ListTile(
              leading: const Icon(Icons.add_circle_outline,
                  color: activeIconColor, size: 24),
              title: const Text(
                'Новый бренд',
                style: TextStyle(color: activeIconColor, fontSize: 15),
              ),
              onTap: () => Navigator.pop(context, 'new'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || chosen == null) return;

    final brand = chosen is ProductBrand ? chosen : await _askNewBrand();

    if (brand == null || !mounted) return;

    try {
      await ProductsCabinetApi.updatePublication(
        _publication.id,
        brandId: brand.id,
      );

      if (!mounted) return;

      setState(() {
        _publication = _publication.copyWith(
          brandId: brand.id,
          brandName: brand.name,
        );
      });
    } catch (e) {
      log.e('Бренд не сохранился: $e');
      _say('Бренд не сохранился. Попробуйте ещё раз.');
    }
  }

  Future<ProductBrand?> _askNewBrand() async {
    final field = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: const Text('Новый бренд',
            style: TextStyle(color: textPrimary, fontSize: 17)),
        content: TextField(
          controller: field,
          autofocus: true,
          style: const TextStyle(color: textPrimary),
          decoration: const InputDecoration(
            hintText: 'Введите название',
            hintStyle: TextStyle(color: textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: const Text('Создать',
                style: TextStyle(color: activeIconColor)),
          ),
        ],
      ),
    );

    // Контроллер НЕ освобождаем здесь намеренно.
    //
    // Диалог закрывается с анимацией, и его поле ввода живёт ещё несколько
    // кадров после того, как `showDialog` вернул результат. Освобождение в
    // этот момент оставляет живой TextField с мёртвым контроллером: на
    // телефоне это выглядит как намертво зависшее приложение, что и случилось
    // 10.09.2026 при заведении группы доставки.

    if (name == null || name.isEmpty) return null;

    try {
      final brand = await ProductsCabinetApi.createBrand(name);

      if (mounted && !_brands.any((item) => item.id == brand.id)) {
        setState(() => _brands = [..._brands, brand]);
      }

      return brand;
    } catch (e) {
      log.e('Бренд не завёлся: $e');
      _say('Бренд не завёлся. Попробуйте ещё раз.');

      return null;
    }
  }

  // ── Товары ──────────────────────────────────────────────────────

  /// «Добавить товар»: сразу к заведению позиции.
  ///
  /// Позиция всегда лежит в группе, поэтому группу надо знать. Одна — берём
  /// молча, несколько — спрашиваем, ни одной — отправляем заводить.
  Future<void> _addPosition() async {
    final groups = _publication.groups;

    if (groups.isEmpty) {
      _say('Сначала добавьте группу: позиция кладётся в неё.');

      await _openGroups();

      return;
    }

    final group = groups.length == 1 ? groups.first : await _chooseGroup();

    if (group == null || !mounted) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPositionScreen(
          publication: _publication,
          group: group,
          nextPosition: group.productsCount + 1,
        ),
      ),
    );

    await _reload();
  }

  Future<ProductGroup?> _chooseGroup() {
    return showModalBottomSheet<ProductGroup>(
      context: context,
      backgroundColor: primaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(defaultPadding, 20, defaultPadding, 12),
              child: Text(
                'В какую группу',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _publication.groups.length,
                itemBuilder: (context, index) {
                  final group = _publication.groups[index];

                  return ListTile(
                    title: Text(
                      group.name,
                      style: const TextStyle(color: textPrimary, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Позиций: ${group.productsCount}',
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(context, group),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Экран доставки.
  Future<void> _openDeliveryScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDeliveryScreen(
          publication: _publication,

          // Сюда мы уже пришли: открывать сводку поверх себя же не надо.
          openReview: false,
        ),
      ),
    );

    await _reload();
    await _reloadDelivery();
  }

  /// Экран групп: правка названий, обложек и содержимого.
  Future<void> _openGroups() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductItemsScreen(publication: _publication),
      ),
    );

    await _reload();
  }

  Future<void> _deleteGroup(ProductGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: const Text('Удалить группу?',
            style: TextStyle(color: textPrimary, fontSize: 17)),
        content: Text(
          group.productsCount == 0
              ? 'Группа пустая, удаляем.'
              : 'Позиции останутся в публикации, исчезнет только папка.',
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить',
                style: TextStyle(color: Color(0xFFE05B5B))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ProductsCabinetApi.deleteGroup(group.id);

      await _reload();
    } catch (e) {
      log.e('Группа не удалилась: $e');
      _say('Не получилось удалить группу.');
    }
  }

  // ── Выбор позиций ───────────────────────────────────────────────

  /// Отметить или снять позицию.
  ///
  /// В режиме правки выбор один: править две карточки одновременно нельзя, а
  /// молча брать первую отмеченную значит открыть не то, что человек думал.
  void _pick(int productId) {
    setState(() {
      if (_pickMode == _PickMode.edit) {
        _picked
          ..clear()
          ..add(productId);

        return;
      }

      if (!_picked.remove(productId)) _picked.add(productId);
    });
  }

  void _startPicking(int groupId, _PickMode mode) {
    setState(() {
      _pickGroupId = groupId;
      _pickMode = mode;
      _picked.clear();
    });
  }

  void _stopPicking() {
    setState(() {
      _pickGroupId = null;
      _pickMode = _PickMode.none;
      _picked.clear();
    });
  }

  /// Долгое нажатие по позиции: включить выбор и отметить её.
  void _pickFromLongPress(ProductGroup group, ProductPosition position) {
    setState(() {
      _pickGroupId = group.id;

      // Множественный выбор: с отмеченного товара можно и удалить, и перейти
      // к правке, а вот отметить второй для удаления — только так.
      _pickMode = _PickMode.delete;

      _picked
        ..clear()
        ..add(position.id);
    });
  }

  /// «Удалить»: без отметок включает выбор, с отметками удаляет их.
  Future<void> _onDelete(ProductGroup group) async {
    final picking = _pickGroupId == group.id && _pickMode != _PickMode.none;

    if (!picking) {
      if (group.products.isEmpty) {
        // Позиций нет — удалять человек хочет саму папку.
        await _deleteGroup(group);

        return;
      }

      _startPicking(group.id, _PickMode.delete);

      return;
    }

    if (_picked.isEmpty) {
      _say('Отметьте, какие товары удалить.');

      return;
    }

    await _deletePicked(group);
  }

  /// «Изменить»: без отметок включает выбор, с одной отметкой открывает правку.
  Future<void> _onEdit(ProductGroup group) async {
    final picking = _pickGroupId == group.id && _pickMode != _PickMode.none;

    if (!picking) {
      if (group.products.isEmpty) {
        // Позиций нет — менять человек хочет саму группу.
        await _openGroups();

        return;
      }

      _startPicking(group.id, _PickMode.edit);

      return;
    }

    if (_picked.isEmpty) {
      _say('Отметьте товар, который хотите изменить.');

      return;
    }

    // Править можно только одну карточку: какую из трёх открыть, человек не
    // говорил, а угадывать значит открыть не то.
    if (_picked.length > 1) {
      _say('Для изменения отметьте один товар.');

      return;
    }

    // Достаём позицию ДО сброса отметок и сразу списком.
    //
    // Так было: `where(...)` откладывал вычисление, а `_stopPicking()`
    // очищал отметки раньше, чем до него добирались, и `_picked.first`
    // падал на пустом множестве. Ленивые последовательности и состояние
    // экрана вместе не живут.
    final pickedId = _picked.first;

    final matches = group.products
        .where((item) => item.id == pickedId)
        .toList();

    if (matches.isEmpty) {
      _say('Этот товар уже изменился. Обновляю список.');

      _stopPicking();

      await _reload();

      return;
    }

    final position = matches.first;

    _stopPicking();

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPositionScreen(
          publication: _publication,
          group: group,
          existing: position,
        ),
      ),
    );

    await _reload();
  }

  /// Удалить отмеченные позиции.
  ///
  /// Спрашиваем прямо: товар уходит насовсем. Заказанный сервер удалять
  /// откажется и объяснит почему — его ответ показываем как есть.
  Future<void> _deletePicked(ProductGroup group) async {
    final names = group.products
        .where((item) => _picked.contains(item.id))
        .map((item) => item.name)
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: Text(
          names.length == 1 ? 'Удалить товар?' : 'Удалить товары (${names.length})?',
          style: const TextStyle(color: textPrimary, fontSize: 17),
        ),
        content: Text(
          '${names.join(', ')}\n\nУдаление безвозвратно: вернуть товар и его'
          ' фотографии будет нельзя.',
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить',
                style: TextStyle(color: Color(0xFFE05B5B))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final failed = <String>[];

    for (final id in _picked.toList()) {
      try {
        await ProductsCabinetApi.deletePosition(id);
      } catch (e) {
        log.e('Позиция $id не удалилась: $e');

        failed.add('$e'.replaceFirst('Exception: ', ''));
      }
    }

    _stopPicking();

    await _reload();

    if (failed.isNotEmpty) _say(failed.first);
  }

  // ── Доставка ────────────────────────────────────────────────────

  /// «Добавить»: сразу к заведению способа доставки.
  ///
  /// Как и у товара: способ кладётся в группу, поэтому группу надо знать.
  /// Одна — берём молча, несколько — спрашиваем, ни одной — отправляем на
  /// экран доставки заводить папку.
  Future<void> _addDeliveryOption() async {
    final groups = _delivery.groups;

    if (groups.isEmpty) {
      _say('Сначала добавьте группу доставки.');

      await _openDeliveryScreen();

      return;
    }

    final group = groups.length == 1 ? groups.first : await _chooseDeliveryGroup();

    if (group == null || !mounted) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDeliveryOptionScreen(
          publicationId: _publication.id,
          groups: groups,
          groupId: group.id,
        ),
      ),
    );

    await _reloadDelivery();
  }

  Future<DeliveryGroup?> _chooseDeliveryGroup() {
    return showModalBottomSheet<DeliveryGroup>(
      context: context,
      backgroundColor: primaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(defaultPadding, 20, defaultPadding, 12),
              child: Text(
                'В какую группу',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _delivery.groups.length,
                itemBuilder: (context, index) {
                  final group = _delivery.groups[index];

                  return ListTile(
                    title: Text(
                      group.name,
                      style: const TextStyle(color: textPrimary, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Способов: ${group.options.length}',
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(context, group),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _pickDelivery(int optionId) {
    setState(() {
      if (_pickDeliveryMode == _PickMode.edit) {
        _pickedDelivery
          ..clear()
          ..add(optionId);

        return;
      }

      if (!_pickedDelivery.remove(optionId)) _pickedDelivery.add(optionId);
    });
  }

  void _startPickingDelivery(int groupId, _PickMode mode) {
    setState(() {
      _pickDeliveryGroupId = groupId;
      _pickDeliveryMode = mode;
      _pickedDelivery.clear();
    });
  }

  void _stopPickingDelivery() {
    setState(() {
      _pickDeliveryGroupId = null;
      _pickDeliveryMode = _PickMode.none;
      _pickedDelivery.clear();
    });
  }

  Future<void> _onDeliveryDelete(DeliveryGroup group) async {
    final picking = _pickDeliveryGroupId == group.id &&
        _pickDeliveryMode != _PickMode.none;

    if (!picking) {
      if (group.options.isEmpty) {
        await _deleteDeliveryGroup(group);

        return;
      }

      _startPickingDelivery(group.id, _PickMode.delete);

      return;
    }

    if (_pickedDelivery.isEmpty) {
      _say('Отметьте, какие способы удалить.');

      return;
    }

    final names = group.options
        .where((item) => _pickedDelivery.contains(item.id))
        .map((item) => item.name)
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: Text(
          names.length == 1
              ? 'Удалить способ доставки?'
              : 'Удалить способы (${names.length})?',
          style: const TextStyle(color: textPrimary, fontSize: 17),
        ),
        content: Text(
          '${names.join(', ')}\n\nУдаление безвозвратно.',
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить',
                style: TextStyle(color: Color(0xFFE05B5B))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    for (final id in _pickedDelivery.toList()) {
      try {
        await ProductsDeliveryApi.deleteOption(id);
      } catch (e) {
        log.e('Способ $id не удалился: $e');
      }
    }

    _stopPickingDelivery();

    await _reloadDelivery();
  }

  Future<void> _onDeliveryEdit(DeliveryGroup group) async {
    final picking = _pickDeliveryGroupId == group.id &&
        _pickDeliveryMode != _PickMode.none;

    if (!picking) {
      if (group.options.isEmpty) {
        await _openDeliveryScreen();

        return;
      }

      _startPickingDelivery(group.id, _PickMode.edit);

      return;
    }

    if (_pickedDelivery.isEmpty) {
      _say('Отметьте способ, который хотите изменить.');

      return;
    }

    if (_pickedDelivery.length > 1) {
      _say('Для изменения отметьте один способ.');

      return;
    }

    final pickedId = _pickedDelivery.first;

    final matches = group.options.where((item) => item.id == pickedId).toList();

    if (matches.isEmpty) {
      _stopPickingDelivery();

      await _reloadDelivery();

      return;
    }

    final option = matches.first;

    _stopPickingDelivery();

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDeliveryOptionScreen(
          publicationId: _publication.id,
          groups: _delivery.groups,
          existing: option,
        ),
      ),
    );

    await _reloadDelivery();
  }

  Future<void> _deleteDeliveryGroup(DeliveryGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: const Text('Удалить группу доставки?',
            style: TextStyle(color: textPrimary, fontSize: 17)),
        content: const Text(
          'Способы доставки останутся, исчезнет только папка.',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить',
                style: TextStyle(color: Color(0xFFE05B5B))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ProductsDeliveryApi.deleteGroup(group.id);

      await _reloadDelivery();
    } catch (e) {
      log.e('Группа доставки не удалилась: $e');
      _say('Не получилось удалить группу.');
    }
  }

  // ── Сотрудники ──────────────────────────────────────────────────

  Future<void> _openStaffScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffScreen(
          publication: _publication,
          openReview: false,
        ),
      ),
    );

    await _reloadStaff();
  }

  /// «Добавить»: сразу к заведению сотрудника.
  Future<void> _addStaffMember() async {
    final groups = _staff.groups;

    if (groups.isEmpty) {
      _say('Сначала добавьте группу сотрудников.');

      await _openStaffScreen();

      return;
    }

    final group = groups.length == 1 ? groups.first : await _chooseStaffGroup();

    if (group == null || !mounted) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffMemberScreen(
          publicationId: _publication.id,
          categoryId: _publication.categoryId,
          groups: groups,
          groupId: group.id,
        ),
      ),
    );

    await _reloadStaff();
  }

  Future<StaffGroup?> _chooseStaffGroup() {
    return showModalBottomSheet<StaffGroup>(
      context: context,
      backgroundColor: primaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(defaultPadding, 20, defaultPadding, 12),
              child: Text(
                'В какую группу',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _staff.groups.length,
                itemBuilder: (context, index) {
                  final group = _staff.groups[index];

                  return ListTile(
                    title: Text(
                      group.name,
                      style: const TextStyle(color: textPrimary, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Сотрудников: ${group.members.length}',
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(context, group),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _pickStaff(int memberId) {
    setState(() {
      if (_pickStaffMode == _PickMode.edit) {
        _pickedStaff
          ..clear()
          ..add(memberId);

        return;
      }

      if (!_pickedStaff.remove(memberId)) _pickedStaff.add(memberId);
    });
  }

  void _startPickingStaff(int groupId, _PickMode mode) {
    setState(() {
      _pickStaffGroupId = groupId;
      _pickStaffMode = mode;
      _pickedStaff.clear();
    });
  }

  void _stopPickingStaff() {
    setState(() {
      _pickStaffGroupId = null;
      _pickStaffMode = _PickMode.none;
      _pickedStaff.clear();
    });
  }

  Future<void> _onStaffDelete(StaffGroup group) async {
    final picking =
        _pickStaffGroupId == group.id && _pickStaffMode != _PickMode.none;

    if (!picking) {
      if (group.members.isEmpty) {
        await _deleteStaffGroup(group);

        return;
      }

      _startPickingStaff(group.id, _PickMode.delete);

      return;
    }

    if (_pickedStaff.isEmpty) {
      _say('Отметьте, кого удалить.');

      return;
    }

    final names = group.members
        .where((item) => _pickedStaff.contains(item.id))
        .map((item) => item.name)
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: Text(
          names.length == 1
              ? 'Удалить сотрудника?'
              : 'Удалить сотрудников (${names.length})?',
          style: const TextStyle(color: textPrimary, fontSize: 17),
        ),
        content: Text(
          '${names.join(', ')}\n\nУдаление безвозвратно.',
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить',
                style: TextStyle(color: Color(0xFFE05B5B))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    for (final id in _pickedStaff.toList()) {
      try {
        await ProductsStaffApi.deleteMember(id);
      } catch (e) {
        log.e('Сотрудник $id не удалился: $e');
      }
    }

    _stopPickingStaff();

    await _reloadStaff();
  }

  Future<void> _onStaffEdit(StaffGroup group) async {
    final picking =
        _pickStaffGroupId == group.id && _pickStaffMode != _PickMode.none;

    if (!picking) {
      if (group.members.isEmpty) {
        await _openStaffScreen();

        return;
      }

      _startPickingStaff(group.id, _PickMode.edit);

      return;
    }

    if (_pickedStaff.isEmpty) {
      _say('Отметьте сотрудника, которого хотите изменить.');

      return;
    }

    if (_pickedStaff.length > 1) {
      _say('Для изменения отметьте одного сотрудника.');

      return;
    }

    final pickedId = _pickedStaff.first;

    final matches = group.members.where((item) => item.id == pickedId).toList();

    if (matches.isEmpty) {
      _stopPickingStaff();

      await _reloadStaff();

      return;
    }

    final member = matches.first;

    _stopPickingStaff();

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffMemberScreen(
          publicationId: _publication.id,
          categoryId: _publication.categoryId,
          groups: _staff.groups,
          existing: member,
        ),
      ),
    );

    await _reloadStaff();
  }

  Future<void> _deleteStaffGroup(StaffGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: const Text('Удалить группу сотрудников?',
            style: TextStyle(color: textPrimary, fontSize: 17)),
        content: const Text(
          'Сотрудники останутся, исчезнет только папка.',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить',
                style: TextStyle(color: Color(0xFFE05B5B))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ProductsStaffApi.deleteGroup(group.id);

      await _reloadStaff();
    } catch (e) {
      log.e('Группа сотрудников не удалилась: $e');
      _say('Не получилось удалить группу.');
    }
  }

  // ── Публикация ──────────────────────────────────────────────────

  Future<void> _toggleAutoRenew(bool value) async {
    setState(() => _publication = _publication.copyWith(isAutoRenew: value));

    try {
      await ProductsCabinetApi.updatePublication(
        _publication.id,
        isAutoRenew: value,
      );
    } catch (e) {
      log.d('Автопродление не сохранилось: $e');

      if (mounted) {
        setState(() =>
            _publication = _publication.copyWith(isAutoRenew: !value));
        _say('Не получилось сохранить автопродление.');
      }
    }
  }

  Future<void> _publish() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await ProductsCabinetApi.publish(_publication.id);

      if (!mounted) return;

      _say('Товары опубликованы.');

      // На витрину товаров, а не назад в форму: человек сразу видит свой
      // товар глазами покупателя.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ProductsScreen(
            categoryId: _publication.categoryId,
            categoryName: _publication.categoryName,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      log.e('Публикация не прошла: $e');

      if (!mounted) return;

      setState(() => _isSaving = false);

      _say(_reason(e));
    }
  }

  String _reason(Object error) {
    final text = error.toString();

    if (text.contains('магазин')) {
      return 'Выберите магазин, в котором лежит товар: туда придут заказы.';
    }

    if (text.contains('позиц')) {
      return 'Добавьте хотя бы одну позицию, иначе публиковать нечего.';
    }

    return 'Не получилось опубликовать. Проверьте связь и попробуйте ещё раз.';
  }

  void _say(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: secondaryBackground),
    );
  }

  // ── Вёрстка ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: textPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Добавить товар',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  defaultPadding,
                  16,
                  defaultPadding,
                  24,
                ),
                children: [
                  _label('Категория'),
                  _card(
                    title: _publication.categoryName.isEmpty
                        ? 'Раздел не указан'
                        : _publication.categoryName,
                    subtitle: _publication.categoryPath,
                    action: 'Изменить',
                    onAction: _changeCategory,
                  ),

                  const SizedBox(height: 20),
                  _label('Название бренда*'),
                  _card(
                    title: _publication.brandName ?? 'Бренд не выбран',
                    action: _publication.brandId == null
                        ? 'Создать'
                        : 'Изменить',
                    onAction: _changeBrand,
                  ),

                  const SizedBox(height: 20),
                  _label('Добавить товар'),
                  _addRow(onTap: _addPosition),
                  ..._groups(),

                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFF2A3744), height: 32),

                  _label('Добавить доставку'),
                  _addRow(onTap: _addDeliveryOption),
                  ..._deliveryBlocks(),

                  // ── Блоки, за которыми ещё нет экранов ──────────────

                  const SizedBox(height: 20),
                  _label('Добавить сотрудника'),
                  _addRow(onTap: _addStaffMember),
                  ..._staffBlocks(),

                  const SizedBox(height: 20),
                  _label('Добавить оплату'),
                  _addRow(onTap: null),
                  _soon('Способы оплаты пока задаёт администратор в разделе'),

                  const SizedBox(height: 24),
                  _autoRenew(),

                  const SizedBox(height: 24),
                  _secondaryButton('Предпросмотр', onTap: null),
                  const SizedBox(height: 12),
                  _primaryButton(
                    _isSaving ? 'Публикуем…' : 'Опубликовать',
                    onTap: _isSaving ? null : _publish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Заведённые группы с позициями.
  List<Widget> _groups() {
    if (_publication.groups.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Групп пока нет. Добавьте первую — в неё лягут позиции.',
            style: TextStyle(color: textMuted, fontSize: 13),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];

    for (final group in _publication.groups) {
      final isOpen = _open.contains(group.id);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: GestureDetector(
            onTap: () => setState(() {
              isOpen ? _open.remove(group.id) : _open.add(group.id);
            }),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  color: textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      );

      if (!isOpen) continue;

      final picking = _pickGroupId == group.id && _pickMode != _PickMode.none;

      for (final position in group.products) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: picking ? () => _pick(position.id) : null,

              // Долгое нажатие включает выбор и сразу отмечает эту позицию:
              // так человек, который хотел «что-то сделать вот с этим
              // товаром», попадает туда же, куда и через кнопки под группой.
              onLongPress: picking ? null : () => _pickFromLongPress(group, position),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  if (picking) ...[
                    CustomCheckbox(
                      value: _picked.contains(position.id),
                      onChanged: (_) => _pick(position.id),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      position.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: picking && _picked.contains(position.id)
                            ? textPrimary
                            : textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${position.stockQuantity} шт',
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (group.products.isEmpty) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'В группе пока нет позиций',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ),
        );
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _onDelete(group),
                child: Text(
                  picking && _pickMode == _PickMode.delete && _picked.isNotEmpty
                      ? 'Удалить (${_picked.length})'
                      : 'Удалить',
                  style: const TextStyle(
                    color: Color(0xFFE05B5B),
                    fontSize: 14,
                  ),
                ),
              ),
              if (picking) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _stopPicking,
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => _onEdit(group),
                child: const Text(
                  'Изменить',
                  style: TextStyle(color: activeIconColor, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );

      // Подсказка, что делать дальше: чекбоксы появились, а зачем — человеку
      // никто не сказал.
      if (picking) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _pickMode == _PickMode.delete
                  ? 'Отметьте товары и нажмите «Удалить». Для правки отметьте один и нажмите «Изменить»'
                  : 'Отметьте один товар и нажмите «Изменить»',
              style: const TextStyle(color: textMuted, fontSize: 12),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  /// Группы сотрудников с людьми: тот же вид, что у товаров и доставки.
  List<Widget> _staffBlocks() {
    if (_staff.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Сотрудников пока нет. Добавьте первого — он появится в группе.',
            style: TextStyle(color: textMuted, fontSize: 13),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];

    for (final group in _staff.groups) {
      final isOpen = _openStaffGroups.contains(group.id);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: GestureDetector(
            onTap: () => setState(() {
              isOpen
                  ? _openStaffGroups.remove(group.id)
                  : _openStaffGroups.add(group.id);
            }),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  color: textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      );

      if (!isOpen) continue;

      final picking =
          _pickStaffGroupId == group.id && _pickStaffMode != _PickMode.none;

      for (final member in group.members) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: picking ? () => _pickStaff(member.id) : null,
              onLongPress: picking
                  ? null
                  : () {
                      _startPickingStaff(group.id, _PickMode.delete);
                      _pickStaff(member.id);
                    },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  if (picking) ...[
                    CustomCheckbox(
                      value: _pickedStaff.contains(member.id),
                      onChanged: (_) => _pickStaff(member.id),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: picking && _pickedStaff.contains(member.id)
                            ? textPrimary
                            : textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    member.position == null || member.position!.isEmpty
                        ? 'без должности'
                        : member.position!,
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (group.members.isEmpty) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'В группе пока нет сотрудников',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ),
        );
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _onStaffDelete(group),
                child: Text(
                  picking &&
                          _pickStaffMode == _PickMode.delete &&
                          _pickedStaff.isNotEmpty
                      ? 'Удалить (${_pickedStaff.length})'
                      : 'Удалить',
                  style: const TextStyle(
                    color: Color(0xFFE05B5B),
                    fontSize: 14,
                  ),
                ),
              ),
              if (picking) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _stopPickingStaff,
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => _onStaffEdit(group),
                child: const Text(
                  'Изменить',
                  style: TextStyle(color: activeIconColor, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Сотрудники без группы: папку удалили, а люди остались.
    if (_staff.ungrouped.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Без группы',
            style: TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

      for (final member in _staff.ungrouped) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  member.position == null || member.position!.isEmpty
                      ? 'без должности'
                      : member.position!,
                  style: const TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  /// Группы доставки со способами: тот же вид, что у товаров.
  List<Widget> _deliveryBlocks() {
    if (_delivery.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Доставки пока нет. Добавьте способ — покупатель увидит условия.',
            style: TextStyle(color: textMuted, fontSize: 13),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];

    for (final group in _delivery.groups) {
      final isOpen = _openDeliveryGroups.contains(group.id);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: GestureDetector(
            onTap: () => setState(() {
              isOpen
                  ? _openDeliveryGroups.remove(group.id)
                  : _openDeliveryGroups.add(group.id);
            }),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  color: textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      );

      if (!isOpen) continue;

      final picking = _pickDeliveryGroupId == group.id &&
          _pickDeliveryMode != _PickMode.none;

      for (final option in group.options) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: picking ? () => _pickDelivery(option.id) : null,
              onLongPress: picking
                  ? null
                  : () {
                      _startPickingDelivery(group.id, _PickMode.delete);
                      _pickDelivery(option.id);
                    },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  if (picking) ...[
                    CustomCheckbox(
                      value: _pickedDelivery.contains(option.id),
                      onChanged: (_) => _pickDelivery(option.id),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      option.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: picking && _pickedDelivery.contains(option.id)
                            ? textPrimary
                            : textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    option.priceFrom == null
                        ? 'бесплатно'
                        : option.priceLabel.replaceFirst('Стоимость: ', ''),
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (group.options.isEmpty) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'В группе пока нет способов',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ),
        );
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _onDeliveryDelete(group),
                child: Text(
                  picking &&
                          _pickDeliveryMode == _PickMode.delete &&
                          _pickedDelivery.isNotEmpty
                      ? 'Удалить (${_pickedDelivery.length})'
                      : 'Удалить',
                  style: const TextStyle(
                    color: Color(0xFFE05B5B),
                    fontSize: 14,
                  ),
                ),
              ),
              if (picking) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _stopPickingDelivery,
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => _onDeliveryEdit(group),
                child: const Text(
                  'Изменить',
                  style: TextStyle(color: activeIconColor, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Способы без группы: папку удалили, а условия остались.
    if (_delivery.ungrouped.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Без группы',
            style: TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

      for (final option in _delivery.ungrouped) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  option.priceFrom == null
                      ? 'бесплатно'
                      : option.priceLabel.replaceFirst('Стоимость: ', ''),
                  style: const TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(color: textPrimary, fontSize: 15),
        ),
      );

  Widget _card({
    required String title,
    String subtitle = '',
    String? action,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action,
                style: const TextStyle(color: activeIconColor, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  /// Строка «Добавить» с синим плюсом справа.
  Widget _addRow({VoidCallback? onTap}) {
    final enabled = onTap != null;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Добавить',
                style: TextStyle(
                  color: enabled ? textPrimary : textMuted,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.add_circle_outline,
              color: enabled ? activeIconColor : textMuted,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  /// Подпись под неактивным блоком.
  ///
  /// Пустой блок без объяснения читается как поломка, а выдуманные строки в
  /// нём — как чужие данные.
  Widget _soon(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: const TextStyle(color: textMuted, fontSize: 12),
        ),
      );

  Widget _autoRenew() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Автопродление',
                style: TextStyle(color: textPrimary, fontSize: 15),
              ),
              SizedBox(height: 4),
              Text(
                'Без него публикация снимется через 30 дней',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        CustomSwitch(
          value: _publication.isAutoRenew,
          onChanged: _toggleAutoRenew,
        ),
      ],
    );
  }

  Widget _primaryButton(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? textMuted : activeIconColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: onTap == null ? textMuted : Colors.white),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: onTap == null ? textMuted : Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

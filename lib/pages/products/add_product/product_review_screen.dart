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
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/products/add_product/product_groups_screen.dart';
import 'package:lidle/pages/products/add_product/product_position_screen.dart';
import 'package:lidle/pages/products/products_screen.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/widgets/components/custom_switch.dart';
import 'package:lidle/widgets/components/header.dart';

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

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Первую группу раскрываем сразу: свёрнутый список выглядит пустым, и
    // человек решает, что его позиции пропали.
    if (_publication.groups.isNotEmpty) _open.add(_publication.groups.first.id);

    _reload();
    _loadBrands();
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

    field.dispose();

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

  /// Экран групп: правка названий, обложек и содержимого.
  Future<void> _openGroups() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductGroupsScreen(publication: _publication),
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

                  // ── Блоки, за которыми ещё нет экранов ──────────────
                  _label('Добавить доставку'),
                  _addRow(onTap: null),
                  _soon('Экран доставки ещё не сделан'),

                  const SizedBox(height: 20),
                  _label('Добавить сотрудника'),
                  _addRow(onTap: null),
                  _soon('Экран сотрудников ещё не сделан'),

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

      for (final position in group.products) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    position.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textSecondary, fontSize: 14),
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
                onTap: () => _deleteGroup(group),
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Color(0xFFE05B5B), fontSize: 14),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openGroups,
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

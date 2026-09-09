// ============================================================
// Экран «Добавить товар»: публикация (макет 09.09.2026).
// ============================================================
//
// То, что у объявлений делает динамический фильтр, у товаров делает этот
// экран. Человек попадает сюда после выбора конечного товарного раздела:
// плюс в нижнем меню → выбор каталога → категории → сюда.
//
// Публикация заводится СРАЗУ при открытии, пустым черновиком. Иначе некуда
// заливать обложки групп и картинки позиций: сервер принимает их только к
// существующей записи. Человек этого не замечает — на витрину черновик не
// попадает, пока не нажата «Опубликовать».
//
// Блоки «Доставка», «Сотрудники» и «Оплата» на макете есть, но экранов за
// ними ещё нет. Они нарисованы и намеренно неактивны: показать кнопку,
// которая ничего не делает, честнее, чем спрятать её и потом переделывать
// вёрстку.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/products/add_product/product_groups_screen.dart';
import 'package:lidle/pages/products/products_screen.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/widgets/components/custom_switch.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductPublicationScreen extends StatefulWidget {
  const ProductPublicationScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.categoryPath = '',
  });

  final int categoryId;
  final String categoryName;

  /// «Одежда / Куртки» — путь под названием раздела.
  final String categoryPath;

  @override
  State<ProductPublicationScreen> createState() =>
      _ProductPublicationScreenState();
}

class _ProductPublicationScreenState extends State<ProductPublicationScreen> {
  ProductPublication? _publication;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final TextEditingController _brand = TextEditingController();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _brand.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final publication = await ProductsCabinetApi.createPublication(
        categoryId: widget.categoryId,
      );

      if (!mounted) return;

      setState(() {
        _publication = publication;
        _brand.text = publication.brandName ?? '';
        _isLoading = false;
      });

      // Точку продаж сервер выбрать не смог: у продавца их несколько, а
      // экрана выбора на макете нет. Говорим об этом сразу, а не на кнопке
      // «Опубликовать».
      if (publication.needsShop && mounted) {
        _say('У вас несколько магазинов. Выберите, в каком лежит товар,'
            ' в настройках магазина.');
      }
    } catch (e) {
      log.e('Не удалось завести публикацию: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Не получилось начать публикацию. Проверьте связь и'
            ' попробуйте ещё раз.';
        _isLoading = false;
      });
    }
  }

  Future<void> _reload() async {
    final id = _publication?.id;

    if (id == null) return;

    try {
      final fresh = await ProductsCabinetApi.publication(id);

      if (mounted) setState(() => _publication = fresh);
    } catch (e) {
      log.d('Не удалось обновить публикацию: $e');
    }
  }

  Future<void> _saveBrand() async {
    final id = _publication?.id;
    final name = _brand.text.trim();

    if (id == null || name.isEmpty) return;

    try {
      // Сервер сам решит, заводить бренд или вернуть существующий с таким же
      // названием. Поэтому кнопка одна, а не «выбрать» и «создать».
      final brand = await ProductsCabinetApi.createBrand(name);

      await ProductsCabinetApi.updatePublication(id, brandId: brand.id);

      if (!mounted) return;

      setState(() {
        _publication = _publication?.copyWith(
          brandId: brand.id,
          brandName: brand.name,
        );
        _brand.text = brand.name;
      });

      _say('Бренд сохранён.');
    } catch (e) {
      log.e('Бренд не сохранился: $e');
      _say('Бренд не сохранился. Попробуйте ещё раз.');
    }
  }

  Future<void> _toggleAutoRenew(bool value) async {
    final id = _publication?.id;

    if (id == null) return;

    setState(() => _publication = _publication?.copyWith(isAutoRenew: value));

    try {
      await ProductsCabinetApi.updatePublication(id, isAutoRenew: value);
    } catch (e) {
      log.d('Автопродление не сохранилось: $e');

      // Возвращаем переключатель назад: показывать включённым то, что сервер
      // не принял, значит обмануть человека.
      if (mounted) {
        setState(() => _publication = _publication?.copyWith(isAutoRenew: !value));
        _say('Не получилось сохранить автопродление.');
      }
    }
  }

  Future<void> _openGroups() async {
    final publication = _publication;

    if (publication == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductGroupsScreen(publication: publication),
      ),
    );

    await _reload();
  }

  Future<void> _publish() async {
    final id = _publication?.id;

    if (id == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      await ProductsCabinetApi.publish(id);

      if (!mounted) return;

      _say('Товары опубликованы.');

      // Ведём на витрину товаров, а не назад в категории.
      //
      // Так было: человек нажимал «Опубликовать» и оказывался на экране
      // выбора категорий, ровно там, откуда пришёл. Понять, получилось ли,
      // было невозможно. Теперь он сразу видит свой товар глазами
      // покупателя, с кнопкой «В корзину».
      //
      // pushAndRemoveUntil, а не push: экраны заведения за спиной больше не
      // нужны, и кнопка «назад» не должна возвращать в форму, которая уже
      // опубликована.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ProductsScreen(
            categoryId: widget.categoryId,
            categoryName: widget.categoryName,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      log.e('Публикация не прошла: $e');

      if (!mounted) return;

      setState(() => _isSaving = false);

      // Сервер отвечает словами человека («выберите магазин», «нет ни одной
      // позиции»), поэтому показываем его ответ, а не свой текст.
      _say(_reason(e));
    }
  }

  /// Понятная причина отказа из ответа сервера.
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

  int get _positions {
    final groups = _publication?.groups ?? const <ProductGroup>[];

    return groups.fold<int>(0, (sum, group) => sum + group.productsCount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: activeIconColor))
            : _error != null
                ? _buildError()
                : _buildForm(),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: textPrimary, fontSize: 15),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _isLoading = true;
              _error = null;
            });
            _start();
          },
          child: const Text('Попробовать снова',
              style: TextStyle(color: activeIconColor)),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final publication = _publication!;

    return Column(
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
              20,
              defaultPadding,
              24,
            ),
            children: [
              _label('Категория'),
              _card(
                title: publication.categoryName.isEmpty
                    ? widget.categoryName
                    : publication.categoryName,
                subtitle: publication.categoryPath.isEmpty
                    ? widget.categoryPath
                    : publication.categoryPath,
                action: 'Изменить',

                // Раздел меняется возвратом к выбору категории: он определяет
                // характеристики всех позиций, и менять его посреди
                // заполненной публикации нельзя.
                onAction: () => Navigator.pop(context),
              ),

              const SizedBox(height: 20),
              _label('Название бренда*'),
              _brandField(),

              const SizedBox(height: 20),
              _label('Добавить товар'),
              _addRow(
                hint: _positions == 0
                    ? 'Добавить'
                    : 'Позиций: $_positions',
                onTap: _openGroups,
              ),
              _more(onTap: _openGroups),

              const SizedBox(height: 8),
              const Divider(color: Color(0xFF2A3744), height: 32),

              // ── Блоки, за которыми ещё нет экранов ──────────────────
              _label('Добавить доставку'),
              _addRow(hint: 'Добавить', onTap: null),
              _more(onTap: null),

              const SizedBox(height: 20),
              _label('Добавить сотрудника'),
              _addRow(hint: 'Добавить', onTap: null),
              _more(onTap: null),

              const SizedBox(height: 20),
              _label('Добавить оплату'),
              _addRow(hint: 'Добавить', onTap: null),
              _more(onTap: null),

              const SizedBox(height: 24),
              _autoRenew(publication),

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
    );
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

  Widget _brandField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _brand,
              style: const TextStyle(color: textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Введите название',
                hintStyle: TextStyle(color: textMuted, fontSize: 15),
              ),
            ),
          ),
          GestureDetector(
            onTap: _saveBrand,
            child: const Text(
              'Создать',
              style: TextStyle(color: activeIconColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Строка «Добавить» с синим плюсом справа.
  ///
  /// Неактивная строка (onTap == null) гаснет: так видно, что экрана за ней
  /// пока нет, и человек не жмёт по ней в недоумении.
  Widget _addRow({required String hint, VoidCallback? onTap}) {
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
                hint,
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

  Widget _more({VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            'Добавить еще',
            style: TextStyle(
              color: onTap == null ? textMuted : activeIconColor,
              fontSize: 14,
            ),
          ),
        ),
      );

  Widget _autoRenew(ProductPublication publication) {
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
          value: publication.isAutoRenew,
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

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
//
// БРЕНД ЗДЕСЬ ГЛАВНЫЙ (решение заказчика от 09.09.2026). Публикация
// определяется парой раздел + бренд: у продавца бывает несколько брендов, и
// в каждом свои товары. Поэтому экран сначала спрашивает бренд, а уже потом
// заводит публикацию — выбранный бренд открывает то, что под ним в этом
// разделе уже заведено, а новый бренд начинает новую витрину.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_delivery.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/pages/products/add_product/product_delivery_screen.dart';
import 'package:lidle/pages/products/add_product/product_items_screen.dart';
import 'package:lidle/pages/products/add_product/product_payment_screen.dart';
import 'package:lidle/pages/products/add_product/product_staff_screen.dart';
import 'package:lidle/pages/products/products_screen.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/services/api/products_delivery_api.dart';
import 'package:lidle/services/api/products_staff_api.dart';
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

  /// Бренды продавца с числом товаров в каждом. Пусто у того, кто заводит
  /// первый товар: ему показываем поле ввода, а не выбор из ничего.
  List<ProductBrand> _brands = const [];

  /// Доставка и сотрудники этой публикации. Нужны только ради счётчиков в
  /// строках: человек должен видеть, что у него уже заведено, не проваливаясь
  /// в каждый блок.
  PublicationDelivery _delivery = const PublicationDelivery();
  PublicationStaff _staff = const PublicationStaff();

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
    _brands = await _loadBrands();

    if (!mounted) return;

    // Три случая, и все три решает число брендов ПРОДАВЦА В ЭТОМ РАЗДЕЛЕ
    // (решение заказчика от 10.09.2026):
    //
    //  - брендов нет — открываем пустую форму, бренд человек заведёт сам;
    //  - бренд один — открываем сразу его витрину, спрашивать не о чем;
    //  - брендов несколько — спрашиваем, какой.
    if (_brands.length == 1) {
      await _openPublication(brand: _brands.first);

      return;
    }

    if (_brands.length > 1) {
      final chosen = await _chooseBrand();

      if (!mounted) return;

      if (chosen != null) {
        await _openPublication(brand: chosen);

        return;
      }
    }

    await _openPublication();
  }

  /// Мои бренды В ЭТОМ РАЗДЕЛЕ. Отказ сервера не должен ронять экран: без
  /// списка человек просто впишет название руками.
  Future<List<ProductBrand>> _loadBrands() async {
    try {
      return await ProductsCabinetApi.myBrands(categoryId: widget.categoryId);
    } catch (e) {
      log.d('Список брендов не пришёл: $e');

      return const [];
    }
  }

  /// Открыть публикацию по паре раздел + бренд.
  ///
  /// Сервер сам решает, завести новую или вернуть ту, что уже есть под этим
  /// брендом: для экрана оба случая одинаковые.
  Future<void> _openPublication({ProductBrand? brand}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final publication = await ProductsCabinetApi.createPublication(
        categoryId: widget.categoryId,
        brandId: brand?.id,
      );

      if (!mounted) return;

      setState(() {
        _publication = publication;
        _brand.text = publication.brandName ?? brand?.name ?? '';
        _isLoading = false;
      });

      // Точку продаж сервер выбрать не смог: у продавца их несколько, а
      // экрана выбора на макете нет. Говорим об этом сразу, а не на кнопке
      // «Опубликовать».
      if (publication.needsShop && mounted) {
        _say('У вас несколько магазинов. Выберите, в каком лежит товар,'
            ' в настройках магазина.');
      }

      // Доставка и сотрудники лежат отдельно от публикации, и на форме их
      // видно только счётчиками. Просим сразу: человек мог заводить их в
      // прошлый заход, и строка «Добавить» вместо «Способов: 2» читается
      // как «всё пропало».
      await _reloadBlocks(publication.id);
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

    await _reloadBlocks(id);
  }

  /// Доставка и сотрудники: только для счётчиков в строках.
  ///
  /// Молча переживаем отказ: без счётчика форма работает, а красная плашка
  /// поверх пустой формы пугает больше, чем помогает.
  Future<void> _reloadBlocks(int id) async {
    try {
      final delivery = await ProductsDeliveryApi.load(id);

      if (mounted) setState(() => _delivery = delivery);
    } catch (e) {
      log.d('Доставка не пришла: $e');
    }

    try {
      final staff = await ProductsStaffApi.load(id);

      if (mounted) setState(() => _staff = staff);
    } catch (e) {
      log.d('Сотрудники не пришли: $e');
    }
  }

  /// Кнопка «Создать» у поля ввода: завести бренд и открыть его витрину.
  Future<void> _saveBrand() async {
    final name = _brand.text.trim();

    if (name.isEmpty) return;

    try {
      // Сервер сам решит, заводить бренд или вернуть существующий с таким же
      // названием. Поэтому кнопка одна, а не «выбрать» и «создать».
      final brand = await ProductsCabinetApi.createBrand(name);

      await _useBrand(brand);
    } catch (e) {
      log.e('Бренд не сохранился: $e');
      _say('Бренд не сохранился. Попробуйте ещё раз.');
    }
  }

  /// Поставить публикации бренд.
  ///
  /// Пустой черновик без бренда переиспользуем, а не бросаем: иначе каждый
  /// выбор бренда оставлял бы в базе брошенную публикацию. Во всех остальных
  /// случаях уходим на пару раздел + бренд, и сервер отдаёт витрину этого
  /// бренда со всем, что в ней уже есть.
  Future<void> _useBrand(ProductBrand brand) async {
    final current = _publication;

    _rememberBrand(brand);

    final isEmptyDraft = current != null &&
        current.brandId == null &&
        current.groups.isEmpty &&
        !current.isPublished;

    if (!isEmptyDraft) {
      await _openPublication(brand: brand);

      return;
    }

    try {
      await ProductsCabinetApi.updatePublication(current.id, brandId: brand.id);

      if (!mounted) return;

      setState(() {
        _publication = current.copyWith(
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

  /// Держим новый бренд в списке своих, не перезапрашивая его с сервера.
  void _rememberBrand(ProductBrand brand) {
    if (_brands.any((item) => item.id == brand.id)) return;

    _brands = [..._brands, brand]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Выбор бренда: список своих с числом товаров плюс «Новый бренд».
  ///
  /// Возвращает null, если человек закрыл список ничего не выбрав.
  Future<ProductBrand?> _chooseBrand() async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: primaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _brandSheet(),
    );

    if (result is ProductBrand) return result;

    if (result == 'new') return _askNewBrand();

    return null;
  }

  Widget _brandSheet() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(defaultPadding, 20, defaultPadding, 12),
            child: Text(
              'Выберите бренд',
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
                final isCurrent = brand.id == _publication?.brandId;

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
                  trailing: isCurrent
                      ? const Icon(Icons.check, color: activeIconColor, size: 20)
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
    );
  }

  /// Название нового бренда.
  Future<ProductBrand?> _askNewBrand() async {
    final field = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: primaryBackground,
        title: const Text(
          'Новый бренд',
          style: TextStyle(color: textPrimary, fontSize: 18),
        ),
        content: TextField(
          controller: field,
          autofocus: true,
          style: const TextStyle(color: textPrimary, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'Введите название',
            hintStyle: TextStyle(color: textMuted, fontSize: 15),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: textMuted)),
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

      _rememberBrand(brand);

      return brand;
    } catch (e) {
      log.e('Бренд не завёлся: $e');
      _say('Бренд не завёлся. Попробуйте ещё раз.');

      return null;
    }
  }

  /// «Изменить» у бренда: выбрать другой и открыть его витрину.
  Future<void> _switchBrand() async {
    final brand = await _chooseBrand();

    if (brand == null || !mounted) return;

    if (brand.id == _publication?.brandId) return;

    await _useBrand(brand);
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

  /// Экран доставки: те же группы и карточки, что у товара.
  Future<void> _openDelivery() async {
    final publication = _publication;

    if (publication == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDeliveryScreen(publication: publication),
      ),
    );

    await _reload();
  }

  /// Экран сотрудников: те же группы и карточки.
  Future<void> _openStaff() async {
    final publication = _publication;

    if (publication == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffScreen(publication: publication),
      ),
    );

    await _reload();
  }

  Future<void> _openGroups() async {
    final publication = _publication;

    if (publication == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductItemsScreen(publication: publication),
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

  /// Подпись под брендом: сколько товаров под ним уже заведено.
  String _brandHint(ProductPublication publication) {
    final id = publication.brandId;

    if (id == null) {
      return _brands.isEmpty
          ? 'В этом разделе брендов ещё нет'
          : 'Выберите из своих или заведите новый';
    }

    final known = _brands.where((brand) => brand.id == id);
    final count = known.isEmpty ? _positions : known.first.productsCount;

    return count == 0 ? 'Пока без товаров' : 'Товаров в бренде: $count';
  }

  /// Короткая подпись строки оплаты.
  ///
  /// Показываем не «Добавить», а то, что уже выбрано: человек должен видеть
  /// свой выбор, не проваливаясь в экран.
  String get _paymentLabel {
    final chosen = _publication?.paymentMethods ?? const <String>[];

    if (chosen.isEmpty) return 'Добавить';

    return 'Способов: ${chosen.length}';
  }

  /// Экран оплаты. Выбор возвращается сюда и сразу уходит на сервер: он
  /// принадлежит публикации, а она уже заведена.
  Future<void> _openPayment() async {
    final publication = _publication;

    if (publication == null) return;

    final chosen = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPaymentScreen(
          chosen: publication.paymentMethods,
        ),
      ),
    );

    if (chosen == null || !mounted) return;

    setState(() {
      _publication = publication.copyWith(paymentMethods: chosen);
    });

    try {
      await ProductsCabinetApi.updatePublication(
        publication.id,
        paymentMethods: chosen,
      );
    } catch (e) {
      log.e('Способы оплаты не сохранились: $e');

      if (mounted) _say('Способы оплаты не сохранились. Проверьте связь.');
    }
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

              // Первому товару выбирать не из чего: показываем поле ввода.
              // Дальше бренд выбирается из своих, и в каждом видно, сколько
              // товаров уже заведено.
              if (_brands.isEmpty && publication.brandId == null)
                _brandField()
              else
                _card(
                  title: publication.brandName ?? 'Выберите бренд',
                  subtitle: _brandHint(publication),
                  action: 'Изменить',
                  onAction: _switchBrand,
                ),

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

              _label('Добавить доставку'),
              _addRow(
                hint: _delivery.total == 0
                    ? 'Добавить'
                    : 'Способов: ${_delivery.total}',
                onTap: _openDelivery,
              ),
              _more(onTap: _openDelivery),

              const SizedBox(height: 20),
              _label('Добавить сотрудника'),
              _addRow(
                hint: _staff.total == 0
                    ? 'Добавить'
                    : 'Сотрудников: ${_staff.total}',
                onTap: _openStaff,
              ),
              _more(onTap: _openStaff),

              const SizedBox(height: 20),
              _label('Добавить оплату'),
              _addRow(hint: _paymentLabel, onTap: _openPayment),
              _more(onTap: _openPayment),

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

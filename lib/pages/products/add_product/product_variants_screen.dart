// ============================================================
// Экран «Варианты модели» (14.09.2026).
// ============================================================
//
// Одна и та же куртка бывает красной 46-го и зелёной 48-го. Это НЕ разные
// товары: покупатель видит одну карточку и выбирает цвет с размером внутри
// неё. А вот остаток, цена и артикул у каждого варианта свои — заказывают
// именно вариант.
//
// Заказчик 14.09.2026: «создаём кластер и кучу объявлений этой курточки в
// разных цветах… добавляем размерный ряд».
//
// Экран работает с УЖЕ СОХРАНЁННОЙ позицией: вариант привязывается к модели
// по её номеру, а до сохранения номера нет.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductVariantsScreen extends StatefulWidget {
  const ProductVariantsScreen({
    super.key,
    required this.model,
    required this.categoryId,
  });

  /// Модель, у которой заводим варианты.
  final ProductPosition model;

  /// Раздел модели: сервер требует его при заведении.
  final int categoryId;

  @override
  State<ProductVariantsScreen> createState() => _ProductVariantsScreenState();
}

class _ProductVariantsScreenState extends State<ProductVariantsScreen> {
  List<ProductPosition> _variants = const [];
  List<ProductColor> _colors = const [];
  List<ProductDimension> _dimensions = const [];

  bool _isLoading = true;

  /// Что-то поменяли: экран позиции должен перечитать карточку.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    try {
      // Справочники и карточку тянем разом: по очереди это два ожидания сети
      // подряд, и экран открывался бы вдвое дольше.
      final results = await Future.wait([
        ProductsCabinetApi.withVariants(widget.model.id),
        ProductsCabinetApi.colors(),
        ProductsCabinetApi.dimensions(),
      ]);

      if (!mounted) return;

      final model = results[0] as ProductPosition?;

      setState(() {
        _variants = model?.variants ?? const [];
        _colors = results[1] as List<ProductColor>;
        _dimensions = results[2] as List<ProductDimension>;
        _isLoading = false;
      });
    } catch (e) {
      log.e('Варианты не загрузились: $e');

      if (!mounted) return;

      setState(() => _isLoading = false);
      _say('Не получилось загрузить варианты');
    }
  }

  Future<void> _openForm({ProductPosition? existing}) async {
    if (_colors.isEmpty && _dimensions.isEmpty) {
      _say('Справочники цвета и размера пустые. Их заводит администратор.');

      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VariantForm(
        model: widget.model,
        categoryId: widget.categoryId,
        existing: existing,
        colors: _colors,
        dimensions: _dimensions,
      ),
    );

    if (saved != true) return;

    _changed = true;
    await _load();
  }

  Future<void> _delete(ProductPosition variant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: formBackground,
        title: const Text(
          'Удалить вариант?',
          style: TextStyle(color: textPrimary, fontSize: 17),
        ),
        content: Text(
          '${variant.variantLabel ?? 'Вариант'}. Удаление безвозвратно, '
          'а если вариант уже заказывали, сервер его не отдаст.',
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ProductsCabinetApi.deletePosition(variant.id);

      _changed = true;
      await _load();
    } catch (e) {
      log.e('Вариант не удалился: $e');

      if (!mounted) return;

      _say('$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // Возвращаем признак изменений: карточка позиции по нему решает,
        // перечитывать ли себя. Без этого добавленный вариант не появился бы
        // в строке «Варианты» до следующего захода.
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: primaryBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Header(),
              const SizedBox(height: 12),
              _title(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: activeIconColor),
                      )
                    : _list(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _isLoading ? null : _addBar(),
      ),
    );
  }

  Widget _title() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context, _changed),
            child: const Icon(Icons.arrow_back_ios, color: textPrimary, size: 18),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Варианты',
              style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(defaultPadding, 12, defaultPadding, 24),
      children: [
        Text(
          widget.model.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Одна вещь в разных цветах и размерах. Покупатель видит одну '
          'карточку и выбирает вариант внутри неё, а остаток и цена у каждого '
          'варианта свои.',
          style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),

        if (_variants.isEmpty)
          const Text(
            'Вариантов пока нет. Товар продаётся как есть, одной строкой.',
            style: TextStyle(color: textMuted, fontSize: 14),
          )
        else
          ..._variants.map(_variantRow),
      ],
    );
  }

  Widget _variantRow(ProductPosition variant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _swatch(variant.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  variant.variantLabel ?? 'Без цвета и размера',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_price(variant.price)} · остаток ${variant.stockQuantity}',
                  style: const TextStyle(color: textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openForm(existing: variant),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.edit_outlined, color: activeIconColor, size: 20),
            ),
          ),
          GestureDetector(
            onTap: () => _delete(variant),
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.delete_outline, color: textMuted, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// Квадратик цвета. Незнакомый цвет рисуем серым: угадать не тот оттенок
  /// хуже, чем не показать никакого.
  Widget _swatch(ProductColor? color) {
    final code = color?.code;
    Color? parsed;

    if (code != null && code.isNotEmpty) {
      final hex = code.replaceFirst('#', '');

      if (hex.length == 6) {
        final value = int.tryParse(hex, radix: 16);

        if (value != null) parsed = Color(0xFF000000 | value);
      }
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: parsed ?? secondaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: parsed == null
          ? const Icon(Icons.palette_outlined, color: textMuted, size: 16)
          : null,
    );
  }

  Widget _addBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(defaultPadding, 8, defaultPadding, 12),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: activeIconColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _openForm(),
            child: const Text(
              'Добавить вариант',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _price(num value) => '${value.round()} ₽';

  void _say(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: secondaryBackground),
    );
  }
}

/// Форма варианта: цвет, размер, цена, остаток.
///
/// Названия и описания здесь нет намеренно: они общие у всей модели и живут в
/// её карточке. Дать их вариантам значит получить куртку, у которой красная
/// называется иначе, чем зелёная.
class _VariantForm extends StatefulWidget {
  const _VariantForm({
    required this.model,
    required this.categoryId,
    required this.colors,
    required this.dimensions,
    this.existing,
  });

  final ProductPosition model;
  final int categoryId;
  final List<ProductColor> colors;
  final List<ProductDimension> dimensions;
  final ProductPosition? existing;

  @override
  State<_VariantForm> createState() => _VariantFormState();
}

class _VariantFormState extends State<_VariantForm> {
  late final TextEditingController _price;
  late final TextEditingController _quantity;

  ProductColor? _color;
  ProductDimension? _dimension;

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    // Цену нового варианта подставляем от модели: чаще всего она та же, и
    // набирать её заново на каждый размер незачем.
    _price = TextEditingController(
      text: (existing?.price ?? widget.model.price).round().toString(),
    );
    _quantity = TextEditingController(
      text: (existing?.stockQuantity ?? 0).toString(),
    );

    _color = existing?.color;
    _dimension = existing?.dimension;
  }

  @override
  void dispose() {
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = num.tryParse(_price.text.replaceAll(' ', '').replaceAll(',', '.'));
    final quantity = int.tryParse(_quantity.text.trim());

    setState(() {
      if (_color == null && _dimension == null) {
        _error = 'Выберите цвет или размер: иначе вариант ничем не отличается';
      } else if (price == null || price <= 0) {
        _error = 'Укажите цену';
      } else if (quantity == null || quantity < 0) {
        _error = 'Укажите остаток';
      } else {
        _error = null;
      }
    });

    if (_error != null) return;

    setState(() => _isSaving = true);

    try {
      if (widget.existing != null) {
        await ProductsCabinetApi.updateVariant(
          widget.existing!.id,
          price: price,
          stockQuantity: quantity,
          colorId: _color?.id,
          dimensionId: _dimension?.id,
        );
      } else {
        await ProductsCabinetApi.createVariant(
          parentId: widget.model.id,
          categoryId: widget.categoryId,

          // Название у варианта то же, что у модели: покупатель видит одну
          // вещь, а отличает варианты цветом и размером.
          name: widget.model.name,
          price: price!,
          stockQuantity: quantity!,
          colorId: _color?.id,
          dimensionId: _dimension?.id,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      log.e('Вариант не сохранился: $e');

      if (!mounted) return;

      setState(() {
        _isSaving = false;

        // Текст сервера конкретный: «Такой вариант уже есть». Свой был бы
        // менее точным.
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: primaryBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Новый вариант' : 'Правка варианта',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            _pickRow(
              'Цвет',
              _color?.name ?? 'Не выбран',
              onTap: widget.colors.isEmpty ? null : _pickColor,
            ),
            const SizedBox(height: 10),
            _pickRow(
              'Размер',
              _dimension?.name ?? 'Не выбран',
              onTap: widget.dimensions.isEmpty ? null : _pickDimension,
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _field('Цена, ₽', _price)),
                const SizedBox(width: 12),
                Expanded(child: _field('Остаток, шт', _quantity)),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFE57373), fontSize: 13),
              ),
            ],

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeIconColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isSaving ? null : _save,
                child: Text(
                  _isSaving ? 'Сохраняем…' : 'Сохранить',
                  style: const TextStyle(
                    color: Colors.white,
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

  Widget _pickRow(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: textMuted, fontSize: 14)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: textPrimary, fontSize: 15),
              ),
            ),
            const Icon(Icons.keyboard_arrow_right, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: textPrimary, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: formBackground,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickColor() async {
    final picked = await showModalBottomSheet<ProductColor>(
      context: context,
      backgroundColor: primaryBackground,
      builder: (_) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: widget.colors
            .map(
              (color) => ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _parse(color.code) ?? secondaryBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                title: Text(
                  color.name,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                ),
                onTap: () => Navigator.pop(context, color),
              ),
            )
            .toList(),
      ),
    );

    if (picked != null) setState(() => _color = picked);
  }

  Future<void> _pickDimension() async {
    final picked = await showModalBottomSheet<ProductDimension>(
      context: context,
      backgroundColor: primaryBackground,
      builder: (_) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: widget.dimensions
            .map(
              (dimension) => ListTile(
                title: Text(
                  dimension.name,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                ),
                onTap: () => Navigator.pop(context, dimension),
              ),
            )
            .toList(),
      ),
    );

    if (picked != null) setState(() => _dimension = picked);
  }

  Color? _parse(String? code) {
    if (code == null || code.isEmpty) return null;

    final hex = code.replaceFirst('#', '');

    if (hex.length != 6) return null;

    final value = int.tryParse(hex, radix: 16);

    return value == null ? null : Color(0xFF000000 | value);
  }
}

// ============================================================
// Экран «Добавить позицию» (макет 09.09.2026).
// ============================================================
//
// Позиция это обычный товар: она сохраняется той же ручкой `/me/products`,
// что и всё остальное в кабинете, и попадает на витрину отдельной карточкой
// с кнопкой «в корзину».
//
// Поля «Тип одежды», «С принтом», «Выберите размер», «Цвет» на макете
// выглядят как обычные выпадашки, но это ХАРАКТЕРИСТИКИ РАЗДЕЛА: их набор
// заводит администратор в супер-админке, и для другого раздела он будет
// другим. Поэтому они рисуются динамически теми же виджетами и диалогами,
// что и в форме подачи объявления, — см. ProductAttributesForm.
//
// Блок «Кластер» ведёт на экран кластеров, у которого пока нет бэкенда:
// заказчик не назвал, что кластер значит. Подробности там же.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/products/add_product/product_attributes_form.dart';
import 'package:lidle/pages/products/add_product/photo_source_sheet.dart';
import 'package:lidle/pages/products/add_product/product_clusters_screen.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductPositionScreen extends StatefulWidget {
  const ProductPositionScreen({
    super.key,
    required this.publication,
    required this.group,
    this.nextPosition = 1,
    this.existing,
  });

  final ProductPublication publication;
  final ProductGroup group;

  /// Номер позиции по умолчанию: следующий по счёту в группе.
  final int nextPosition;

  /// Позиция, которую правим. Пусто — заводим новую.
  ///
  /// Экран один на оба случая намеренно: поля, характеристики и проверки у
  /// заведения и правки одни и те же, а вторая форма разъехалась бы с первой
  /// на первой же правке макета.
  final ProductPosition? existing;

  @override
  State<ProductPositionScreen> createState() => _ProductPositionScreenState();
}

class _ProductPositionScreenState extends State<ProductPositionScreen> {
  /// Столько символов просит макет в описании позиции.
  static const int _minDescription = 70;

  /// Столько же картинок, сколько у объявления и у товара в кабинете.
  static const int _maxPhotos = 15;

  final _name = TextEditingController();
  final _position = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController();
  final _brand = TextEditingController();
  final _description = TextEditingController();

  final _attributes = ProductAttributesController();

  List<Attribute> _fields = const [];

  /// Уже загруженные фотографии: готовые ссылки с сервера.
  ///
  /// Показываем их при правке, но дописать к ним новые нельзя: сервер
  /// заменяет набор целиком, а имена файлов в приложение не приезжают. Поэтому
  /// выбор новых означает замену, и экран говорит об этом прямо.
  final List<String> _saved = [];

  /// Выбранные фотографии позиции: пути к файлам на телефоне.
  ///
  /// Уходят на сервер уже ПОСЛЕ сохранения товара: ручка картинок принимает
  /// их только к существующей записи. Поэтому до нажатия «Сохранить» они
  /// живут здесь и показываются прямо с диска.
  final List<String> _photos = [];

  /// Справочник цветов и выбранный цвет.
  ///
  /// Цвет у товара это своё поле `color_id`, а не характеристика раздела:
  /// поэтому он не приходил вместе с полями формы, и выбрать его было негде.
  List<ProductColor> _colors = const [];
  ProductColor? _color;

  int? _brandId;
  bool _isLoading = true;
  bool _isSaving = false;
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _position.text = '${existing?.position ?? widget.nextPosition}';
    _brand.text = widget.publication.brandName ?? '';
    _brandId = existing?.brandId ?? widget.publication.brandId;

    if (existing != null) {
      _name.text = existing.name;
      _price.text = existing.price.toString();
      _quantity.text = '${existing.stockQuantity}';
      _description.text = existing.description;
      _saved.addAll(existing.images);
      _color = existing.color;
    }

    _loadFields();
  }

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
    _price.dispose();
    _quantity.dispose();
    _brand.dispose();
    _description.dispose();
    _attributes.dispose();
    super.dispose();
  }

  Future<void> _loadFields() async {
    // Цвета тянем рядом с полями и молча переживаем отказ: без справочника
    // форма всё равно работает, просто без выбора цвета.
    final colors = _loadColors();

    try {
      final fields = await ProductsCabinetApi.positionFields(
        widget.publication.categoryId,
      );

      _colors = await colors;

      if (!mounted) return;

      setState(() {
        _fields = fields;
        _isLoading = false;

        // Подставляем сохранённое ПОСЛЕ полей: выбранные варианты приходят
        // номерами значений, а перевести их в названия можно только по
        // справочнику раздела.
        _attributes.fields = fields;

        final existing = widget.existing;

        if (existing != null) _attributes.prefill(existing.attributes);
      });
    } catch (e) {
      log.e('Характеристики раздела не загрузились: $e');

      _colors = await colors;

      // Форму всё равно показываем: без характеристик товар сохранить можно,
      // а пустой экран человеку не объяснить.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Раздел уже спрашивает цвет своей характеристикой?
  bool get _hasColorAttribute => _fields.any(
        (field) => field.title.toLowerCase().contains('цвет'),
      );

  Future<List<ProductColor>> _loadColors() async {
    try {
      return await ProductsCabinetApi.colors();
    } catch (e) {
      log.d('Справочник цветов не пришёл: $e');

      return const [];
    }
  }

  /// Выбор цвета из справочника.
  Future<void> _pickColor() async {
    if (_colors.isEmpty) {
      _say('Справочник цветов пуст: цвета заводятся в админке.');

      return;
    }

    final chosen = await showModalBottomSheet<ProductColor>(
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
                'Цвет',
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
                itemCount: _colors.length,
                itemBuilder: (context, index) {
                  final color = _colors[index];

                  return ListTile(
                    leading: _swatch(color) ??
                        const Icon(Icons.circle_outlined,
                            color: textMuted, size: 22),
                    title: Text(
                      color.name,
                      style: const TextStyle(color: textPrimary, fontSize: 15),
                    ),
                    trailing: color.id == _color?.id
                        ? const Icon(Icons.check,
                            color: activeIconColor, size: 20)
                        : null,
                    onTap: () => Navigator.pop(context, color),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null || !mounted) return;

    setState(() => _color = chosen);
  }

  /// Квадратик цвета. Пусто, если код цвета в справочнике не заполнен.
  Widget? _swatch(ProductColor color) {
    final parsed = _parseColor(color.code);

    if (parsed == null) return null;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: parsed,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textMuted.withValues(alpha: 0.4)),
      ),
    );
  }

  /// «#43A047» и «43A047» в цвет. Мусор превращаем в пустоту, а не в чёрный
  /// квадрат: чёрный квадрат человек примет за настоящий цвет.
  Color? _parseColor(String? code) {
    var value = (code ?? '').trim().replaceFirst('#', '');

    if (value.length == 3) {
      value = value.split('').map((ch) => '$ch$ch').join();
    }

    if (value.length != 6) return null;

    final parsed = int.tryParse(value, radix: 16);

    return parsed == null ? null : Color(0xFF000000 | parsed);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() {
      _errors.clear();

      if (_name.text.trim().length < 2) {
        _errors['name'] = 'Напишите название позиции';
      }

      final price = num.tryParse(_price.text.replaceAll(' ', '').replaceAll(',', '.'));

      if (price == null || price <= 0) {
        _errors['price'] = 'Укажите цену';
      }

      if (int.tryParse(_quantity.text.trim()) == null) {
        _errors['quantity'] = 'Укажите количество';
      }

      final description = _description.text.trim();

      if (description.isNotEmpty && description.length < _minDescription) {
        _errors['description'] =
            'Не меньше $_minDescription символов, сейчас ${description.length}';
      }
    });

    final missing = _attributes.missingRequired();

    if (missing.isNotEmpty) {
      _say('Заполните: ${missing.join(', ')}.');

      return;
    }

    if (_errors.isNotEmpty) return;

    setState(() => _isSaving = true);

    try {
      // Бренд позиции: если человек написал своё название, заводим или
      // находим его. Пустое поле означает бренд публикации.
      final brandName = _brand.text.trim();
      var brandId = _brandId;

      if (brandName.isNotEmpty && brandName != widget.publication.brandName) {
        brandId = (await ProductsCabinetApi.createBrand(brandName)).id;
      }

      final existing = widget.existing;
      final price = num.parse(_price.text.replaceAll(' ', '').replaceAll(',', '.'));

      if (existing != null) {
        await ProductsCabinetApi.updatePosition(
          existing.id,
          groupId: widget.group.id,
          position: int.tryParse(_position.text.trim()),
          name: _name.text.trim(),
          description: _description.text.trim(),
          price: price,
          stockQuantity: int.parse(_quantity.text.trim()),
          brandId: brandId,
          colorId: _color?.id,
          attributes: _attributes.payload(),
        );
      }

      final productId = existing?.id ??
          await ProductsCabinetApi.createPosition(
            publicationId: widget.publication.id,
            groupId: widget.group.id,
            position: int.tryParse(_position.text.trim()),
            categoryId: widget.publication.categoryId,
            name: _name.text.trim(),
            description: _description.text.trim(),
            price: price,
            stockQuantity: int.parse(_quantity.text.trim()),
            brandId: brandId,
            colorId: _color?.id,
            attributes: _attributes.payload(),
          );

      // Фотографии заливаем вторым запросом, и его неудача позицию не
      // отменяет: товар уже заведён, и выбрасывать заполненную форму из-за
      // сорвавшейся картинки значит потерять работу человека. Просто
      // говорим, что фото не долетело.
      if (_photos.isNotEmpty && productId > 0) {
        try {
          await ProductsCabinetApi.uploadPositionImages(productId, _photos);
        } catch (e) {
          log.e('Фотографии позиции не загрузились: $e');

          if (mounted) {
            _say('Позиция сохранена, а фотографии не загрузились.'
                ' Добавьте их из карточки позиции.');
          }
        }
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      log.e('Позиция не сохранилась: $e');

      if (!mounted) return;

      setState(() => _isSaving = false);

      // Сервер отвечает понятным текстом («Заполните обязательные
      // характеристики: …»), поэтому показываем его, а не своё «ошибка».
      _say('$e'.replaceFirst('Exception: ', ''));
    }
  }

  void _say(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: secondaryBackground),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: activeIconColor))
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
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
                child: const Icon(Icons.arrow_back_ios,
                    color: textPrimary, size: 18),
              ),
              Text(
                widget.existing == null
                    ? 'Добавить позицию'
                    : 'Изменить позицию',
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text('Отмена',
                    style: TextStyle(color: activeIconColor, fontSize: 16)),
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
              const Text('Изображение позиции',
                  style: TextStyle(color: textPrimary, fontSize: 15)),
              const SizedBox(height: 8),
              _imagePlaceholder(),

              const SizedBox(height: 20),
              _text('Название позиции', _name, hint: 'Введите',
                  error: _errors['name']),

              const SizedBox(height: 20),
              const Text('Выбор группы',
                  style: TextStyle(color: textPrimary, fontSize: 15)),
              const SizedBox(height: 8),
              _readonly(widget.group.name),

              const SizedBox(height: 20),
              _text('Номер позиции', _position,
                  hint: '1', keyboard: TextInputType.number),

              const SizedBox(height: 20),
              _text('Цена позиции', _price,
                  hint: 'Введите',
                  keyboard: TextInputType.number,
                  suffix: '₽',
                  error: _errors['price']),

              const SizedBox(height: 20),
              _text('Колл. (шт.)', _quantity,
                  hint: 'Введите',
                  keyboard: TextInputType.number,
                  error: _errors['quantity']),

              const SizedBox(height: 20),
              // Характеристики раздела: «Тип одежды», «С принтом», «Размер»,
              // «Цвет». Их набор зависит от раздела и приходит с сервера.
              if (_fields.isEmpty)
                const ProductAttributesEmptyHint()
              else
                ProductAttributesForm(
                  controller: _attributes,
                  fields: _fields,
                ),

              // Цвет из общего справочника товаров. Показываем, только если
              // раздел не завёл свой «Цвет» характеристикой: два одинаковых
              // поля в одной форме означают два разных ответа на один вопрос,
              // и человек не поймёт, какой из них попадёт в карточку.
              if (!_hasColorAttribute) ...[
                const SizedBox(height: 20),
                const Text('Цвет',
                    style: TextStyle(color: textPrimary, fontSize: 15)),
                const SizedBox(height: 8),
                _colorField(),
              ],

              const SizedBox(height: 20),
              _text('Бренд товара', _brand, hint: 'Введите'),

              const SizedBox(height: 20),
              _text('Описание позиции', _description,
                  hint: 'Чем больше информации вы укажете о вашем товаре, тем'
                      ' более привлекательнее он будет для клиентов.'
                      ' Без ссылок, телефонов, матерных слов.',
                  maxLines: 5,
                  error: _errors['description']),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Введите не менее $_minDescription символов',
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                'Кластер',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Что такое кластер?',
                  style: TextStyle(color: activeIconColor, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Как это работает?',
                  style: TextStyle(color: activeIconColor, fontSize: 14)),
              const SizedBox(height: 12),
              _clusterRow(),

              const SizedBox(height: 24),
              GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _isSaving ? textMuted : activeIconColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
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
      ],
    );
  }

  /// Выбрать фотографии позиции.
  ///
  /// Сами файлы уходят на сервер после сохранения товара: ручка картинок
  /// принимает их только к существующей записи. До этого показываем их прямо
  /// с диска, чтобы человек видел, что выбрал.
  Future<void> _addPhotos() async {
    final picked = await pickProductPhotos(context, multiple: true);

    if (picked.isEmpty || !mounted) return;

    var dropped = 0;

    setState(() {
      for (final path in picked) {
        if (_photos.contains(path)) continue;

        if (_photos.length >= _maxPhotos) {
          dropped++;

          continue;
        }

        _photos.add(path);
      }
    });

    if (dropped > 0) {
      _say('Больше $_maxPhotos фотографий к одной позиции не добавить.');
    }
  }

  /// Фотографии позиции: выбранные плитками и плитка «плюс».
  ///
  /// Первая фотография становится главной — той, что видно на витрине и в
  /// ленте. Поэтому она подписана: иначе человек узнаёт об этом уже после
  /// публикации.
  Widget _imagePlaceholder() {
    if (_photos.isEmpty && _saved.isEmpty) {
      return GestureDetector(
        onTap: _addPhotos,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: textSecondary, size: 28),
              SizedBox(height: 8),
              Text('Добавить изображение',
                  style: TextStyle(color: textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    // Пока новых фотографий не выбрали, показываем загруженные. Как только
    // выбрали — показываем выбранные: именно они встанут вместо прежних.
    if (_photos.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final url in _saved)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 104,
                    height: 104,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 104,
                      height: 104,
                      color: formBackground,
                      child: const Icon(Icons.photo_outlined,
                          color: textMuted, size: 24),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: _addPhotos,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_circle_outline,
                      color: textSecondary, size: 24),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Новые фотографии встанут вместо загруженных',
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var index = 0; index < _photos.length; index++)
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_photos[index]),
                        width: 104,
                        height: 104,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                if (index == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Главная',
                        style: TextStyle(color: textMuted, fontSize: 11)),
                  ),
              ],
            ),
          ),
        if (_photos.length < _maxPhotos)
          GestureDetector(
            onTap: _addPhotos,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_circle_outline,
                  color: textSecondary, size: 28),
            ),
          ),
      ],
    );
  }

  /// Строка выбора цвета: квадратик, название и «Изменить».
  Widget _colorField() {
    final color = _color;

    return GestureDetector(
      onTap: _pickColor,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (color != null) ...[
              _swatch(color) ?? const SizedBox.shrink(),
              if (_swatch(color) != null) const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                color?.name ??
                    (_colors.isEmpty
                        ? 'Цвета не заведены в админке'
                        : 'Выберите цвет'),
                style: TextStyle(
                  color: color == null ? textMuted : textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            if (color != null)
              GestureDetector(
                onTap: () => setState(() => _color = null),
                child: const Icon(Icons.close, color: textMuted, size: 18),
              )
            else
              const Icon(Icons.keyboard_arrow_down, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _clusterRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Перейти',
                style: TextStyle(color: textMuted, fontSize: 15)),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductClustersScreen(
                positionName: _name.text.trim().isEmpty
                    ? 'Позиция'
                    : _name.text.trim(),
              ),
            ),
          ),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_forward_ios,
                color: textSecondary, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _text(
    String label,
    TextEditingController controller, {
    String hint = '',
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? suffix,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 15)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: error == null ? formBackground : const Color(0xFF381A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType: keyboard,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(color: textMuted, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(suffix,
                    style: const TextStyle(color: textPrimary, fontSize: 16)),
              ),
            ],
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error,
                style: const TextStyle(color: Color(0xFFE45B5B), fontSize: 12)),
          ),
      ],
    );
  }

  Widget _readonly(String value) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(value,
          style: const TextStyle(color: textPrimary, fontSize: 15)),
    );
  }
}

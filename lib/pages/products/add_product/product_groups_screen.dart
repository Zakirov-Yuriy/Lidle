// ============================================================
// Экран «Добавить товар»: группы и позиции внутри них.
// ============================================================
//
// Второй экран макета от 09.09.2026. Сверху лента групп с обложками
// («Куртки зима», «Куртки осень-весна») и плитка «плюс» для новой группы,
// ниже содержимое выбранной группы: позиции и плитка «Добавить позицию».
//
// Группа это папка при заведении. Покупателю групп не показывают: на витрине
// он видит каждую позицию отдельной карточкой с кнопкой «в корзину».

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/products/add_product/photo_source_sheet.dart';
import 'package:lidle/pages/products/add_product/product_position_screen.dart';
import 'package:lidle/pages/products/add_product/product_review_screen.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/utils/color_names.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductGroupsScreen extends StatefulWidget {
  const ProductGroupsScreen({super.key, required this.publication});

  final ProductPublication publication;

  @override
  State<ProductGroupsScreen> createState() => _ProductGroupsScreenState();
}

class _ProductGroupsScreenState extends State<ProductGroupsScreen> {
  late ProductPublication _publication = widget.publication;

  /// Какая группа раскрыта. Номер, а не объект: после обновления с сервера
  /// объекты новые, а выбор человека должен остаться прежним.
  int? _openGroupId;

  bool _isLoading = true;

  final TextEditingController _groupName = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _groupName.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final fresh = await ProductsCabinetApi.publication(_publication.id);

      if (!mounted) return;

      setState(() {
        _publication = fresh;
        _isLoading = false;

        // Если раскрытая группа исчезла, раскрываем первую: пустой экран без
        // объяснения выглядит поломкой.
        final ids = fresh.groups.map((g) => g.id).toSet();

        if (_openGroupId == null || !ids.contains(_openGroupId)) {
          _openGroupId = fresh.groups.isEmpty ? null : fresh.groups.first.id;
        }

        _groupName.text = _openGroup?.name ?? '';
      });
    } catch (e) {
      log.e('Не удалось загрузить публикацию: $e');

      if (mounted) setState(() => _isLoading = false);
    }
  }

  ProductGroup? get _openGroup {
    for (final group in _publication.groups) {
      if (group.id == _openGroupId) return group;
    }

    return null;
  }

  Future<void> _createGroup() async {
    final name = await _askName('Новая группа', '');

    if (name == null || name.trim().isEmpty) return;

    try {
      final group = await ProductsCabinetApi.createGroup(
        publicationId: _publication.id,
        name: name.trim(),
      );

      if (!mounted) return;

      setState(() => _openGroupId = group.id);

      await _reload();
    } catch (e) {
      log.e('Группа не завелась: $e');
      _say('Не получилось добавить группу.');
    }
  }

  Future<void> _renameGroup() async {
    final group = _openGroup;

    if (group == null) return;

    final name = await _askName('Название группы', group.name);

    if (name == null || name.trim().isEmpty) return;

    try {
      await ProductsCabinetApi.renameGroup(group.id, name.trim());
      await _reload();
    } catch (e) {
      log.e('Группа не переименовалась: $e');
      _say('Не получилось сохранить название.');
    }
  }

  Future<void> _deleteGroup(ProductGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: const Text('Удалить группу?',
            style: TextStyle(color: textPrimary, fontSize: 17)),

        // Прямо говорим, что будет с товарами: человек боится потерять
        // заведённое, и это законный страх.
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
            child: const Text('Удалить', style: TextStyle(color: activeIconColor)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ProductsCabinetApi.deleteGroup(group.id);

      if (mounted) setState(() => _openGroupId = null);

      await _reload();
    } catch (e) {
      log.e('Группа не удалилась: $e');
      _say('Не получилось удалить группу.');
    }
  }

  Future<String?> _askName(String title, String initial) {
    final controller = TextEditingController(text: initial);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: Text(title, style: const TextStyle(color: textPrimary, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: textPrimary),
          decoration: const InputDecoration(
            hintText: 'Например, Куртки зима',
            hintStyle: TextStyle(color: textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Сохранить', style: TextStyle(color: activeIconColor)),
          ),
        ],
      ),
    );
  }

  /// Обложка группы.
  ///
  /// Обложка одна, новая заменяет старую — так же, как главная фотография у
  /// объявления. Сервер удаляет прежний файл сам, поэтому спрашивать
  /// подтверждение не о чем: терять нечего, обложку всегда можно поставить
  /// другую.
  Future<void> _setGroupImage(ProductGroup group) async {
    final picked = await pickProductPhotos(context);

    if (picked.isEmpty || !mounted) return;

    _say('Загружаем обложку…');

    try {
      await ProductsCabinetApi.uploadGroupImage(group.id, picked.first);

      await _reload();
    } catch (e) {
      log.e('Обложка группы не загрузилась: $e');
      _say('Обложка не загрузилась. Проверьте связь и попробуйте ещё раз.');
    }
  }

  /// Фотографии уже заведённой позиции.
  ///
  /// Сервер заменяет набор картинок целиком, а прежние имена файлов в
  /// приложение не приезжают — только готовые ссылки. Поэтому у позиции с
  /// фотографией сначала спрашиваем: то, что там лежит, заменится.
  Future<void> _setPositionImages(ProductPosition position) async {
    if (position.image != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: secondaryBackground,
          title: const Text('Заменить фотографии?',
              style: TextStyle(color: textPrimary, fontSize: 17)),
          content: const Text(
            'Новые фотографии встанут вместо тех, что уже загружены.',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена',
                  style: TextStyle(color: textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Заменить',
                  style: TextStyle(color: activeIconColor)),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
    }

    final picked = await pickProductPhotos(context, multiple: true);

    if (picked.isEmpty || !mounted) return;

    _say('Загружаем фотографии…');

    try {
      await ProductsCabinetApi.uploadPositionImages(position.id, picked);

      await _reload();
    } catch (e) {
      log.e('Фотографии позиции не загрузились: $e');
      _say('Фотографии не загрузились. Проверьте связь и попробуйте ещё раз.');
    }
  }

  /// Правка позиции: тот же экран, что и заведение, но с заполненной формой.
  Future<void> _editPosition(ProductPosition position) async {
    final group = _openGroup;

    if (group == null) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPositionScreen(
          publication: _publication,
          group: group,
          nextPosition: position.position ?? 1,
          existing: position,
        ),
      ),
    );

    if (saved == true) await _reload();
  }

  Future<void> _addPosition() async {
    final group = _openGroup;

    if (group == null) {
      _say('Сначала добавьте группу: позиция кладётся в неё.');

      return;
    }

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPositionScreen(
          publication: _publication,
          group: group,
          nextPosition: group.productsCount + 1,
        ),
      ),
    );

    if (saved == true) await _reload();
  }

  /// «Сохранить»: к сводке публикации.
  ///
  /// Сохранять здесь нечего — группы и позиции уходят на сервер сразу, как их
  /// завели. Кнопка означает «я закончил с группами», и дальше человек видит
  /// всё заведённое одним списком и оттуда публикует.
  Future<void> _openReview() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductReviewScreen(publication: _publication),
      ),
    );

    // Со сводки можно было менять группы и позиции.
    await _reload();
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
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final group = _openGroup;

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
              const Text(
                'Добавить товар',
                style: TextStyle(
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
              _hintLink('Как это работает?'),
              _hintLink('Что такое группы?'),

              const SizedBox(height: 12),
              const Text('Категория',
                  style: TextStyle(color: textPrimary, fontSize: 15)),
              const SizedBox(height: 8),

              // Раздел, выбранный на прошлом экране. Человек проваливается
              // сюда через несколько экранов подряд и к моменту заведения
              // групп уже не помнит, куда именно кладёт товар.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _publication.categoryName.isEmpty
                          ? 'Раздел не указан'
                          : _publication.categoryName,
                      style: TextStyle(
                        color: _publication.categoryName.isEmpty
                            ? textMuted
                            : textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    if (_publication.categoryPath.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _publication.categoryPath,
                        style: const TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text('Название группы',
                  style: TextStyle(color: textPrimary, fontSize: 15)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: group == null ? null : _renameGroup,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          group?.name ?? 'Группы пока нет',
                          style: TextStyle(
                            color: group == null ? textMuted : textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ),

                      // Карандаш, а не молчаливое нажатие по строке: иначе про
                      // переименование группы никто не догадается.
                      if (group != null)
                        const Icon(Icons.edit_outlined,
                            color: activeIconColor, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _groupsStrip(),

              const SizedBox(height: 20),
              Text(
                group == null
                    ? 'Содержимое группы'
                    : 'Содержимое группы: ${group.name}',
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _positionsGrid(group),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            defaultPadding,
            0,
            defaultPadding,
            16,
          ),
          child: GestureDetector(
            onTap: _openReview,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activeIconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Сохранить',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hintLink(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(color: activeIconColor, fontSize: 14),
        ),
      );

  /// Лента групп с обложками и плиткой «плюс».
  Widget _groupsStrip() {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _publication.groups.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == _publication.groups.length) {
            // Плитка «плюс» той же формы и того же размера, что обложка
            // группы, и прижата к верху: лента идёт одной строкой, и плитка
            // другой высоты сбивает её.
            return SizedBox(
              width: 116,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _createGroup,
                    child: Container(
                      width: double.infinity,
                      height: 88,
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
            );
          }

          final group = _publication.groups[index];
          final isOpen = group.id == _openGroupId;

          return GestureDetector(
            onTap: () => setState(() => _openGroupId = group.id),
            onLongPress: () => _deleteGroup(group),
            child: SizedBox(
              width: 116,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        // Ширину задаём явно. Container с ребёнком и без
                        // ширины сжимается до этого ребёнка, и группа без
                        // обложки выходила узкой полоской в ширину значка,
                        // а с обложкой — нормальной плиткой.
                        width: double.infinity,
                        height: 88,
                        decoration: BoxDecoration(
                          color: formBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOpen ? activeIconColor : Colors.transparent,
                            width: 2,
                          ),
                          image: group.image == null
                              ? null
                              : DecorationImage(
                                  image: NetworkImage(group.image!),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: group.image != null
                            ? null
                            : const Icon(Icons.photo_outlined,
                                color: textMuted, size: 24),
                      ),

                      // Значок фотоаппарата в углу: обложку ставят прямо
                      // отсюда. Прятать это в длинное нажатие нельзя — про
                      // длинное нажатие человек не догадается.
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: GestureDetector(
                          onTap: () => _setGroupImage(group),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.photo_camera_outlined,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isOpen ? textPrimary : textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _positionsGrid(ProductGroup? group) {
    final positions = group?.products ?? const <ProductPosition>[];

    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        ...positions.map(_positionCard),
        // Плитка «Добавить позицию» ровно того же размера и формы, что
        // картинка позиции, и прижата к верху: подписи под карточками разной
        // длины, и плитка в 180 точек торчала из ряда.
        SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _addPosition,
                child: Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: textSecondary, size: 24),
                      SizedBox(height: 8),
                      Text('Добавить позицию',
                          style: TextStyle(color: textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _positionCard(ProductPosition position) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(8),
                  image: position.image == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(position.image!),
                          fit: BoxFit.cover,
                        ),
                ),
                child: position.image != null
                    ? null
                    : const Icon(Icons.photo_outlined,
                        color: textMuted, size: 24),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: GestureDetector(
                  onTap: () => _setPositionImages(position),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.photo_camera_outlined,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Название и карандаш в одной строке: правка начинается там же, где
          // человек читает название, а не в отдельном меню.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  position.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                ),
              ),
              GestureDetector(
                onTap: () => _editPosition(position),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6, top: 2),
                  child: Icon(Icons.edit_outlined,
                      color: activeIconColor, size: 18),
                ),
              ),
            ],
          ),

          const SizedBox(height: 2),
          Text(
            _price(position.price),
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),

          // Кластер пока показываем названием позиции, как на макете. Своего
          // значения у него нет: экран кластеров ничего не сохраняет, потому
          // что заказчик не назвал, что кластер значит.
          const SizedBox(height: 4),
          _attributeLine('Кластер', position.name, muted: true),

          for (final attribute in position.attributes)
            _attributeLine(attribute.title, attribute.value),
        ],
      ),
    );
  }

  /// Цена без хвоста «.0»: 4559.0 читается как ошибка, а не как цена.
  String _price(num value) {
    final rounded = value % 1 == 0 ? value.toInt().toString() : '$value';
    final digits = rounded.split('').reversed.toList();
    final grouped = <String>[];

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) grouped.add(' ');

      grouped.add(digits[i]);
    }

    return '${grouped.reversed.join()} ₽';
  }

  /// Строка «Размер: 54» под карточкой.
  ///
  /// Одним текстовым блоком, а не строкой из двух колонок: у длинного
  /// значения вторая строка уезжала вправо, под колонку значения, и подписи
  /// шли рваной лесенкой. Text.rich переносит всё по левому краю.
  ///
  /// Набор характеристик у каждого раздела свой, поэтому строки не зашиты, а
  /// приходят с сервера: в мебели тут будут «Материал» и «Ширина».
  Widget _attributeLine(String title, String value, {bool muted = false}) {
    // Цветов у позиции бывает несколько: сервер отдаёт их одной строкой через
    // запятую. Разбираем и рисуем квадратиками.
    final swatches = isColorAttribute(title)
        ? value
              .split(',')
              .map((item) => colorByName(item))
              .whereType<Color>()
              .toList()
        : const <Color>[];

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${_shortTitle(title)}: ',
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
            if (swatches.isNotEmpty)
              for (final color in swatches)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: colorSwatch(color, size: 16),
                  ),
                )
            else
              TextSpan(
                text: value,
                style: TextStyle(
                  color: muted ? textMuted : textPrimary,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        textAlign: TextAlign.start,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Название характеристики для карточки.
  ///
  /// В форме поле называется так, как его завёл администратор, — «Выберите
  /// размер». Под карточкой это читается странно: там уже выбранное значение,
  /// а не приглашение выбрать. Приглашение отрезаем.
  String _shortTitle(String title) {
    for (final prefix in const ['Выберите ', 'Выбери ', 'Выбрать ', 'Укажите ']) {
      if (title.startsWith(prefix)) {
        final rest = title.substring(prefix.length);

        if (rest.isEmpty) return title;

        return rest[0].toUpperCase() + rest.substring(1);
      }
    }

    return title;
  }
}

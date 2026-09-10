// ============================================================
// Экран «Добавить доставку» (макет 10.09.2026).
// ============================================================
//
// Повторяет экран групп товара: сверху название открытой группы, лента групп
// с обложками («Курьер»), ниже содержимое — способы доставки карточками с
// картинкой, названием и ценой «от».
//
// Так и задумано заказчиком: человек только что заводил товар точно таким же
// экраном, и второй раз объяснять ему, как это работает, не приходится.
//
// Доставка принадлежит публикации. Когда появится экран точки продаж, её
// можно будет поднять на уровень точки — экран от этого не изменится.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_delivery.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/products/add_product/photo_source_sheet.dart';
import 'package:lidle/services/api/products_delivery_api.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductDeliveryScreen extends StatefulWidget {
  const ProductDeliveryScreen({super.key, required this.publication});

  final ProductPublication publication;

  @override
  State<ProductDeliveryScreen> createState() => _ProductDeliveryScreenState();
}

class _ProductDeliveryScreenState extends State<ProductDeliveryScreen> {
  PublicationDelivery _delivery = const PublicationDelivery();

  /// Какая группа раскрыта. Номер, а не объект: после обновления с сервера
  /// объекты новые, а выбор человека должен остаться прежним.
  int? _openGroupId;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final fresh = await ProductsDeliveryApi.load(widget.publication.id);

      if (!mounted) return;

      setState(() {
        _delivery = fresh;
        _isLoading = false;

        final ids = fresh.groups.map((group) => group.id).toSet();

        if (_openGroupId == null || !ids.contains(_openGroupId)) {
          _openGroupId = fresh.groups.isEmpty ? null : fresh.groups.first.id;
        }
      });
    } catch (e) {
      log.e('Доставка не загрузилась: $e');

      if (mounted) setState(() => _isLoading = false);
    }
  }

  DeliveryGroup? get _openGroup {
    for (final group in _delivery.groups) {
      if (group.id == _openGroupId) return group;
    }

    return null;
  }

  /// Что показывать в содержимом: способы открытой группы, а если групп нет —
  /// те, что лежат без группы.
  List<DeliveryOption> get _visibleOptions =>
      _openGroup?.options ?? _delivery.ungrouped;

  // ── Группы ──────────────────────────────────────────────────────

  Future<void> _createGroup() async {
    final name = await _askText('Новая группа', hint: 'Например, Курьер');

    if (name == null || name.isEmpty) return;

    try {
      final group = await ProductsDeliveryApi.createGroup(
        publicationId: widget.publication.id,
        name: name,
      );

      if (mounted) setState(() => _openGroupId = group.id);

      await _reload();
    } catch (e) {
      log.e('Группа доставки не завелась: $e');
      _say('Не получилось добавить группу.');
    }
  }

  Future<void> _renameGroup() async {
    final group = _openGroup;

    if (group == null) return;

    final name = await _askText('Название группы', initial: group.name);

    if (name == null || name.isEmpty) return;

    try {
      await ProductsDeliveryApi.renameGroup(group.id, name);

      await _reload();
    } catch (e) {
      log.e('Группа не переименовалась: $e');
      _say('Не получилось сохранить название.');
    }
  }

  Future<void> _deleteGroup(DeliveryGroup group) async {
    final confirmed = await _confirm(
      'Удалить группу?',
      group.options.isEmpty
          ? 'Группа пустая, удаляем.'
          : 'Способы доставки останутся, исчезнет только папка.',
    );

    if (!confirmed) return;

    try {
      await ProductsDeliveryApi.deleteGroup(group.id);

      if (mounted) setState(() => _openGroupId = null);

      await _reload();
    } catch (e) {
      log.e('Группа не удалилась: $e');
      _say('Не получилось удалить группу.');
    }
  }

  Future<void> _setGroupImage(DeliveryGroup group) async {
    final picked = await pickProductPhotos(context);

    if (picked.isEmpty || !mounted) return;

    _say('Загружаем обложку…');

    try {
      await ProductsDeliveryApi.uploadGroupImage(group.id, picked.first);

      await _reload();
    } catch (e) {
      log.e('Обложка группы не загрузилась: $e');
      _say('Обложка не загрузилась. Проверьте связь и попробуйте ещё раз.');
    }
  }

  // ── Способы ─────────────────────────────────────────────────────

  Future<void> _addOption() async {
    final form = await _askOption();

    if (form == null) return;

    try {
      await ProductsDeliveryApi.createOption(
        publicationId: widget.publication.id,
        name: form.name,
        priceFrom: form.price,
        groupId: _openGroupId,
      );

      await _reload();
    } catch (e) {
      log.e('Способ доставки не завёлся: $e');
      _say('Не получилось добавить способ доставки.');
    }
  }

  Future<void> _editOption(DeliveryOption option) async {
    final form = await _askOption(option: option);

    if (form == null) return;

    try {
      await ProductsDeliveryApi.updateOption(
        option.id,
        name: form.name,
        priceFrom: form.price,

        // Цену отправляем всегда: пустое поле означает «убрать цену», и
        // отличить это от «не менял» можно только так.
        touchPrice: true,
      );

      await _reload();
    } catch (e) {
      log.e('Способ доставки не сохранился: $e');
      _say('Не получилось сохранить способ доставки.');
    }
  }

  Future<void> _deleteOption(DeliveryOption option) async {
    final confirmed = await _confirm(
      'Удалить способ доставки?',
      '${option.name}\n\nУдаление безвозвратно.',
    );

    if (!confirmed) return;

    try {
      await ProductsDeliveryApi.deleteOption(option.id);

      await _reload();
    } catch (e) {
      log.e('Способ доставки не удалился: $e');
      _say('Не получилось удалить способ доставки.');
    }
  }

  Future<void> _setOptionImage(DeliveryOption option) async {
    final picked = await pickProductPhotos(context);

    if (picked.isEmpty || !mounted) return;

    _say('Загружаем картинку…');

    try {
      await ProductsDeliveryApi.uploadOptionImage(option.id, picked.first);

      await _reload();
    } catch (e) {
      log.e('Картинка способа не загрузилась: $e');
      _say('Картинка не загрузилась. Проверьте связь и попробуйте ещё раз.');
    }
  }

  // ── Диалоги ─────────────────────────────────────────────────────

  Future<String?> _askText(
    String title, {
    String initial = '',
    String hint = 'Введите название',
  }) async {
    final field = TextEditingController(text: initial);

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: Text(title,
            style: const TextStyle(color: textPrimary, fontSize: 17)),
        content: TextField(
          controller: field,
          autofocus: true,
          style: const TextStyle(color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: const Text('Сохранить',
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

    return value;
  }

  /// Название и стоимость способа доставки.
  ///
  /// Цена необязательна: доставка бывает бесплатной, и заставлять человека
  /// выдумывать число ради заполненного поля незачем.
  Future<_OptionForm?> _askOption({DeliveryOption? option}) async {
    final name = TextEditingController(text: option?.name ?? '');
    final price = TextEditingController(
      text: option?.priceFrom == null
          ? ''
          : '${option!.priceFrom! % 1 == 0 ? option.priceFrom!.toInt() : option.priceFrom}',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: Text(
          option == null ? 'Способ доставки' : 'Изменить способ',
          style: const TextStyle(color: textPrimary, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              style: const TextStyle(color: textPrimary),
              decoration: const InputDecoration(
                labelText: 'Название',
                labelStyle: TextStyle(color: textMuted),
                hintText: 'Например, Доставка на авто',
                hintStyle: TextStyle(color: textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: textPrimary),
              decoration: const InputDecoration(
                labelText: 'Стоимость от, ₽',
                labelStyle: TextStyle(color: textMuted),
                hintText: 'Можно не указывать',
                hintStyle: TextStyle(color: textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить',
                style: TextStyle(color: activeIconColor)),
          ),
        ],
      ),
    );

    final result = saved == true && name.text.trim().isNotEmpty
        ? _OptionForm(
            name: name.text.trim(),
            price: num.tryParse(
              price.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
            ),
          )
        : null;

    if (saved == true && result == null) _say('Напишите название способа.');

    // Контроллер НЕ освобождаем здесь намеренно.
    //
    // Диалог закрывается с анимацией, и его поле ввода живёт ещё несколько
    // кадров после того, как `showDialog` вернул результат. Освобождение в
    // этот момент оставляет живой TextField с мёртвым контроллером: на
    // телефоне это выглядит как намертво зависшее приложение, что и случилось
    // 10.09.2026 при заведении группы доставки.

    return result;
  }

  Future<bool> _confirm(String title, String text) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: Text(title,
            style: const TextStyle(color: textPrimary, fontSize: 17)),
        content: Text(text,
            style: const TextStyle(color: textSecondary, fontSize: 14)),
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

    return answer == true;
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
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: activeIconColor))
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
                'Добавить доставку',
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

              // Тот же блок, что на экране товара: человек проваливается сюда
              // через несколько экранов и должен видеть, к чему заводит
              // доставку.
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
                      widget.publication.categoryName.isEmpty
                          ? 'Раздел не указан'
                          : widget.publication.categoryName,
                      style: TextStyle(
                        color: widget.publication.categoryName.isEmpty
                            ? textMuted
                            : textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    if (widget.publication.categoryPath.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.publication.categoryPath,
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
                    ? 'Способы доставки'
                    : 'Содержимое группы: ${group.name}',
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _optionsGrid(),
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
            onTap: () => Navigator.pop(context, true),
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
        itemCount: _delivery.groups.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == _delivery.groups.length) {
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

          final group = _delivery.groups[index];
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

  Widget _optionsGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        ..._visibleOptions.map(_optionCard),
        SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _addOption,
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

  Widget _optionCard(DeliveryOption option) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _deleteOption(option),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(8),
                    image: option.image == null
                        ? null
                        : DecorationImage(
                            image: NetworkImage(option.image!),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: option.image != null
                      ? null
                      : const Icon(Icons.local_shipping_outlined,
                          color: textMuted, size: 24),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: GestureDetector(
                    onTap: () => _setOptionImage(option),
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
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  option.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                ),
              ),
              GestureDetector(
                onTap: () => _editOption(option),
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
            option.priceLabel,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Что человек ввёл в диалоге способа доставки.
class _OptionForm {
  const _OptionForm({required this.name, this.price});

  final String name;
  final num? price;
}

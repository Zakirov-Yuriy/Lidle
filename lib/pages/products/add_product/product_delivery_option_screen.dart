// ============================================================
// Экран «Добавить позицию» доставки (макет 10.09.2026).
// ============================================================
//
// Тот же экран, что у позиции товара, и это намеренно: картинка, название,
// выбор группы, цена, описание, внизу «Удалить» и «Сохранить». Человек только
// что заводил товар точно такой же формой.
//
// Один экран на заведение и на правку. Отличий два: при правке форма открыта
// заполненной и появляется «Удалить способ доставки».
//
// Картинка при ЗАВЕДЕНИИ уходит на сервер вторым запросом, уже после того как
// способ создан: ручка картинок принимает файл только к существующей записи.
// При правке картинка уходит сразу — способ уже есть.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_delivery.dart';
import 'package:lidle/pages/products/add_product/photo_source_sheet.dart';
import 'package:lidle/services/api/products_delivery_api.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductDeliveryOptionScreen extends StatefulWidget {
  const ProductDeliveryOptionScreen({
    super.key,
    required this.publicationId,
    required this.groups,
    this.existing,
    this.groupId,
  });

  final int publicationId;

  /// Группы доставки публикации: из них собирается выпадашка «Выбор группы».
  final List<DeliveryGroup> groups;

  /// Способ, который правим. Пусто — заводим новый.
  final DeliveryOption? existing;

  /// В какую группу класть новый способ.
  final int? groupId;

  @override
  State<ProductDeliveryOptionScreen> createState() =>
      _ProductDeliveryOptionScreenState();
}

class _ProductDeliveryOptionScreenState
    extends State<ProductDeliveryOptionScreen> {
  /// Столько символов просит макет в описании — как у позиции товара.
  static const int _minDescription = 70;

  final _name = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();

  int? _groupId;

  /// Выбранный файл с телефона. Пока он не выбран, показываем то, что уже
  /// загружено на сервер.
  String? _photo;
  String? _saved;

  bool _isSaving = false;
  final Map<String, String> _errors = {};

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _groupId = existing?.groupId ?? widget.groupId;

    if (existing != null) {
      _name.text = existing.name;
      _description.text = existing.description;
      _saved = existing.image;

      final price = existing.priceFrom;

      if (price != null) {
        _price.text = price % 1 == 0 ? '${price.toInt()}' : '$price';
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  // ── Действия ────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picked = await pickProductPhotos(context);

    if (picked.isEmpty || !mounted) return;

    setState(() => _photo = picked.first);

    // У существующего способа картинку меняем сразу: способ уже есть, ждать
    // «Сохранить» незачем, а человек ждёт, что фото применилось.
    final existing = widget.existing;

    if (existing == null) return;

    try {
      await ProductsDeliveryApi.uploadOptionImage(existing.id, picked.first);

      _say('Картинка сохранена.');
    } catch (e) {
      log.e('Картинка способа не загрузилась: $e');
      _say('Картинка не загрузилась. Проверьте связь и попробуйте ещё раз.');
    }
  }

  Future<void> _pickGroup() async {
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
                'Выбор группы',
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
                itemCount: widget.groups.length,
                itemBuilder: (context, index) {
                  final group = widget.groups[index];

                  return ListTile(
                    title: Text(
                      group.name,
                      style: const TextStyle(color: textPrimary, fontSize: 15),
                    ),
                    trailing: group.id == _groupId
                        ? const Icon(Icons.check,
                            color: activeIconColor, size: 20)
                        : null,
                    onTap: () => Navigator.pop(context, group),
                  );
                },
              ),
            ),
            const Divider(color: Color(0xFF2A3744), height: 1),
            ListTile(
              title: const Text(
                'Без группы',
                style: TextStyle(color: textSecondary, fontSize: 15),
              ),
              onTap: () => Navigator.pop(context, 'none'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null || !mounted) return;

    setState(() => _groupId = chosen is DeliveryGroup ? chosen.id : null);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() {
      _errors.clear();

      if (_name.text.trim().length < 2) {
        _errors['name'] = 'Напишите название способа доставки';
      }

      final description = _description.text.trim();

      if (description.isNotEmpty && description.length < _minDescription) {
        _errors['description'] =
            'Не меньше $_minDescription символов, сейчас ${description.length}';
      }
    });

    if (_errors.isNotEmpty) return;

    setState(() => _isSaving = true);

    final price = num.tryParse(
      _price.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
    );

    try {
      final existing = widget.existing;

      if (existing != null) {
        await ProductsDeliveryApi.updateOption(
          existing.id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          priceFrom: price,

          // Пустое поле означает «убрать цену», а не «не менял».
          touchPrice: true,
          groupId: _groupId,
        );
      } else {
        final created = await ProductsDeliveryApi.createOption(
          publicationId: widget.publicationId,
          name: _name.text.trim(),
          description: _description.text.trim(),
          priceFrom: price,
          groupId: _groupId,
        );

        // Картинка вторым запросом: её принимают только к существующей
        // записи. Неудача способ не отменяет — он уже заведён.
        if (_photo != null) {
          try {
            await ProductsDeliveryApi.uploadOptionImage(created.id, _photo!);
          } catch (e) {
            log.e('Картинка способа не загрузилась: $e');

            if (mounted) {
              _say('Способ сохранён, а картинка не загрузилась.');
            }
          }
        }
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      log.e('Способ доставки не сохранился: $e');

      if (!mounted) return;

      setState(() => _isSaving = false);

      _say('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;

    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: const Text('Удалить способ доставки?',
            style: TextStyle(color: textPrimary, fontSize: 17)),
        content: Text(
          '${existing.name}\n\nУдаление безвозвратно.',
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

    try {
      await ProductsDeliveryApi.deleteOption(existing.id);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      log.e('Способ доставки не удалился: $e');
      _say('Не получилось удалить способ доставки.');
    }
  }

  void _say(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: secondaryBackground),
    );
  }

  String get _groupName {
    for (final group in widget.groups) {
      if (group.id == _groupId) return group.name;
    }

    return 'Без группы';
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
                    child: const Icon(Icons.arrow_back_ios,
                        color: textPrimary, size: 18),
                  ),
                  Text(
                    _isEditing ? 'Изменить позицию' : 'Добавить позицию',
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
                  _photoBlock(),

                  const SizedBox(height: 20),
                  _text('Название позиции', _name,
                      hint: 'Например, Доставка на авто',
                      error: _errors['name']),

                  const SizedBox(height: 20),
                  const Text('Выбор группы',
                      style: TextStyle(color: textPrimary, fontSize: 15)),
                  const SizedBox(height: 8),
                  _groupField(),

                  const SizedBox(height: 20),
                  _price_(),

                  const SizedBox(height: 20),
                  _text(
                    'Описание позиции',
                    _description,
                    hint: 'Сроки, зона доставки, ограничения по весу.'
                        ' Чем понятнее условия, тем меньше вопросов в чате.',
                    lines: 5,
                    error: _errors['description'],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Введите не менее 70 символов',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ),

                  const SizedBox(height: 28),
                  if (_isEditing) ...[
                    _dangerButton('Удалить способ', onTap: _delete),
                    const SizedBox(height: 12),
                  ],
                  _primaryButton(
                    _isSaving ? 'Сохраняем…' : 'Сохранить',
                    onTap: _isSaving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Картинка способа с кнопкой съёмки в правом нижнем углу.
  ///
  /// Кнопка лежит НА картинке, а не сбоку от неё: вынесенная в строку, она
  /// отжимала картинку влево, и та переставала стоять по центру экрана.
  ///
  /// Значок фотоаппарата, а не карандаш: карандашом в приложении меняют
  /// текст, и на снимке он читается как «переименовать». Тот же значок и в
  /// том же углу стоит на карточках в списке способов.
  Widget _photoBlock() {
    final local = _photo;
    final saved = _saved;

    return GestureDetector(
      onTap: _pickPhoto,
      child: Stack(
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: local != null
                ? Image.file(File(local), fit: BoxFit.cover)
                : saved != null
                    ? Image.network(
                        saved,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.local_shipping_outlined,
                          color: textMuted,
                          size: 28,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: textSecondary, size: 28),
                          SizedBox(height: 8),
                          Text('Добавить изображение',
                              style: TextStyle(
                                  color: textSecondary, fontSize: 14)),
                        ],
                      ),
          ),

          // Подложка под значком нужна: на светлом снимке белый значок без
          // неё пропадает.
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.photo_camera_outlined,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupField() {
    return GestureDetector(
      onTap: widget.groups.isEmpty ? null : _pickGroup,
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
                widget.groups.isEmpty ? 'Групп пока нет' : _groupName,
                style: TextStyle(
                  color: widget.groups.isEmpty ? textMuted : textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  /// Цена с рублём в отдельной клетке, как на макете.
  Widget _price_() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Цена позиции',
            style: TextStyle(color: textPrimary, fontSize: 15)),
        const SizedBox(height: 8),
        Row(
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
                child: TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Можно не указывать',
                    hintStyle: TextStyle(color: textMuted, fontSize: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('₽',
                  style: TextStyle(color: textPrimary, fontSize: 16)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _text(
    String label,
    TextEditingController controller, {
    String hint = 'Введите',
    int lines = 1,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 15)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(8),
            border: error == null
                ? null
                : Border.all(color: const Color(0xFFE05B5B)),
          ),
          child: TextField(
            controller: controller,
            maxLines: lines,
            style: const TextStyle(color: textPrimary, fontSize: 15),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(color: textMuted, fontSize: 14),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error,
              style: const TextStyle(color: Color(0xFFE05B5B), fontSize: 12),
            ),
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

  Widget _dangerButton(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE05B5B)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFFE05B5B), fontSize: 16),
        ),
      ),
    );
  }
}

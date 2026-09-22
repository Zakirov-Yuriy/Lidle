// ============================================================
//  Блоки-оформление формы подачи (22.09.2026)
// ============================================================
//
// Два стиля атрибута, которые ничего не хранят в объявлении, а только
// рисуют блок там, куда админ их поставил (порядок атрибута):
//
//   O / O1  «Добавить …»   — заголовок («Добавить меню», «Добавить
//           сотрудника»), поле «Добавить» с синим плюсом, ссылка
//           «Добавить еще».
//   P / P1  блок с переходом — заголовок («Объединить в холдинг»), ссылки
//           «Что такое …?» (первое значение атрибута) и «Как это
//           работает?», поле «Перейти» со стрелкой.
//
// Что именно добавляется и куда ведёт «Перейти», у каждого блока своё и
// делается отдельно. Пока нажатие честно говорит «Скоро», а не молчит.
// Значений эти атрибуты не отдают: форма их в `attributes` не кладёт, и
// сервер «обязательность» к ним не применяет (FormBlockStyles на бэке).

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/block_item.dart';
import 'package:lidle/models/filter_models.dart';

const Color _divider = Color(0xFF474747);

void _soon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('«$what» скоро будет доступно'),
        backgroundColor: secondaryBackground,
        duration: const Duration(seconds: 2),
      ),
    );
}

/// Тёмное поле с подписью и квадратная кнопка справа, как на макете.
class _FieldWithButton extends StatelessWidget {
  const _FieldWithButton({
    required this.label,
    required this.button,
    required this.onTap,
  });

  final String label;
  final Widget button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 45,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: const TextStyle(color: textPrimary, fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 45,
            height: 45,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: button,
          ),
        ),
      ],
    );
  }
}

/// Стиль O: «Добавить меню», «Добавить сотрудника» и так далее.
///
/// Если у блока есть свой экран (поля из админки, например залы у «Добавить
/// общий план зала»), форма передаёт [onAdd] и список добавленного: плюс и
/// «Добавить еще» открывают экран, добавленное видно строками, нажатие на
/// строку открывает правку. Без экрана нажатие говорит «скоро».
class AddListBlockField extends StatelessWidget {
  const AddListBlockField({
    super.key,
    required this.attribute,
    this.items = const [],
    this.onAdd,
    this.onOpen,
    this.onRemove,
  });

  final Attribute attribute;
  final List<BlockItemDraft> items;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onOpen;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    final title = attribute.title;
    final add = onAdd ?? () => _soon(context, title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: _divider, height: 1),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(color: textPrimary, fontSize: 16),
        ),
        const SizedBox(height: 9),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ItemRow(
              item: items[i],
              onTap: onOpen == null ? null : () => onOpen!(i),
              onRemove: onRemove == null ? null : () => onRemove!(i),
            ),
          ),
        if (items.isEmpty)
          _FieldWithButton(
            label: 'Добавить',
            onTap: add,
            button: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: activeIconColor, width: 1.6),
              ),
              child: const Icon(Icons.add, color: activeIconColor, size: 16),
            ),
          ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: add,
          child: const Text(
            'Добавить еще',
            style: TextStyle(color: activeIconColor, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Добавленный зал: название, остальное строкой ниже, крестик.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, this.onTap, this.onRemove});

  final BlockItemDraft item;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final rest = item.summary.skip(1).map((e) => e.value).join(' · ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              item.hasFile
                  ? (item.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined)
                  : Icons.table_restaurant_outlined,
              color: activeIconColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(color: textPrimary, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (rest.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        rest,
                        style: const TextStyle(color: textSecondary, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, color: textSecondary, size: 20),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

/// Стиль P: «Объединить в холдинг», «Таблица распределения».
///
/// Первая ссылка берётся из первого значения атрибута («Что такое
/// холдинг?»), её админ пишет сам. Вторая всегда «Как это работает?».
class LinkBlockField extends StatelessWidget {
  const LinkBlockField({super.key, required this.attribute});

  final Attribute attribute;

  @override
  Widget build(BuildContext context) {
    final title = attribute.title;
    final question =
        attribute.values.isNotEmpty ? attribute.values.first.value.trim() : '';

    Widget link(String text) => GestureDetector(
          onTap: () => _soon(context, title),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              text,
              style: const TextStyle(color: activeIconColor, fontSize: 14),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: _divider, height: 1),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (question.isNotEmpty) link(question),
        link('Как это работает?'),
        const SizedBox(height: 8),
        _FieldWithButton(
          label: 'Перейти',
          onTap: () => _soon(context, title),
          button: const Icon(
            Icons.chevron_right,
            color: textSecondary,
            size: 26,
          ),
        ),
        const SizedBox(height: 18),
        const Divider(color: _divider, height: 1),
        const SizedBox(height: 8),
      ],
    );
  }
}

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
import 'package:lidle/pages/dynamic_filter/block/block_item_screen.dart';

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

/// Строка содержимого блока: как в списке товаров публикации (23.09.2026).
class BlockLine {
  const BlockLine({
    required this.title,
    this.subtitle,
    this.trailing,
    this.isGroup = false,
  });

  /// Название позиции или группы.
  final String title;

  /// Вторая строка мелким: цвет, размеры, описание.
  final String? subtitle;

  /// Значение справа: «40 шт», «от 800 ₽».
  final String? trailing;

  /// Заголовок группы внутри экрана, а не сама позиция.
  final bool isGroup;
}

/// Добавленное списком: меню, товары, услуги, сотрудники (23.09.2026).
///
/// Вид повторяет экран «Добавить товар» в товарах (решение Анны 23.09.2026):
/// поле «Добавить» с плюсом, ниже заведённое раскрывающимися разделами.
/// Заголовок раздела со стрелкой, внутри строки содержимого со значением
/// справа, снизу «Удалить» слева и «Изменить» справа.
///
/// Карусель с картинкой осталась только у общего плана зала: там картинка и
/// есть смысл блока.
class BlockItemsListField extends StatefulWidget {
  const BlockItemsListField({
    super.key,
    required this.attribute,
    this.items = const [],
    this.onAdd,
    this.onOpen,
    this.onRemove,
    this.details,
    this.titleOf,
  });

  final Attribute attribute;
  final List<BlockItemDraft> items;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onOpen;
  final ValueChanged<int>? onRemove;

  /// Строки раздела: у меню группы и блюда, у остальных поля экрана.
  final List<BlockLine> Function(BlockItemDraft item)? details;

  /// Название раздела, если его не взять из первого поля экрана.
  final String Function(BlockItemDraft item)? titleOf;

  @override
  State<BlockItemsListField> createState() => _BlockItemsListFieldState();
}

class _BlockItemsListFieldState extends State<BlockItemsListField> {
  /// Раскрытые разделы. Первый открыт сразу: иначе экран выглядит пустым.
  final Set<int> _open = {0};

  List<BlockLine> _lines(BlockItemDraft item) {
    if (widget.details != null) return widget.details!(item);

    return [
      for (final e in item.summary.skip(1)) BlockLine(title: e.key, trailing: e.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.attribute.title;
    final add = widget.onAdd ?? () => _soon(context, title);
    final items = widget.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: _divider, height: 1),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: textPrimary, fontSize: 16)),
        const SizedBox(height: 9),
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
        for (var i = 0; i < items.length; i++) ..._section(i, items[i]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: add,
          child: const Text('Добавить еще',
              style: TextStyle(color: activeIconColor, fontSize: 13)),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  /// Один раздел: заголовок со стрелкой и, если раскрыт, содержимое.
  List<Widget> _section(int index, BlockItemDraft item) {
    final isOpen = _open.contains(index);

    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            isOpen ? _open.remove(index) : _open.add(index);
          }),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.titleOf?.call(item) ?? item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    ];

    if (!isOpen) return widgets;

    final lines = _lines(item);

    if (lines.isEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Здесь пока пусто',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    for (final line in lines) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: line.isGroup ? 12 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: line.isGroup ? textPrimary : textSecondary,
                        fontSize: line.isGroup ? 14 : 14,
                        fontWeight: line.isGroup ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (line.subtitle != null && line.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        line.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (line.trailing != null && line.trailing!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  line.trailing!,
                  style: const TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ],
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
              onTap: () => _remove(index),
              child: const Text('Удалить',
                  style: TextStyle(color: Color(0xFFE05B5B), fontSize: 14)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => widget.onOpen?.call(index),
              child: const Text('Изменить',
                  style: TextStyle(color: activeIconColor, fontSize: 14)),
            ),
          ],
        ),
      ),
    );

    return widgets;
  }

  /// Удаление сдвигает номера, поэтому раскрытые разделы пересобираем.
  void _remove(int index) {
    widget.onRemove?.call(index);

    setState(() {
      _open
        ..clear()
        ..add(0);
    });
  }
}

/// Стиль O: «Добавить меню», «Добавить сотрудника» и так далее.
///
/// Если у блока есть свой экран (поля из админки, например залы у «Добавить
/// общий план зала»), форма передаёт [onAdd] и список добавленного.
///
/// Пусто: поле «Добавить» с плюсом. Есть добавленное (макет 22.09.2026):
///   поле с названием текущего зала и «Изменить»;
///   план зала листается стрелками и точками, по странице на зал;
///   снизу «Добавить еще» и красное «Удалить» (удаляет текущий).
/// Без экрана нажатие говорит «скоро».
class AddListBlockField extends StatefulWidget {
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
  State<AddListBlockField> createState() => _AddListBlockFieldState();
}

class _AddListBlockFieldState extends State<AddListBlockField> {
  final PageController _pages = PageController();
  int _current = 0;
  int _lastCount = 0;

  @override
  void didUpdateWidget(covariant AddListBlockField oldWidget) {
    super.didUpdateWidget(oldWidget);

    final count = widget.items.length;

    // Добавили зал — показываем его. Удалили — остаёмся в пределах списка.
    if (count > _lastCount && count > 0) {
      _current = count - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients) _pages.jumpToPage(_current);
      });
    } else if (_current >= count) {
      _current = count == 0 ? 0 : count - 1;
    }

    _lastCount = count;
  }

  @override
  void initState() {
    super.initState();
    _lastCount = widget.items.length;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (page < 0 || page >= widget.items.length) return;
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.attribute.title;
    final items = widget.items;
    final add = widget.onAdd ?? () => _soon(context, title);

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
        if (items.isEmpty) ...[
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
        ] else ...[
          // Название текущего зала и «Изменить».
          GestureDetector(
            onTap: () => widget.onOpen?.call(_current),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      items[_current].title,
                      style: const TextStyle(color: textPrimary, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(
                    'Изменить',
                    style: TextStyle(color: activeIconColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // План: по странице на зал, стрелки по бокам.
          SizedBox(
            height: 190,
            child: Row(
              children: [
                _Arrow(
                  icon: Icons.chevron_left,
                  enabled: _current > 0,
                  onTap: () => _go(_current - 1),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: items.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (context, i) => GestureDetector(
                      onTap: () => widget.onOpen?.call(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _PlanPage(item: items[i]),
                      ),
                    ),
                  ),
                ),
                _Arrow(
                  icon: Icons.chevron_right,
                  enabled: _current < items.length - 1,
                  onTap: () => _go(_current + 1),
                ),
              ],
            ),
          ),
          if (items.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < items.length; i++)
                  GestureDetector(
                    onTap: () => _go(i),
                    child: Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _current ? activeIconColor : Colors.transparent,
                        border: Border.all(
                          color: i == _current ? activeIconColor : textSecondary,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              GestureDetector(
                onTap: add,
                child: const Text(
                  'Добавить еще',
                  style: TextStyle(color: activeIconColor, fontSize: 13),
                ),
              ),
              const Spacer(),
              if (widget.onRemove != null)
                GestureDetector(
                  onTap: () => widget.onRemove!(_current),
                  child: const Text(
                    'Удалить',
                    style: TextStyle(color: Color(0xFFFF4D4D), fontSize: 13),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 26,
        child: Icon(
          icon,
          size: 30,
          color: enabled ? textSecondary : textSecondary.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

/// Страница карусели: план зала, а без файла — плашка с названием.
class _PlanPage extends StatelessWidget {
  const _PlanPage({required this.item});

  final BlockItemDraft item;

  @override
  Widget build(BuildContext context) {
    if (item.hasFile) {
      return Center(
        child: BlockFilePreview(
          localPath: item.localFilePath,
          remoteUrl: item.remoteFileUrl,
          kind: item.fileKind,
        ),
      );
    }

    final rest = item.summary.skip(1).map((e) => '${e.key}: ${e.value}').join('\n');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.table_restaurant_outlined, color: activeIconColor),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              rest.isEmpty ? 'План не добавлен' : rest,
              style: const TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }
}

/// Стиль P: «Объединить в холдинг», «Таблица распределения».
///
/// Первая ссылка берётся из первого значения атрибута («Что такое
/// холдинг?»), её админ пишет сам. Вторая всегда «Как это работает?».
class LinkBlockField extends StatelessWidget {
  const LinkBlockField({super.key, required this.attribute, this.onGo});

  final Attribute attribute;

  /// Что делает «Перейти». Нет — «скоро» (22.09.2026: у «Таблицы
  /// распределения» это экран сценариев).
  final VoidCallback? onGo;

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
          onTap: onGo ?? () => _soon(context, title),
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

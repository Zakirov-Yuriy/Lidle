// ============================================================
// Экран «Добавить позицию»: сотрудник (макет 10.09.2026).
// ============================================================
//
// Тот же по устройству экран, что позиция товара и способ доставки:
// картинка, поля, внизу «Удалить» и «Сохранить». Один экран на заведение и на
// правку.
//
// Должность приходит ХАРАКТЕРИСТИКОЙ РАЗДЕЛА, как размер у одежды: список
// ведёт администратор в супер-админке. У ресторана свои должности, у
// автосервиса свои, и зашивать их в приложение значит однажды получить заявку
// «добавьте шиномонтажника».
//
// Доступы, наоборот, приходят из кода сервера: каждый пункт — это раздел
// приложения, и список должен совпадать с ним один в один.
//
// График работы на макете есть, за ним три отдельных экрана (период,
// календарь, часы). Кнопка нарисована и погашена: показать её честнее, чем
// потом переделывать вёрстку.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/pages/products/add_product/photo_source_sheet.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/services/api/products_staff_api.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/custom_radio_button.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductStaffMemberScreen extends StatefulWidget {
  const ProductStaffMemberScreen({
    super.key,
    required this.publicationId,
    required this.categoryId,
    required this.groups,
    this.existing,
    this.groupId,
  });

  final int publicationId;

  /// Раздел публикации: из него берётся список должностей.
  final int categoryId;

  final List<StaffGroup> groups;
  final StaffMember? existing;
  final int? groupId;

  @override
  State<ProductStaffMemberScreen> createState() =>
      _ProductStaffMemberScreenState();
}

class _ProductStaffMemberScreenState extends State<ProductStaffMemberScreen> {
  /// Столько символов просит макет в описании — как у товара и доставки.
  static const int _minDescription = 70;

  final _name = TextEditingController();
  final _number = TextEditingController();
  final _salary = TextEditingController();
  final _description = TextEditingController();

  int? _groupId;
  String? _position;

  final Set<String> _venue = {};
  final Set<String> _account = {};

  /// Должности из характеристики раздела и справочник доступов с сервера.
  List<String> _positions = const [];
  StaffAccessDictionary _access = const StaffAccessDictionary();

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
      _position = existing.position;
      _saved = existing.image;
      _venue.addAll(existing.venueAccess);
      _account.addAll(existing.accountAccess);

      if (existing.number != null) _number.text = '${existing.number}';

      final salary = existing.salary;

      if (salary != null) {
        _salary.text = salary % 1 == 0 ? '${salary.toInt()}' : '$salary';
      }
    }

    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _salary.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Должности и доступы. Отказ любого из запросов экран не роняет: без
  /// списков сотрудник всё равно сохранится, просто без должности и галочек.
  Future<void> _load() async {
    try {
      final fields = await ProductsCabinetApi.positionFields(widget.categoryId);

      final positions = _positionsFrom(fields);

      if (mounted) setState(() => _positions = positions);
    } catch (e) {
      log.d('Должности не пришли: $e');
    }

    try {
      final access = await ProductsStaffApi.access();

      if (mounted) setState(() => _access = access);
    } catch (e) {
      log.d('Справочник доступов не пришёл: $e');
    }
  }

  /// Значения характеристики «Должность» этого раздела.
  List<String> _positionsFrom(List<Attribute> fields) {
    for (final field in fields) {
      if (!field.title.toLowerCase().contains('должност')) continue;

      return field.values.map((value) => value.value).toList();
    }

    return const [];
  }

  // ── Действия ────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picked = await pickProductPhotos(context);

    if (picked.isEmpty || !mounted) return;

    setState(() => _photo = picked.first);

    final existing = widget.existing;

    if (existing == null) return;

    try {
      await ProductsStaffApi.uploadMemberImage(existing.id, picked.first);

      _say('Фотография сохранена.');
    } catch (e) {
      log.e('Фотография не загрузилась: $e');
      _say('Фотография не загрузилась. Проверьте связь и попробуйте ещё раз.');
    }
  }

  Future<void> _pickPosition() async {
    if (_positions.isEmpty) {
      _say('Должности заводит администратор в разделе. Пока их нет.');

      return;
    }

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => _RadioDialog(
        title: 'Выбор должности',
        options: _positions,
        selected: _position,
      ),
    );

    if (chosen == null || !mounted) return;

    setState(() => _position = chosen);
  }

  Future<void> _pickAccess({required bool venue}) async {
    final items = venue ? _access.venue : _access.account;

    if (items.isEmpty) {
      _say('Список доступов не загрузился. Проверьте связь.');

      return;
    }

    final chosen = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _ChecksDialog(
        title: venue
            ? 'Доступы к управлению заведением'
            : 'Доступы к управлению аккаунтом',
        items: items,
        selected: venue ? _venue : _account,

        // «Полный доступ от аккаунта» на макете отделён чертой: он не пункт
        // в ряду, а замена всему списку.
        separateLast: !venue,
      ),
    );

    if (chosen == null || !mounted) return;

    setState(() {
      final target = venue ? _venue : _account;

      target
        ..clear()
        ..addAll(chosen);
    });
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

    setState(() => _groupId = chosen is StaffGroup ? chosen.id : null);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() {
      _errors.clear();

      if (_name.text.trim().length < 2) {
        _errors['name'] = 'Напишите имя сотрудника';
      }

      final description = _description.text.trim();

      if (description.isNotEmpty && description.length < _minDescription) {
        _errors['description'] =
            'Не меньше $_minDescription символов, сейчас ${description.length}';
      }
    });

    if (_errors.isNotEmpty) return;

    setState(() => _isSaving = true);

    final salary = num.tryParse(
      _salary.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
    );

    try {
      final existing = widget.existing;

      if (existing != null) {
        await ProductsStaffApi.updateMember(
          existing.id,
          name: _name.text.trim(),
          position: _position,
          number: int.tryParse(_number.text.trim()),
          salary: salary,

          // Пустое поле означает «убрать», а не «не менял».
          touchSalary: true,
          venueAccess: _venue.toList(),
          accountAccess: _account.toList(),
          description: _description.text.trim(),
          groupId: _groupId,
        );
      } else {
        final created = await ProductsStaffApi.createMember(
          publicationId: widget.publicationId,
          name: _name.text.trim(),
          position: _position,
          number: int.tryParse(_number.text.trim()),
          salary: salary,
          venueAccess: _venue.toList(),
          accountAccess: _account.toList(),
          description: _description.text.trim(),
          groupId: _groupId,
        );

        // Фотография вторым запросом: её принимают только к существующей
        // записи. Неудача сотрудника не отменяет.
        if (_photo != null) {
          try {
            await ProductsStaffApi.uploadMemberImage(created.id, _photo!);
          } catch (e) {
            log.e('Фотография не загрузилась: $e');

            if (mounted) _say('Сотрудник сохранён, а фотография не загрузилась.');
          }
        }
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      log.e('Сотрудник не сохранился: $e');

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
        title: const Text('Удалить сотрудника?',
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
      await ProductsStaffApi.deleteMember(existing.id);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      log.e('Сотрудник не удалился: $e');
      _say('Не получилось удалить сотрудника.');
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

  /// Подпись у доступов: сколько отмечено.
  String _accessLabel(Set<String> chosen, List<StaffAccessItem> items) {
    if (chosen.isEmpty) return 'Выбрать';

    if (chosen.length == 1) {
      for (final item in items) {
        if (item.key == chosen.first) return item.title;
      }
    }

    return 'Выбрано: ${chosen.length}';
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
                  _text('Имя сотрудника', _name,
                      hint: 'Например, Ольга', error: _errors['name']),

                  const SizedBox(height: 20),
                  _picker(
                    'Выбор должности',
                    _position ?? 'Выбрать',
                    onTap: _pickPosition,
                    filled: _position != null,
                  ),

                  const SizedBox(height: 20),
                  _picker(
                    'Выбор группы',
                    widget.groups.isEmpty ? 'Групп пока нет' : _groupName,
                    onTap: widget.groups.isEmpty ? null : _pickGroup,
                    filled: widget.groups.isNotEmpty,
                  ),

                  const SizedBox(height: 20),
                  _text('Номер позиции', _number,
                      hint: 'Например, 1', keyboard: TextInputType.number),

                  const SizedBox(height: 20),
                  _salaryField(),

                  const SizedBox(height: 20),
                  _picker(
                    'Доступы к управлению заведением',
                    _accessLabel(_venue, _access.venue),
                    onTap: () => _pickAccess(venue: true),
                    filled: _venue.isNotEmpty,
                  ),

                  const SizedBox(height: 20),
                  _picker(
                    'Доступы к управлению аккаунтом',
                    _accessLabel(_account, _access.account),
                    onTap: () => _pickAccess(venue: false),
                    filled: _account.isNotEmpty,
                  ),

                  const SizedBox(height: 20),
                  _scheduleRow(),

                  const SizedBox(height: 20),
                  _text(
                    'Описание позиции',
                    _description,
                    hint: 'Что делает человек, за что отвечает, в какие смены'
                        ' выходит.',
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
                    _dangerButton('Удалить сотрудника', onTap: _delete),
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

  Widget _photoBlock() {
    final local = _photo;
    final saved = _saved;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              height: 150,
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
                            Icons.person_outline,
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
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_outlined,
                color: activeIconColor, size: 18),
          ),
        ),
      ],
    );
  }

  /// Строка выбора: подпись сверху, значение и шеврон.
  Widget _picker(
    String label,
    String value, {
    VoidCallback? onTap,
    bool filled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 15)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
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
                    value,
                    style: TextStyle(
                      color: filled ? textPrimary : textMuted,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down,
                    color: textMuted, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Зарплата с рублём в отдельной клетке, как на макете.
  Widget _salaryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Зарплата в месяц',
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
                  controller: _salary,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Введите',
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

  /// График работы: экраны за ним ещё не сделаны.
  Widget _scheduleRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('График работы сотрудника',
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
                child: const Text('Перейти',
                    style: TextStyle(color: textMuted, fontSize: 15)),
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
              child: const Icon(Icons.chevron_right,
                  color: textMuted, size: 22),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Экран графика ещё не сделан',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _text(
    String label,
    TextEditingController controller, {
    String hint = 'Введите',
    int lines = 1,
    TextInputType? keyboard,
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
            keyboardType: keyboard,
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

/// Диалог одиночного выбора: должность.
class _RadioDialog extends StatefulWidget {
  const _RadioDialog({
    required this.title,
    required this.options,
    this.selected,
  });

  final String title;
  final List<String> options;
  final String? selected;

  @override
  State<_RadioDialog> createState() => _RadioDialogState();
}

class _RadioDialogState extends State<_RadioDialog> {
  late String? _chosen = widget.selected;

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: widget.title,
      onDone: _chosen == null ? null : () => Navigator.pop(context, _chosen),
      children: [
        for (final option in widget.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GestureDetector(
              onTap: () => setState(() => _chosen = option),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option,
                      style: const TextStyle(color: textPrimary, fontSize: 16),
                    ),
                  ),
                  CustomRadioButton<String>(
                    value: option,
                    groupValue: _chosen,
                    onChanged: (value) => setState(() => _chosen = value),
                    selectedBorderColor: const Color(0xFF888888),
                    unselectedBorderColor: const Color(0xFF888888),
                    selectedFillColor: const Color(0xFF00A6FF),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Диалог множественного выбора: доступы.
class _ChecksDialog extends StatefulWidget {
  const _ChecksDialog({
    required this.title,
    required this.items,
    required this.selected,
    this.separateLast = false,
  });

  final String title;
  final List<StaffAccessItem> items;
  final Set<String> selected;

  /// Отделить последний пункт чертой: на макете «Полный доступ от аккаунта»
  /// стоит особняком.
  final bool separateLast;

  @override
  State<_ChecksDialog> createState() => _ChecksDialogState();
}

class _ChecksDialogState extends State<_ChecksDialog> {
  late final Set<String> _chosen = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var index = 0; index < widget.items.length; index++) {
      final item = widget.items[index];
      final isLast = index == widget.items.length - 1;

      if (widget.separateLast && isLast) {
        rows.add(const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Divider(color: Color(0xFF2A3744), height: 1),
        ));
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () => setState(() {
              if (!_chosen.remove(item.key)) _chosen.add(item.key);
            }),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(color: textPrimary, fontSize: 16),
                  ),
                ),
                CustomCheckbox(
                  value: _chosen.contains(item.key),
                  onChanged: (value) => setState(() {
                    value ? _chosen.add(item.key) : _chosen.remove(item.key);
                  }),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _DialogShell(
      title: widget.title,
      onDone: () => Navigator.pop(context, _chosen),
      children: rows,
    );
  }
}

/// Общая оболочка диалогов: заголовок с крестиком, «Отмена» и «Готово».
class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.title,
    required this.children,
    this.onDone,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: secondaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: textPrimary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: onDone,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: onDone == null ? textMuted : activeIconColor,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Готово',
                      style: TextStyle(
                        color: onDone == null ? textMuted : activeIconColor,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

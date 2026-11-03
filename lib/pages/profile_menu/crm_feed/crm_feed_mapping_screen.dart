// ============================================================
// "Виджет: Сопоставление колонок прайса с нашими характеристиками"
// ============================================================
//
// Задача 90, 03.11.2026.
//
// ЗАЧЕМ ЭТОТ ЭКРАН. Продавцы несут нам ровно тот файл, который отправляют в
// Авито, и переделывать его под нас не будут. В нём свои названия колонок,
// своё дерево категорий и свои значения: колонка «Тип конструкции» со
// значением «Сборно-разборный». Угадать за человека, что из этого наша
// характеристика, нельзя, поэтому стыкует он сам.
//
// Решение заказчика от 02.11.2026: сопоставление на стороне продавца, с
// возможностью открыть заново и поправить.
//
// СПРАШИВАЕМ ПРО НАШИ ХАРАКТЕРИСТИКИ, А НЕ ПРО ЕГО КОЛОНКИ (03.11.2026).
//
// Сначала было наоборот: список колонок файла, у каждой выбор характеристики.
// На живой выгрузке Авито колонок тридцать четыре, и для большинства верный
// ответ «никакая». Человек открывал «Номер телефона» и видел там размер и
// цвет, что выглядит бредом и им и является.
//
// Характеристик же у раздела единицы. Поэтому спрашиваем про них: «Размер, из
// какой колонки его брать?» Четыре вопроса вместо тридцати четырёх.
//
// ЧТО ЗДЕСЬ ЕСТЬ:
//  - раздел, один на весь файл (в выгрузке Авито вся книга это одна
//    категория), с подставленной догадкой по пути над шапкой и выбором
//    вручную, если догадка неверна;
//  - наши характеристики раздела, у каждой выбор колонки файла;
//  - для характеристик со справочником — стыковка значений.
//
// Очевидные совпадения сервер подставляет сам, человек поправляет.
//
// ПОЧЕМУ ОТБОР ХАРАКТЕРИСТИК НА СЕРВЕРЕ. Служебные поля вроде «Показывать по
// всей России» для стыковки не годятся, в них не положишь значение из
// колонки. Отсеивает их сервер, и при смене раздела экран просто
// переспрашивает тот же маршрут: иначе правила отбора разъехались бы.
//
// API:
// - GET  /me/crm-feeds/{id}/mapping[?category_id=]  — что показать
// - POST /me/crm-feeds/{id}/mapping                 — сохранить и перезапустить

import 'package:flutter/material.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';

class CrmFeedMappingScreen extends StatefulWidget {
  static const routeName = '/crm_feed_mapping';

  final int feedId;

  const CrmFeedMappingScreen({super.key, required this.feedId});

  @override
  State<CrmFeedMappingScreen> createState() => _CrmFeedMappingScreenState();
}

class _CrmFeedMappingScreenState extends State<CrmFeedMappingScreen> {
  static const bgColor = Color(0xFF243241);

  // Тот же цвет карточки, что на экране автозагрузки через CRM (03.11.2026).
  // Здесь был свой, светлее, и два соседних экрана выглядели из разных
  // приложений. Цвет один на карточки, окна и выпадающие списки.
  static const cardColor = Color(0xFF1F2C3A);
  static const warnText = Color(0xFFE8D6A8);
  static const warnBack = Color(0xFF3A2E14);
  static const warnAccent = Color(0xFFE0B33C);

  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// Путь категории из файла: объясняет человеку, откуда взялась догадка.
  List<String> _categoryPath = [];
  int? _categoryId;
  String? _categoryName;

  /// Товарные разделы на выбор.
  List<Map<String, dynamic>> _categories = [];

  /// Колонки файла: title, samples, attribute_id.
  List<Map<String, dynamic>> _columns = [];

  /// Характеристики раздела: id, title, is_required, values.
  List<Map<String, dynamic>> _attributes = [];

  /// Стыковка значений: колонка -> значение из файла -> номер нашего.
  Map<String, Map<String, int>> _values = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Загрузить черновик сопоставления.
  ///
  /// `categoryId` это «покажи, что будет, если выбрать вот этот раздел»:
  /// сервер отдаёт характеристики нового раздела и свежие догадки.
  Future<void> _load({int? categoryId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = categoryId == null ? '' : '?category_id=$categoryId';

      final response =
          await ApiService.get('/me/crm-feeds/${widget.feedId}/mapping$query');

      if (response['success'] == false) {
        setState(() {
          _error = response['message'] as String? ??
              'Не удалось открыть сопоставление';
          _loading = false;
        });

        return;
      }

      final data = (response['data'] as Map?) ?? {};

      setState(() {
        _categoryPath =
            ((data['category_path'] as List?) ?? []).map((e) => '$e').toList();
        _categoryId = data['category_id'] as int?;
        _categoryName = data['category_name'] as String?;
        _categories = _mapList(data['categories']);
        _columns = _mapList(data['columns']);
        _attributes = _mapList(data['attributes']);
        _values = _readValues(data['values']);
        _loading = false;
      });
    } catch (e) {
      log.d('Ошибка загрузки сопоставления: $e');

      setState(() {
        _error = 'Не удалось открыть сопоставление';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Разбор стыковки значений.
  ///
  /// Пустая карта в JSON неотличима от пустого списка, поэтому разбираем
  /// осторожно, а не приведением типа.
  Map<String, Map<String, int>> _readValues(dynamic raw) {
    final result = <String, Map<String, int>>{};

    if (raw is! Map) return result;

    raw.forEach((column, pairs) {
      if (pairs is! Map) return;

      final inner = <String, int>{};

      pairs.forEach((value, id) {
        final parsed = id is int ? id : int.tryParse('$id');

        if (parsed != null && parsed > 0) inner['$value'] = parsed;
      });

      if (inner.isNotEmpty) result['$column'] = inner;
    });

    return result;
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final columns = <String, int>{};

      for (final column in _columns) {
        final id = column['attribute_id'];

        if (id is int && id > 0) columns['${column['title']}'] = id;
      }

      final response = await ApiService.post(
        '/me/crm-feeds/${widget.feedId}/mapping',
        {
          'category_id': _categoryId,
          'columns': columns,
          'values': _values,
        },
      );

      if (!mounted) return;

      if (response['success'] == false) {
        _snack(response['message'] as String? ?? 'Не удалось сохранить');

        return;
      }

      _snack('Сохранено, товары обновляются');
      Navigator.pop(context, true);
    } catch (e) {
      log.d('Ошибка сохранения сопоставления: $e');
      if (mounted) _snack('Не удалось сохранить');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  /// Выбор раздела: список с поиском.
  Future<void> _pickCategory() async {
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CategoryPicker(categories: _categories),
    );

    if (chosen == null || !mounted) return;

    // Характеристики принадлежат разделу, значит со сменой раздела прежние
    // стыковки ни к чему не относятся. Сервер это знает и отдаёт свежие
    // догадки сам, поэтому просто перезапрашиваем.
    await _load(categoryId: chosen['id'] as int?);
  }

  /// Многозначная ячейка на отдельные значения.
  ///
  /// Авито складывает их в одну ячейку через палку: «Сборно-разборный |
  /// Стационарный | Передвижной». Точка с запятой встречается у других.
  List<String> _splitSample(String sample) {
    return sample
        .split(RegExp(r'\s*[|;]\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12, right: 23),
              child: Row(children: [Header()]),
            ),
            _buildBack(),
            Expanded(child: _buildBody()),
            if (!_loading && _error == null) _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBack() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Row(
          children: [
            Icon(Icons.chevron_left, color: activeIconColor, size: 26),
            Text(
              'Назад',
              style: TextStyle(
                color: activeIconColor,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(25),
        child: Center(
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      );
    }

    final hasAttributes = _attributes.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        const Text(
          'Характеристики раздела',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasAttributes
              ? 'Укажите, из какой колонки вашего файла брать каждую '
                  'характеристику. Что совпало по названию, мы подставили '
                  'сами. Ненужную можно оставить незаполненной.'
              : 'Сначала выберите раздел: характеристики принадлежат ему.',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildCategoryCard(),
        const SizedBox(height: 16),
        if (!hasAttributes)
          _buildNoAttributes()
        else ...[
          ..._attributes.map(_buildAttributeCard),
          const SizedBox(height: 8),
          _buildSystemNote(),
        ],
      ],
    );
  }

  /// Что мы разбираем сами, без всякой настройки.
  ///
  /// Человеку важно видеть, что название, цена и фотографии уже работают, и
  /// их отсутствие в списке выше не значит, что они потеряются.
  Widget _buildSystemNote() {
    final known = _columns
        .where((c) => c['system'] != null)
        .map((c) => '${c['title']} — ${c['system']}')
        .toList();

    if (known.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Эти колонки загружаются сами',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            known.join('\n'),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Одна наша характеристика: из какой колонки её брать.
  Widget _buildAttributeCard(Map<String, dynamic> attribute) {
    final attributeId = attribute['id'] as int?;
    final column = _columnForAttribute(attributeId);
    final columnTitle = column == null ? null : '${column['title']}';
    final samples =
        ((column?['samples'] as List?) ?? []).map((e) => '$e').toList();
    final values = _mapList(attribute['values']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${attribute['title']}'
            '${attribute['is_required'] == true ? ' (обязательная)' : ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Из какой колонки файла',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildColumnPicker(attributeId, columnTitle),
          if (samples.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'В файле: ${samples.join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],

          // Стыковка значений нужна только там, где у характеристики есть
          // справочник: «Б/у» продавца к нашему «Б/у».
          if (columnTitle != null && values.isNotEmpty && samples.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Значения',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            ...samples
                .expand(_splitSample)
                .toSet()
                .map((part) => _buildValuePicker(columnTitle, part, values)),
          ],
        ],
      ),
    );
  }

  /// Колонка, из которой сейчас берётся эта характеристика.
  Map<String, dynamic>? _columnForAttribute(int? attributeId) {
    if (attributeId == null) return null;

    for (final column in _columns) {
      if (column['attribute_id'] == attributeId) return column;
    }

    return null;
  }

  /// Выбор колонки файла для характеристики.
  ///
  /// Системные колонки в список не попадают: название и цена уже разбираются
  /// сами, и брать из них характеристику незачем. Занятые другими
  /// характеристиками тоже скрыты: одна колонка это одна характеристика.
  Widget _buildColumnPicker(int? attributeId, String? selected) {
    final taken = <String>{};

    for (final column in _columns) {
      final id = column['attribute_id'];

      if (id is int && id > 0 && id != attributeId) {
        taken.add('${column['title']}');
      }
    }

    final options = _columns
        .where((c) => c['system'] == null)
        .map((c) => '${c['title']}')
        .where((title) => title == selected || !taken.contains(title))
        .toList();

    // Та же защита, что у значений: колонка могла пропасть из файла, а в
    // сохранённом сопоставлении остаться.
    final current = options.contains(selected) ? selected : null;

    return DropdownButtonFormField<String?>(
      // Ключ с текущим выбором обязателен: поле формы держит своё состояние
      // и после setState показало бы прежнее значение.
      key: ValueKey('col-$attributeId-$current'),
      initialValue: current,
      isExpanded: true,
      dropdownColor: cardColor,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: activeIconColor),
        ),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Не заполнять', style: TextStyle(color: Colors.white54)),
        ),
        ...options.map(
          (title) => DropdownMenuItem<String?>(
            value: title,
            child: Text(title, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (title) {
        setState(() {
          // Снимаем характеристику со старой колонки и ставим на новую:
          // хранится это по-прежнему на колонке.
          for (final column in _columns) {
            if (column['attribute_id'] == attributeId) {
              _values.remove('${column['title']}');
              column['attribute_id'] = null;
            }

            if (title != null && '${column['title']}' == title) {
              column['attribute_id'] = attributeId;
            }
          }
        });
      },
    );
  }

  Widget _buildCategoryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Раздел для всего файла',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_categoryPath.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'В файле указано: ${_categoryPath.join(' / ')}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: _categories.isEmpty ? null : _pickCategory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _categoryName ?? 'Раздел не выбран',
                      style: TextStyle(
                        color:
                            _categoryName == null ? warnAccent : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.expand_more,
                    color: Colors.white54,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _categoryId == null
                ? 'Пока раздел не выбран, товары из файла не загрузятся.'
                : 'Характеристик в разделе: ${_attributes.length}',
            style: TextStyle(
              color: _categoryId == null ? warnAccent : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAttributes() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warnBack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'У этого раздела нет характеристик, поэтому стыковать колонки не с '
        'чем. Название, цена, адрес и фотографии при этом загружаются как '
        'обычно. Выберите другой раздел или попросите завести характеристики '
        'этому.',
        style: TextStyle(color: warnText, fontSize: 13),
      ),
    );
  }
  Widget _buildValuePicker(
    String column,
    String sample,
    List<Map<String, dynamic>> values,
  ) {
    final saved = _values[column]?[sample];

    /*
     * Выбранное значение могло исчезнуть (03.11.2026).
     *
     * Админ удалил характеристику и завёл заново, номера значений сменились,
     * а в сохранённом сопоставлении остались прежние. Выпадающий список на
     * такое не рассчитан: он падает, если текущее значение не нашлось среди
     * пунктов. Поэтому проверяем сами и показываем «Нет».
     */
    final selected = values.any((v) => v['id'] == saved) ? saved : null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              sample,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int?>(
              key: ValueKey('val-$column-$sample-$selected'),
              initialValue: selected,
              isExpanded: true,
              dropdownColor: cardColor,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: activeIconColor),
                ),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Нет', style: TextStyle(color: Colors.white54)),
                ),
                ...values.map(
                  (value) => DropdownMenuItem<int?>(
                    value: value['id'] as int,
                    child: Text(
                      '${value['title']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  final inner = _values[column] ?? <String, int>{};

                  if (value == null) {
                    inner.remove(sample);
                  } else {
                    inner[sample] = value;
                  }

                  if (inner.isEmpty) {
                    _values.remove(column);
                  } else {
                    _values[column] = inner;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: activeIconColor,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Сохранить и обновить товары',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Выбор раздела: список с поиском по названию.
///
/// Списком, а не выпадашкой: товарных разделов сотни, и колесом их не
/// пролистать. Строка поиска решает это одним полем.
class _CategoryPicker extends StatefulWidget {
  final List<Map<String, dynamic>> categories;

  const _CategoryPicker({required this.categories});

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visible {
    final needle = _query.trim().toLowerCase();

    if (needle.isEmpty) return widget.categories;

    // Ищем и по каталогу тоже: человек помнит «мебель», а не точное
    // название конечного раздела.
    return widget.categories
        .where((c) =>
            '${c['name']}'.toLowerCase().contains(needle) ||
            '${c['catalog']}'.toLowerCase().contains(needle))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _search,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Найти раздел',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: activeIconColor),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text(
                        'Ничего не нашлось',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (_, index) {
                        final category = list[index];

                        final catalog = '${category['catalog']}';

                        return ListTile(
                          title: Text(
                            '${category['name']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          // Каталог подписью: в товарном дереве есть и
                          // транспорт, и по одному слову «Феррари» понять,
                          // откуда оно, нельзя.
                          subtitle: catalog.isEmpty
                              ? null
                              : Text(
                                  catalog,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                          onTap: () => Navigator.pop(context, category),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

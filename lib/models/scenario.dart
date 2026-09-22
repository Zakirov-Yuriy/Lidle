import 'package:lidle/models/block_item.dart';

/// Кто обслуживает стол в сценарии (22.09.2026). Официант и администратор
/// это экраны блока «Добавить сотрудника».
class TableStaff {
  BlockItemDraft? waiter;
  BlockItemDraft? admin;

  TableStaff({this.waiter, this.admin});

  bool get isEmpty => waiter == null && admin == null;

  TableStaff copy() => TableStaff(waiter: waiter, admin: admin);
}

/// Сценарий бизнеса, «Таблица распределения» (22.09.2026).
///
/// Набор отмеченного из блоков «Добавить …» этой же формы: какие залы,
/// какое меню, товары, услуги, доставка, сотрудники и оплата работают
/// вместе. Отмеченное хранится ссылками на сами экраны блоков (а не
/// номерами): пока объявление не отправлено, номеров на сервере у залов
/// ещё нет. Номера подставляются при отправке.
class ScenarioDraft {
  int? serverId;
  String name;

  /// Номер блока → отмеченные экраны этого блока.
  final Map<int, List<BlockItemDraft>> selected;

  /// Персонал столов в этом сценарии: зал → ключ стола → официант и
  /// администратор (22.09.2026).
  final Map<BlockItemDraft, Map<String, TableStaff>> tables;

  ScenarioDraft({
    this.serverId,
    required this.name,
    Map<int, List<BlockItemDraft>>? selected,
    Map<BlockItemDraft, Map<String, TableStaff>>? tables,
  })  : selected = selected ?? {},
        tables = tables ?? {};

  bool get isEmpty => selected.values.every((l) => l.isEmpty);

  ScenarioDraft copy() => ScenarioDraft(
        serverId: serverId,
        name: name,
        selected: {for (final e in selected.entries) e.key: List.of(e.value)},
        tables: {
          for (final e in tables.entries)
            e.key: {for (final t in e.value.entries) t.key: t.value.copy()},
        },
      );

  /// Убрать ссылки на удалённый экран блока.
  void forget(BlockItemDraft item) {
    for (final list in selected.values) {
      list.remove(item);
    }

    // Удалённый зал уносит свои столы, удалённый сотрудник снимается со
    // столов.
    tables.remove(item);
    for (final hall in tables.values) {
      for (final staff in hall.values) {
        if (staff.waiter == item) staff.waiter = null;
        if (staff.admin == item) staff.admin = null;
      }
    }
  }
}

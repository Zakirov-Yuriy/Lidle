import 'package:lidle/models/block_item.dart';
import 'package:lidle/models/menu_content.dart';

/// Сотрудник из справочника человека (25.09.2026).
///
/// Раньше за столом стоял экран блока «Добавить сотрудника», и у каждого
/// заведения были свои карточки людей. Теперь справочник общий: за столом
/// стоит сам человек, а экран блока только отмечает галочкой, кто здесь
/// работает.
class StaffRef {
  final int id;
  final String name;
  final String role;
  final String? imageUrl;

  const StaffRef({
    required this.id,
    required this.name,
    this.role = '',
    this.imageUrl,
  });

  /// Из позиции экрана блока: её ключ это «s<номер сотрудника>».
  static StaffRef? tryFrom(MenuItem item) {
    if (!item.key.startsWith('s')) return null;

    final id = int.tryParse(item.key.substring(1));
    if (id == null || id <= 0) return null;

    return StaffRef(id: id, name: item.name, role: item.role, imageUrl: item.imageUrl);
  }

  @override
  bool operator ==(Object other) => other is StaffRef && other.id == id;

  @override
  int get hashCode => id;
}

/// Кто обслуживает стол в сценарии (22.09.2026, справочник с 25.09.2026).
class TableStaff {
  StaffRef? waiter;
  StaffRef? admin;

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

    // Удалённый зал уносит свои столы.
    tables.remove(item);
  }

  /// Снять со столов тех, кого больше нет среди отмеченных сотрудников
  /// (25.09.2026): галочку сняли или человека удалили из справочника.
  /// Возвращает, пришлось ли кого-то снять: по этому признаку форма решает,
  /// нужно ли отправлять сценарии заново.
  bool keepOnly(Iterable<StaffRef> staff) {
    final ids = staff.map((s) => s.id).toSet();
    var changed = false;

    for (final hall in tables.values) {
      for (final entry in hall.values) {
        if (entry.waiter != null && !ids.contains(entry.waiter!.id)) {
          entry.waiter = null;
          changed = true;
        }

        if (entry.admin != null && !ids.contains(entry.admin!.id)) {
          entry.admin = null;
          changed = true;
        }
      }
    }

    return changed;
  }
}

import 'package:lidle/models/block_item.dart';

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

  ScenarioDraft({this.serverId, required this.name, Map<int, List<BlockItemDraft>>? selected})
      : selected = selected ?? {};

  bool get isEmpty => selected.values.every((l) => l.isEmpty);

  ScenarioDraft copy() => ScenarioDraft(
        serverId: serverId,
        name: name,
        selected: {for (final e in selected.entries) e.key: List.of(e.value)},
      );

  /// Убрать ссылки на удалённый экран блока.
  void forget(BlockItemDraft item) {
    for (final list in selected.values) {
      list.remove(item);
    }
  }
}

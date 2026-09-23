import 'package:lidle/models/hall_table.dart';
import 'package:lidle/models/menu_content.dart';

/// Один заполненный экран блока «Добавить …» (22.09.2026), например зал
/// ресторана из «Добавить общий план зала».
///
/// Пока объявление не отправлено, зал живёт только в приложении: его
/// показывают списком в форме, открывают и правят. На сервер залы уходят
/// после объявления, по запросу на каждый (`/adverts/{id}/blocks`), так же
/// как фото объявления.
class BlockItemDraft {
  /// Номер на сервере; null — зал ещё не отправлен.
  int? serverId;

  /// Значения полей в виде, в каком их ждёт сервер:
  /// `{value_selected: [..], values: {id: {value, value_to, max_value}}}`.
  Map<String, dynamic> values;

  /// Файл плана, выбранный на телефоне (ещё не загружен).
  String? localFilePath;

  /// Файл, уже лежащий на сервере.
  String? remoteFileUrl;

  /// `image` или `pdf`.
  String? fileKind;

  /// Строки «Поле: значение» для списка в форме.
  List<MapEntry<String, String>> summary;

  /// Изменён после загрузки с сервера: при отправке нужен запрос.
  bool dirty;

  /// Файл убран при правке.
  bool removeFile;

  /// Столы на плане зала (22.09.2026). У других блоков пусто.
  List<HallTable> layout;

  /// Группы и позиции меню (23.09.2026). У других блоков пусто.
  MenuContent menu;

  BlockItemDraft({
    this.serverId,
    Map<String, dynamic>? values,
    this.localFilePath,
    this.remoteFileUrl,
    this.fileKind,
    List<MapEntry<String, String>>? summary,
    this.dirty = true,
    this.removeFile = false,
    List<HallTable>? layout,
    MenuContent? menu,
  })  : layout = layout ?? [],
        menu = menu ?? MenuContent(),
        values = values ?? {'value_selected': <int>[], 'values': <String, dynamic>{}},
        summary = summary ?? [];

  bool get hasFile => localFilePath != null || remoteFileUrl != null;

  bool get isPdf => fileKind == 'pdf';

  /// Заголовок строки в списке: первое заполненное поле (обычно «Название
  /// зала»).
  String get title => summary.isNotEmpty ? summary.first.value : 'Без названия';

  /// Значение поля по его заголовку из строк summary: «Должность» у
  /// сотрудника (22.09.2026).
  String? summaryValue(String title) {
    for (final e in summary) {
      if (e.key.trim().toLowerCase() == title.toLowerCase()) return e.value;
    }
    return null;
  }

  factory BlockItemDraft.fromServer(Map<String, dynamic> json) {
    final summary = (json['summary'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MapEntry('${e['title'] ?? ''}', '${e['value'] ?? ''}'))
        .toList();

    final values = json['values'] is Map
        ? Map<String, dynamic>.from(json['values'] as Map)
        : <String, dynamic>{};

    return BlockItemDraft(
      serverId: (json['id'] as num?)?.toInt(),
      values: {
        'value_selected': (values['value_selected'] as List? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        'values': values['values'] is Map
            ? Map<String, dynamic>.from(values['values'] as Map)
            : <String, dynamic>{},
      },
      remoteFileUrl: json['file_url']?.toString(),
      fileKind: json['file_kind']?.toString(),
      summary: summary,
      dirty: false,
      layout: [
        if (json['layout'] is List)
          for (final raw in json['layout'] as List)
            if (HallTable.tryParse(raw) != null) HallTable.tryParse(raw)!,
      ],
      menu: MenuContent.fromJson(json['content']),
    );
  }
}

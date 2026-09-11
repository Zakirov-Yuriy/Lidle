// ============================================================
// "Экран: Выбор категории" — направления работы компании
// (макет 11.09.2026).
// ============================================================
//
// Открывается со строки «Направление работы» на экране контактных данных
// компании. Каталоги идут заголовками, под каждым его верхние категории с
// галочками. Отметить можно сколько угодно.
//
// СПИСОК ПРИХОДИТ С СЕРВЕРА вместе с уже отмеченным
// (`GET /me/settings/company/work-directions`). Своего справочника в
// приложении нет намеренно: категории у нас общие для всего проекта, и вторая
// копия разошлась бы с деревом в первую же неделю.
//
// Показываем только ВЕРХНИЕ категории каталога: на макете это один уровень
// под заголовком, а развернуть туда подкатегории значит получить список на
// несколько экранов прокрутки.
//
// Выбор возвращается наружу И по кнопке «Сохранить», И по стрелке назад:
// здесь нет черновика, каждая галочка это уже решение человека, и терять его
// по дороге назад было бы обидно. Сохраняет на сервер тот экран, который
// открыл этот: он же показывает результат.

import 'package:flutter/material.dart';
import 'package:lidle/services/company_contact_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/header.dart';

/// Что экран возвращает: номера отмеченных категорий и их названия.
///
/// Названия нужны сразу: иначе экран компании показал бы номера или пошёл бы
/// за деревом второй раз только ради подписи в строке.
class WorkDirectionChoice {
  const WorkDirectionChoice({required this.ids, required this.names});

  final List<int> ids;
  final List<String> names;
}

class CompanyWorkDirectionScreen extends StatefulWidget {
  const CompanyWorkDirectionScreen({super.key, this.chosen = const []});

  /// Что отмечено сейчас.
  final List<int> chosen;

  @override
  State<CompanyWorkDirectionScreen> createState() =>
      _CompanyWorkDirectionScreenState();
}

class _CompanyWorkDirectionScreenState
    extends State<CompanyWorkDirectionScreen> {
  static const bgColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);

  /// Каталоги с категориями: [{id, name, categories: [{id, name}]}].
  List<Map<String, dynamic>> _groups = [];

  late Set<int> _chosen = {...widget.chosen};

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await CompanyContactService.getWorkDirections(
        token: TokenService.currentToken,
      );

      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};

      final groups = <Map<String, dynamic>>[];

      for (final raw in (data['groups'] as List? ?? const [])) {
        if (raw is! Map) continue;

        final categories = <Map<String, dynamic>>[];

        for (final item in (raw['categories'] as List? ?? const [])) {
          if (item is! Map) continue;

          final id = int.tryParse('${item['id']}');
          final name = '${item['name'] ?? ''}'.trim();

          if (id == null || name.isEmpty) continue;

          categories.add({'id': id, 'name': name});
        }

        if (categories.isEmpty) continue;

        groups.add({
          'name': '${raw['name'] ?? ''}'.trim(),
          'categories': categories,
        });
      }

      if (!mounted) return;

      setState(() {
        _groups = groups;

        // Отмеченное берём с сервера, только если экран открыли без
        // подсказки: иначе затёрли бы то, что человек выбрал минуту назад и
        // ещё не сохранил.
        if (widget.chosen.isEmpty) {
          _chosen = {
            for (final id in (data['chosen'] as List? ?? const []))
              if (int.tryParse('$id') != null) int.parse('$id'),
          };
        }

        _isLoading = false;
      });
    } catch (e) {
      log.d('❌ Не удалось загрузить направления работы: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить список. Потяните вниз, чтобы повторить.';
        _isLoading = false;
      });
    }
  }

  /// Собрать выбор в том порядке, в каком категории идут в справочнике.
  ///
  /// Порядок справочника, а не порядок нажатий: иначе в строке на экране
  /// компании направления каждый раз стояли бы по-новому.
  WorkDirectionChoice _result() {
    final ids = <int>[];
    final names = <String>[];

    for (final group in _groups) {
      for (final category in (group['categories'] as List)) {
        final id = category['id'] as int;

        if (!_chosen.contains(id)) continue;

        ids.add(id);
        names.add(category['name'] as String);
      }
    }

    return WorkDirectionChoice(ids: ids, names: names);
  }

  void _close() => Navigator.pop(context, _result());

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Системная кнопка «назад» должна отдать выбор так же, как стрелка на
      // экране: иначе одно и то же действие двумя путями даёт разный итог.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 20, right: 23),
                child: Row(children: [Header()]),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _close,
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Выбор категории',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _close,
                      child: const Text(
                        'Сохранить',
                        style: TextStyle(color: accentColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: accentColor),
      );
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _isLoading = true;
            _error = null;
          });

          await _load();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 25),
        child: Text(
          'Список направлений пока пуст.',
          style: TextStyle(color: Colors.white54, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _groups.length,
      itemBuilder: (context, index) => _group(_groups[index], index),
    );
  }

  Widget _group(Map<String, dynamic> group, int index) {
    final categories = (group['categories'] as List).cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Черта между каталогами, как на макете. Перед первым не нужна:
        // над ним заголовок экрана.
        if (index > 0)
          const Divider(color: Colors.white12, height: 1, thickness: 1),

        Padding(
          padding: const EdgeInsets.fromLTRB(25, 16, 25, 10),
          child: Text(
            group['name'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        for (final category in categories) _row(category),

        const SizedBox(height: 10),
      ],
    );
  }

  Widget _row(Map<String, dynamic> category) {
    final id = category['id'] as int;
    final checked = _chosen.contains(id);

    void toggle() {
      setState(() {
        if (checked) {
          _chosen.remove(id);
        } else {
          _chosen.add(id);
        }
      });
    }

    return GestureDetector(
      onTap: toggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                category['name'] as String,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            CustomCheckbox(value: checked, onChanged: (_) => toggle()),
          ],
        ),
      ),
    );
  }
}

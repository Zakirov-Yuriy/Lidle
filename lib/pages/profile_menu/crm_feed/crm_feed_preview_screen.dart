// Экран предпросмотра объявлений, загруженных из фида CRM (Topnlab).
// Менеджер попадает сюда сразу после подключения фида: видит объявления
// на модерации со сгенерированным ИИ текстом, может опубликовать или
// отредактировать каждое.
//
// Множественный выбор доступен всегда: на каждой карточке показан чекбокс,
// сверху — панель «Выбрать все», массовая публикация и массовое удаление.
// При этом на каждой карточке остаются и индивидуальные кнопки
// «Опубликовать» / «Редактировать».
//
// Публиковать можно только объявления, которые уже обработал ИИ
// (ai_processed == true). Если среди выбранных есть необработанные —
// показываем предупреждение и просим дождаться завершения ИИ.
//
// Данные берём через тот же эндпоинт, что и вкладка CRM:
//   GET /me/adverts/moderation

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/services/my_adverts_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/models/main_content_model.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/pages/dynamic_filter/dynamic_filter.dart';

class CrmFeedPreviewScreen extends StatefulWidget {
  const CrmFeedPreviewScreen({super.key});

  @override
  State<CrmFeedPreviewScreen> createState() => _CrmFeedPreviewScreenState();
}

class _CrmFeedPreviewScreenState extends State<CrmFeedPreviewScreen> {
  static const Color accentColor = Color(0xFF00B7FF);
  static const Color greenColor = Color(0xFF00D084);
  static const Color redColor = Color(0xFFFF3B30);
  static const Color bgColor = Color(0xFF243241);
  static const Color cardColor = Color(0xFF1F2C3A);

  List<UserAdvert> _listings = [];
  bool _loading = true;

  // Множественный выбор доступен всегда (чекбоксы показаны постоянно).
  final Set<int> _selectedIds = {};
  bool _selectAllChecked = false;
  bool _processing = false;

  // Авто-обновление списка, пока идёт фоновый импорт фида.
  Timer? _pollTimer;
  bool _isFetching = false;

  /// Как часто тихо перепрашивать список.
  static const Duration _pollInterval = Duration(seconds: 5);

  // Индикатор прогресса загрузки из фида.
  int? _feedTotal; // всего офферов в фиде (M), приходит с сервера
  int _prevCount = 0; // сколько было в прошлый опрос — для детекта роста
  int _stableTicks = 0; // сколько опросов подряд число не растёт
  bool _importing = true; // идёт ли ещё загрузка (число растёт)

  @override
  void initState() {
    super.initState();
    _loadListings();
    _loadFeedTotal();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Запустить периодический тихий опрос списка модерации.
  /// Новые объявления из фида появляются на экране сами, без действий юзера.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      // Во время массовой операции не мешаем — обновимся после неё.
      if (_processing) return;
      _fetchAll(silent: true);
      // Пока не узнали общее число офферов — дозапрашиваем (сервер проставляет
      // total_offers в начале импорта, так что появится быстро).
      if (_feedTotal == null) _loadFeedTotal();
    });
  }

  /// Узнать общее число объявлений в фиде (M) для индикатора «N из M».
  /// Суммируем total_offers активных фидов пользователя.
  Future<void> _loadFeedTotal() async {
    try {
      final resp = await ApiService.get('/me/crm-feeds');
      final feeds = (resp['data'] as List?) ?? [];
      int sum = 0;
      bool any = false;
      for (final f in feeds) {
        final bool active = f['is_active'] == true;
        final total = f['total_offers'];
        if (active && total != null) {
          sum += (total as num).toInt();
          any = true;
        }
      }
      if (mounted && any) setState(() => _feedTotal = sum);
    } catch (_) {
      // Молча: индикатор просто покажет «N объявлений» без «из M».
    }
  }

  /// Текст индикатора под заголовком.
  String get _progressText {
    final n = _listings.length;
    final m = _feedTotal;
    if (_importing) {
      return m != null
          ? 'Загрузка объявлений из фида… $n из $m'
          : 'Загрузка объявлений из фида… $n';
    }
    return m != null ? '$n из $m объявлений' : _pluralAdverts(n);
  }

  /// Сколько загруженных объявлений уже обработал ИИ (флаг ai_processed).
  int get _aiProcessedCount =>
      _listings.where((a) => a.aiProcessed == true).length;

  /// Текст индикатора обработки ИИ.
  String get _aiProgressText {
    final n = _aiProcessedCount;
    final m = _feedTotal;
    return m != null ? 'Обработано ИИ: $n из $m' : 'Обработано ИИ: $n';
  }

  /// Русское склонение «объявление/объявления/объявлений».
  String _pluralAdverts(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    String word;
    if (mod100 >= 11 && mod100 <= 14) {
      word = 'объявлений';
    } else if (mod10 == 1) {
      word = 'объявление';
    } else if (mod10 >= 2 && mod10 <= 4) {
      word = 'объявления';
    } else {
      word = 'объявлений';
    }
    return '$n $word';
  }

  /// Обычная загрузка со спиннером (первый вход, pull-to-refresh, после операций).
  Future<void> _loadListings() => _fetchAll(silent: false);

  /// Загрузить ВСЕ объявления, обходя пагинацию бэкенда постранично.
  /// [silent] = true — без спиннера и без сброса состояния (для авто-опроса).
  Future<void> _fetchAll({bool silent = false}) async {
    // Не запускаем параллельные запросы (опрос мог совпасть с ручным refresh).
    if (_isFetching) return;
    _isFetching = true;

    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        if (!silent && mounted) setState(() => _loading = false);
        return;
      }

      if (!silent && mounted) setState(() => _loading = true);

      // per_page ставим большим, чтобы уменьшить число запросов; если сервер
      // ограничивает размер страницы — цикл по meta.last_page догрузит остальное.
      const int pageSize = 100;
      final List<UserAdvert> all = [];
      int page = 1;

      while (true) {
        final response = await MyAdvertsService.getModerationList(
          token: token,
          page: page,
          perPage: pageSize,
        );

        all.addAll(response.data);

        final lastPage = response.lastPage;
        final bool reachedEnd = lastPage != null
            ? page >= lastPage
            : response.data.length < pageSize;

        // Останавливаемся на последней странице, при пустом ответе
        // или по предохранителю (защита от бесконечного цикла).
        if (reachedEnd || response.data.isEmpty || page >= 1000) break;
        page++;
      }

      // Обработанные ИИ поднимаем наверх, чтобы пользователь сразу видел
      // готовые к публикации. Порядок внутри групп сохраняем.
      final processed = all.where((a) => a.aiProcessed == true).toList();
      final rest = all.where((a) => a.aiProcessed != true).toList();
      final ordered = [...processed, ...rest];

      if (mounted) {
        setState(() {
          _listings = ordered;
          _loading = false;

          // Прогресс импорта: пока число растёт — «идёт загрузка».
          // Если два опроса подряд без прироста — считаем, что загрузка завершена.
          if (all.length > _prevCount) {
            _stableTicks = 0;
            _importing = true;
          } else {
            _stableTicks++;
            if (_stableTicks >= 2) _importing = false;
          }
          _prevCount = all.length;

          // Убираем из выбора те, что уже исчезли (опубликованы/удалены).
          final ids = all.map((e) => e.id).toSet();
          _selectedIds.retainWhere(ids.contains);
          if (_selectedIds.isEmpty) _selectAllChecked = false;
        });
      }
    } catch (e) {
      if (!silent && mounted) setState(() => _loading = false);
    } finally {
      _isFetching = false;
    }
  }

  /// Снять текущее выделение (после массовой операции).
  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectAllChecked = false;
    });
  }

  /// Кнопка-«обводка» для диалогов: без фона, цветной бордер и текст.
  Widget _outlinedDialogButton({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Предупреждение: среди выбранных есть объявления, которые ИИ ещё не
  /// обработал. Пользователь может либо отменить, либо всё равно
  /// опубликовать их как есть (с текстом, как загрузилось из фида).
  /// Возвращает true, если пользователь выбрал «Опубликовать».
  Future<bool> _showAiProcessingWarning(bool many) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2732),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                many ? 'Публикация объявлений' : 'Публикация объявления',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Процесс обработки объявления ещё продолжается. '
                'Дождитесь завершение ИИ работы.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _outlinedDialogButton(
                      text: 'Отмена',
                      color: Colors.white54,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _outlinedDialogButton(
                      text: 'Опубликовать',
                      color: greenColor,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  /// Диалог-подтверждение перед публикацией. Возвращает true, если согласен.
  /// Текст меняется для одного объявления / нескольких.
  Future<bool> _confirmPublish(int count) async {
    final bool many = count > 1;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2732),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                many ? 'Публикация объявлений' : 'Публикация объявления',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                many
                    ? 'Эти объявления будут опубликованы в публичном доступе.'
                    : 'Это объявление будет опубликовано в публичном доступе.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _outlinedDialogButton(
                      text: 'Отмена',
                      color: Colors.white54,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _outlinedDialogButton(
                      text: 'Согласен',
                      color: greenColor,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  /// Открыть объявление на редактирование (как кнопка «Редактировать»),
  /// в режиме модерации. После «Обновить» на форме мы вернёмся сюда и
  /// обновим список, чтобы подтянулась зелёная галочка «отредактировано».
  Future<void> _openEditForReview(UserAdvert advert) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DynamicFilter(
          categoryId: 2,
          advertId: advert.id,
          fromModeration: true,
        ),
      ),
    );
    if (mounted) _loadListings();
  }

  /// Предупреждение: в выборе есть объявления, которые ещё не отредактированы.
  /// Публиковать их пачкой нельзя, сначала нужно отредактировать каждое.
  Future<void> _showNeedEditWarning(int count) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2732),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Сначала отредактируйте',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                count > 1
                    ? 'Среди выбранных есть объявления ($count), которые вы ещё '
                        'не отредактировали. Откройте каждое, отредактируйте и '
                        'сохраните, затем публикуйте.'
                    : 'Это объявление нужно сначала отредактировать: откройте '
                        'его, отредактируйте и сохраните, затем публикуйте.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              _outlinedDialogButton(
                text: 'Понятно',
                color: accentColor,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _publish(UserAdvert advert) async {
    // Пока менеджер не отредактировал объявление — «Опубликовать» ведёт на
    // редактирование (и до обработки ИИ, и после). После сохранения правок
    // вернёмся сюда, объявление отметится галочкой, и повторное
    // «Опубликовать» уже публикует по обычной процедуре.
    if (advert.isReviewed != true) {
      await _openEditForReview(advert);
      return;
    }

    if (advert.aiProcessed != true) {
      // ИИ ещё не обработал: предупреждаем, но даём опубликовать как есть
      // (с текстом, как загрузилось из фида). Кнопка «Опубликовать» -> true.
      if (!await _showAiProcessingWarning(false)) return;
    } else if (!await _confirmPublish(1)) {
      return;
    }
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      await MyAdvertsService.publishAdvert(advertId: advert.id, token: token);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Объявление опубликовано'),
            backgroundColor: Colors.green,
          ),
        );
        _loadListings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка публикации: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _publishSelected() async {
    if (_selectedIds.isEmpty) return;

    final selected =
        _listings.where((a) => _selectedIds.contains(a.id)).toList();

    // Пачкой публикуем только отредактированные. Если среди выбранных есть
    // неотредактированные (например, после «Выбрать все») — просим сначала
    // отредактировать их и не публикуем.
    final notReviewed = selected.where((a) => a.isReviewed != true).toList();
    if (notReviewed.isNotEmpty) {
      await _showNeedEditWarning(notReviewed.length);
      return;
    }

    // Если среди выбранных есть необработанные ИИ — предупреждаем, но даём
    // опубликовать как есть (с текстом из фида). Иначе — обычное подтверждение.
    final bool hasUnprocessed = selected.any((a) => a.aiProcessed != true);
    if (hasUnprocessed) {
      if (!await _showAiProcessingWarning(_selectedIds.length > 1)) return;
    } else if (!await _confirmPublish(_selectedIds.length)) {
      return;
    }
    final token = HiveService.getUserData('token') as String?;
    if (token == null) return;

    setState(() => _processing = true);

    int ok = 0;
    int fail = 0;
    final ids = _selectedIds.toList();
    for (final id in ids) {
      try {
        await MyAdvertsService.publishAdvert(advertId: id, token: token);
        ok++;
      } catch (_) {
        fail++;
      }
    }

    if (mounted) {
      setState(() => _processing = false);
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fail == 0
                ? 'Опубликовано: $ok'
                : 'Опубликовано: $ok, с ошибкой: $fail',
          ),
          backgroundColor: fail == 0 ? Colors.green : Colors.orange,
        ),
      );
      _loadListings();
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final token = HiveService.getUserData('token') as String?;
    if (token == null) return;

    setState(() => _processing = true);

    int ok = 0;
    int fail = 0;
    final ids = _selectedIds.toList();
    for (final id in ids) {
      try {
        await MyAdvertsService.deleteAdvert(advertId: id, token: token);
        ok++;
      } catch (_) {
        fail++;
      }
    }

    if (mounted) {
      setState(() => _processing = false);
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fail == 0 ? 'Удалено: $ok' : 'Удалено: $ok, с ошибкой: $fail',
          ),
          backgroundColor: fail == 0 ? Colors.green : Colors.orange,
        ),
      );
      _loadListings();
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2732),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedIds.length > 1
                    ? 'Удалить объявления'
                    : 'Удалить объявление',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedIds.length > 1
                    ? 'Вы уверены, что хотите удалить '
                        'выбранные объявления (${_selectedIds.length})? '
                        'Это действие необратимо.'
                    : 'Вы уверены, что хотите удалить это объявление? '
                        'Это действие необратимо.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _outlinedDialogButton(
                      text: 'Отмена',
                      color: Colors.white54,
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _outlinedDialogButton(
                      text: 'Удалить',
                      color: redColor,
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteSelected();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    final value = price?.toString() ?? '0';
    return '$value руб.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      bottomNavigationBar: const BottomNavigation(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Header(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Объявления из фида',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Индикатор прогресса загрузки из фида («Загрузка… N из M»).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  if (_importing) ...[
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _progressText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Индикатор обработки ИИ («Обработано ИИ: N из M»).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  const Text(
                    'ИИ',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _aiProgressText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Панель массового выбора — показана всегда.
            _selectionBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: accentColor),
                    )
                  : _listings.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          onRefresh: _loadListings,
                          child: ListView.separated(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: bottomNavHeight +
                                  bottomNavPaddingBottom +
                                  36,
                            ),
                            itemCount: _listings.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) => _card(_listings[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          CustomCheckbox(
            value: _selectAllChecked,
            onChanged: (value) {
              setState(() {
                _selectAllChecked = value;
                if (value) {
                  _selectedIds.addAll(_listings.map((l) => l.id));
                } else {
                  _selectedIds.clear();
                }
              });
            },
          ),
          const SizedBox(width: 8),
          const Text(
            'Выбрать все',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (_selectedIds.isNotEmpty && !_processing) ...[
            GestureDetector(
              onTap: _publishSelected,
              child: const Text(
                'Опубликовать',
                style: TextStyle(
                  color: greenColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 1,
              height: 19,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _showDeleteDialog,
              child: const Text(
                'Удалить',
                style: TextStyle(
                  color: redColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (_processing)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accentColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Объявления загружаются',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Загрузка и обработка объявлений из фида '
              'занимает некоторое время. Потяните вниз, '
              'чтобы обновить список.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _loadListings,
            child: const Text(
              'Обновить',
              style: TextStyle(color: accentColor, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(UserAdvert advert) {
    final isSelected = _selectedIds.contains(advert.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected ? Border.all(color: accentColor, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Чекбокс показан всегда.
              CustomCheckbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _selectedIds.add(advert.id);
                    } else {
                      _selectedIds.remove(advert.id);
                    }
                    _selectAllChecked = false;
                  });
                },
              ),
              const SizedBox(width: 12),
              if (advert.thumbnail != null && advert.thumbnail!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    advert.thumbnail!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.white10,
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.white38),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advert.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _formatPrice(advert.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // Пометка «ИИ» для обработанных объявлений.
                        if (advert.aiProcessed == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: accentColor),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Ai',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        // Зелёная галочка: объявление отредактировано менеджером
                        // и готово к публикации. Показываем справа от «ИИ».
                        if (advert.isReviewed == true) ...[
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            'assets/publication_tariff/check.svg',
                            width: 18,
                            height: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      advert.address ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Кнопки на карточке показаны всегда.
          const Divider(color: Colors.white24, height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _publish(advert),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: greenColor, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Опубликовать',
                      style: TextStyle(
                        color: greenColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openEditForReview(advert),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: accentColor, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Редактировать',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
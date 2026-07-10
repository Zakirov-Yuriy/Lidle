// ============================================================
// "Виджет: Экран автовыгрузки через CRM систему"
// ============================================================
//
// Позволяет пользователю подключить фид внешней CRM (Topnlab):
// вставить ссылку на фид и запустить автозагрузку объявлений.
// Импортированные объявления привязываются к текущему пользователю.
//
// API:
// - GET    /me/crm-feeds        — список подключённых фидов
// - POST   /me/crm-feeds        — подключить фид (feed_url)
// - DELETE /me/crm-feeds/{id}   — удалить фид

import 'package:lidle/services/my_adverts_service.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/pages/profile_menu/crm_feed/crm_feed_preview_screen.dart';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lidle/pages/profile_menu/crm_feed/crm_feed_preview_screen.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';

class CrmFeedScreen extends StatefulWidget {
  static const routeName = '/crm_feed';

  const CrmFeedScreen({super.key});

  @override
  State<CrmFeedScreen> createState() => _CrmFeedScreenState();
}

class _CrmFeedScreenState extends State<CrmFeedScreen> {
  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);

  final TextEditingController _urlController = TextEditingController();

  List<dynamic> _feeds = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  /// Если включено — ИИ изменит заголовок и описание импортируемых объявлений.
  /// По умолчанию включено.
  bool _aiRewrite = true;

  @override
  void initState() {
    super.initState();
    _loadFeeds();
    _checkPendingModeration();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Проверка: если у пользователя есть неопубликованные объявления из фида
  /// (на модерации), не даём подключать новый фид — сначала нужно разобрать
  /// текущие. Показываем сообщение и уводим на экран предпросмотра.
  Future<void> _checkPendingModeration() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      final count = await MyAdvertsService.getModerationCount(token: token);

      if (count > 0 && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: cardColor,
            title: const Text(
              'Есть незавершённые объявления',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'У вас есть объявления из фида на модерации ($count). '
              'Сначала опубликуйте или разберите их, '
              'прежде чем подключать новый фид.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Перейти к объявлениям',
                  style: TextStyle(color: Color(0xFF00B7FF)),
                ),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const CrmFeedPreviewScreen(),
            ),
          );
        }
      }
    } catch (e) {
      // При ошибке проверки не блокируем (не мешаем работе).
    }
  }

  /// Загрузить список подключённых фидов.
  Future<void> _loadFeeds() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Токен не передаём — ApiService сам возьмёт актуальный из хранилища
      // и при 401 обновит его и повторит запрос.
      final response = await ApiService.get('/me/crm-feeds');

      setState(() {
        _feeds = (response['data'] as List?) ?? [];
        _isLoading = false;
      });
    } catch (e) {
      log.d('Ошибка загрузки фидов CRM: $e');
      setState(() {
        _error = 'Не удалось загрузить список фидов';
        _isLoading = false;
      });
    }
  }

  /// Показать сообщение о загрузке и перейти на экран предпросмотра
  /// объявлений из фида.
  Future<void> _showLoadingDialogAndGoToPreview() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Фид подключён',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Загрузка и обработка объявлений из фида займёт '
          'некоторое время. Объявления будут появляться '
          'на экране по мере готовности.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Перейти к объявлениям',
              style: TextStyle(color: Color(0xFF00B7FF)),
            ),
          ),
        ],
      ),
    );
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CrmFeedPreviewScreen(),
        ),
      );
    }
  }

  /// Подключить фид по ссылке.
  Future<void> _connectFeed() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnack('Вставьте ссылку на фид');
      return;
    }
    if (!url.startsWith('http')) {
      _showSnack('Ссылка должна начинаться с http');
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      // Токен не передаём — ApiService сам возьмёт актуальный и обновит при 401.
      await ApiService.post(
        '/me/crm-feeds',
        {
          'feed_url': url,
          'is_active': true,
          'archive_missing': true,
          'ai_rewrite': _aiRewrite,
        },
      );

      _urlController.clear();
      await _loadFeeds();
      if (mounted) {
        await _showLoadingDialogAndGoToPreview();
      }
    } catch (e) {
      log.d('Ошибка подключения фида: $e');
      _showSnack('Не удалось подключить фид');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Подключить фид файлом (выбор XML и загрузка через multipart).
  Future<void> _connectFeedFile() async {
    try {
      // Выбор XML-файла фида.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml', 'txt'],
        withData: false,
      );

      if (result == null || result.files.single.path == null) {
        return; // пользователь отменил выбор
      }

      final filePath = result.files.single.path!;

      setState(() => _isSubmitting = true);

      final token = await TokenService.getCurrentToken();
      await ApiService.uploadFile(
        '/me/crm-feeds',
        filePath: filePath,
        fieldName: 'file',
        token: token,
      );

      _showSnack('Фид из файла подключён. Объявления загрузятся автоматически.');
      await _loadFeeds();
    } catch (e) {
      log.d('Ошибка загрузки файла фида: $e');
      _showSnack('Не удалось загрузить файл');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Удалить фид.
  Future<void> _deleteFeed(dynamic id) async {
    try {
      await ApiService.delete('/me/crm-feeds/$id');
      _showSnack('Фид удалён');
      await _loadFeeds();
    } catch (e) {
      log.d('Ошибка удаления фида: $e');
      _showSnack('Не удалось удалить фид');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── Header ─────
              const Padding(
                padding: EdgeInsets.only(bottom: 20, right: 23),
                child: Row(children: [Header()]),
              ),

              // ───── Кнопка назад ─────
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 10),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left,
                          color: activeIconColor, size: 26),
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
              ),

              // ───── Заголовок ─────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 8),
                child: Text(
                  'Автовыгрузка через CRM систему',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              // ───── Описание ─────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 4),
                child: Text(
                  'Вставьте ссылку на фид вашей CRM системы. '
                  'Объявления будут загружаться и обновляться автоматически.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),

              // ───── Поле ввода ссылки ─────
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 20, 25, 0),
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: activeIconColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: activeIconColor),
                    ),
                  ),
                ),
              ),

              // ───── Кнопка запуска ─────
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 14, 25, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _connectFeed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeIconColor,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Подключить и запустить',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),

              // ───── Разделитель «или» ─────
              const Padding(
                padding: EdgeInsets.fromLTRB(25, 16, 25, 0),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('или',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
              ),

              // ───── Кнопка загрузки файлом ─────
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 14, 25, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _connectFeedFile,
                    icon: Icon(Icons.attach_file,
                        color: activeIconColor, size: 20),
                    label: Text(
                      'Загрузить файлом (XML)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: activeIconColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: activeIconColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

              // ───── Список подключённых фидов ─────
              const Padding(
                padding: EdgeInsets.fromLTRB(25, 28, 25, 8),
                child: Text(
                  'Подключённые фиды',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(25),
                  child: Center(
                    child: CircularProgressIndicator(color: activeIconColor),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              else if (_feeds.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  child: Text(
                    'Пока нет подключённых фидов',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                ..._feeds.map((feed) => _feedCard(feed)).toList(),

              // ───── Переключатель: ИИ меняет заголовок и описание ─────
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 20, 25, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ИИ изменит заголовок и описание вашего объявления',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _AiRewriteSwitch(
                      value: _aiRewrite,
                      activeIconColor: activeIconColor,
                      onChanged: (v) => setState(() => _aiRewrite = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  /// Карточка одного фида.
  Widget _feedCard(dynamic feed) {
    final id = feed['id'];
    final url = feed['feed_url'] ?? feed['feed_file'] ?? '';
    final isActive = feed['is_active'] == true;
    final lastStatus = feed['last_status'];
    final lastSynced = feed['last_synced_at'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.pause_circle_filled,
                color: isActive ? Colors.greenAccent : Colors.orangeAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  url.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              GestureDetector(
                onTap: () => _confirmDelete(id),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),
          if (lastStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              lastStatus.toString(),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          if (lastSynced != null) ...[
            const SizedBox(height: 4),
            Text(
              'Обновлено: $lastSynced',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(dynamic id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Удалить фид?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Объявления, загруженные из этого фида, останутся. '
          'Новых обновлений не будет.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteFeed(id);
            },
            child: const Text('Удалить',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

/// Кастомный переключатель (тумблер) в стиле проекта.
///
/// Дизайн полностью повторяет чекбокс из общих компонентов:
/// капсула 37×20 с цветом 0xFF17212B и «пустой» круглой ручкой,
/// обводка которой окрашивается в [activeIconColor], когда включено.
class _AiRewriteSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeIconColor;

  const _AiRewriteSwitch({
    required this.value,
    required this.onChanged,
    required this.activeIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 37,
        height: 20,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF17212B),
          borderRadius: BorderRadius.circular(30),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: value ? activeIconColor : Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
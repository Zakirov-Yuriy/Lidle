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
// Данные берём через тот же эндпоинт, что и вкладка CRM:
//   GET /me/adverts/moderation

import 'package:flutter/material.dart';
import 'package:lidle/services/my_adverts_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (mounted) setState(() => _loading = true);

      final response = await MyAdvertsService.getModerationList(token: token);

      if (mounted) {
        setState(() {
          _listings = response.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Снять текущее выделение (после массовой операции).
  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectAllChecked = false;
    });
  }

  Future<void> _publish(UserAdvert advert) async {
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
              const Text(
                'Удалить объявления',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Вы уверены, что хотите удалить '
                'выбранные объявления (${_selectedIds.length})? '
                'Это действие необратимо.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Отмена',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteSelected();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: redColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Удалить',
                          style: TextStyle(
                            color: Colors.white,
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
                    Text(
                      _formatPrice(advert.price),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DynamicFilter(
                          categoryId: 2,
                          advertId: advert.id,
                        ),
                      ),
                    );
                  },
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
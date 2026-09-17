// ============================================================
//  "Жалоба на товар"
// ============================================================
//
// Сделано 17.09.2026 вместе с блоком жалобы в карточке товара.
//
// Повторяет диалог жалобы на объявление по виду и по порядку действий: это
// одно и то же действие в глазах человека, и два разных окна для него были бы
// двумя разными привычками на ровном месте. Отличий два: причины приходят для
// товаров, и уходит жалоба на товар.
//
// Причины приходят с сервера, а не лежат списком здесь: их правит
// администратор, и захардкоженный список однажды разойдётся с тем, что
// разбирают в админке.

import 'package:flutter/material.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';

class ReportProductDialog extends StatefulWidget {
  final int productId;

  const ReportProductDialog({super.key, required this.productId});

  @override
  State<ReportProductDialog> createState() => _ReportProductDialogState();
}

class _ReportProductDialogState extends State<ReportProductDialog> {
  List<Map<String, dynamic>> _reasons = const [];
  int? _selected;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ApiService.getReportReasons(type: 'products');

      final reasons = rows
          .map((row) => {
                'id': row['id'],
                'name': '${row['title'] ?? row['name'] ?? ''}'.trim(),
              })
          .where((row) => row['id'] != null && '${row['name']}'.isNotEmpty)
          .toList();

      if (!mounted) return;

      setState(() {
        _reasons = reasons;
        _loading = false;
      });
    } catch (e) {
      log.d('Причины жалоб на товар не загрузились: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить причины жалоб';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selected == null || _sending) return;

    setState(() => _sending = true);

    try {
      await ApiService.reportProduct(
        productId: widget.productId,
        reportId: _selected!,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жалоба отправлена')),
      );
    } catch (e) {
      log.d('Жалоба на товар не отправилась: $e');

      if (!mounted) return;

      setState(() => _sending = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить жалобу')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _selected != null && !_sending;

    return Dialog(
      backgroundColor: primaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 8, 25, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Text(
              'Пожаловаться',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 13),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(activeIconColor),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              )
            else if (_reasons.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Причины жалоб пока не заведены',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              )
            else
              ..._reasons.map((reason) {
                final id = reason['id'] as int?;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${reason['name']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      CustomCheckbox(
                        value: _selected == id,
                        // Причина одна: жалоба на «неверную цену и чужие
                        // фотографии разом» это две разные жалобы, и разбирать
                        // их админке тоже придётся по отдельности.
                        onChanged: (value) => setState(
                          () => _selected = value == true ? id : null,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      inherit: false,
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                      decorationThickness: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 21),
                OutlinedButton(
                  onPressed: canSend ? _submit : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: canSend ? activeIconColor : Colors.white24,
                      width: 1.4,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Отправить',
                          style: TextStyle(
                            color: canSend ? activeIconColor : Colors.white24,
                            fontSize: 16,
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

// ============================================================
//  "Диалог жалобы на отзыв"
//  Причины тянутся с сервера (GET /content/reports?type=...),
//  отправка — на соответствующий эндпоинт:
//   - отзыв объявления: POST /reviews/{id}/report
//   - отзыв компании:   POST /companies/{companyId}/reviews/{id}/report
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';

/// На какой отзыв жалуемся: на отзыв к объявлению или на отзыв о компании.
enum ReviewComplaintTarget { advert, company }

class ReviewComplaintDialog extends StatefulWidget {
  /// Id отзыва.
  final int reviewId;

  /// Тип отзыва (объявление/компания).
  final ReviewComplaintTarget target;

  /// Id компании (обязателен для жалобы на отзыв о компании).
  final int? companyId;

  const ReviewComplaintDialog({
    super.key,
    required this.reviewId,
    this.target = ReviewComplaintTarget.advert,
    this.companyId,
  });

  @override
  State<ReviewComplaintDialog> createState() => _ReviewComplaintDialogState();
}

class _ReviewComplaintDialogState extends State<ReviewComplaintDialog> {
  List<Map<String, dynamic>> reportTypes = [];
  int? selectedReportId;
  bool isLoading = true;
  bool _submitting = false;
  String? errorMessage;

  String get _reasonsType => widget.target == ReviewComplaintTarget.company
      ? 'company_review'
      : 'advert_review';

  @override
  void initState() {
    super.initState();
    _loadReportTypes();
  }

  /// Причины жалоб на отзыв с сервера. Сервер отдаёт {id, title}.
  Future<void> _loadReportTypes() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      final reasons = await ApiService.getReportReasons(type: _reasonsType);
      final types = reasons
          .map((e) => {
                'id': e['id'],
                'name': (e['title'] ?? e['name'] ?? '').toString(),
              })
          .where((e) => e['id'] != null)
          .toList();
      if (!mounted) return;
      setState(() {
        reportTypes = types;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Не удалось загрузить причины жалоб';
        isLoading = false;
      });
      log.d('❌ Ошибка загрузки причин жалоб на отзыв: $e');
    }
  }

  Future<void> _submitReport() async {
    if (selectedReportId == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      if (widget.target == ReviewComplaintTarget.company) {
        final companyId = widget.companyId;
        if (companyId == null) {
          throw Exception('Не указана компания');
        }
        await ApiService.reportCompanyReview(
          companyId: companyId,
          reviewId: widget.reviewId,
          reportId: selectedReportId!,
        );
      } else {
        await ApiService.reportAdvertReview(
          reviewId: widget.reviewId,
          reportId: selectedReportId!,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жалоба успешно отправлена')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить жалобу')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: primaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.only(
          top: 25.0,
          left: 25.0,
          right: 25.0,
          bottom: 47.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Пожаловаться',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF00B7FF)),
                ),
              )
            else if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              )
            else if (reportTypes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Нет доступных причин жалоб',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              )
            else
              ...List.generate(reportTypes.length, (index) {
                final reportType = reportTypes[index];
                final reportId = reportType['id'] as int?;
                final reportName =
                    reportType['name'] as String? ?? 'Неизвестная причина';
                final isSelected = selectedReportId == reportId;
                return _buildCheckboxRow(
                  reportName,
                  isSelected,
                  (bool? value) {
                    setState(() {
                      selectedReportId = value == true ? reportId : null;
                    });
                  },
                );
              }),
            const SizedBox(height: 34),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
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
                  onPressed: (selectedReportId != null && !_submitting)
                      ? _submitReport
                      : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: selectedReportId != null
                          ? activeIconColor
                          : Colors.white24,
                      width: 1.4,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Отправить',
                          style: TextStyle(
                            color: selectedReportId != null
                                ? activeIconColor
                                : Colors.white24,
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

  Widget _buildCheckboxRow(
    String title,
    bool isChecked,
    ValueChanged<bool?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          CustomCheckbox(value: isChecked, onChanged: onChanged),
        ],
      ),
    );
  }
}

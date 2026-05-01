import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';

class ReportUserDialog extends StatefulWidget {
  final int userId;
  final String userName;

  const ReportUserDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  List<Map<String, dynamic>> reportTypes = [];
  int? selectedReportId;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReportTypes();
  }

  /// Загружает доступные типы жалоб на пользователей
  Future<void> _loadReportTypes() async {
    try {
      setState(() => isLoading = true);
      // Локальные типы жалоб с предопределённым списком
      final types = [
        {'id': 1, 'name': 'Некорректная информация'},
        {'id': 2, 'name': 'Оскорбления'},
        {'id': 3, 'name': 'Спам'},
        {'id': 4, 'name': 'Ссылки на странные ресурсы'},
      ];
      if (mounted) {
        setState(() {
          reportTypes = types;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Ошибка загрузки типов жалоб: $e';
          isLoading = false;
        });
      }
      log.d('❌ Ошибка загрузки типов жалоб: $e');
    }
  }

  /// Отправляет жалобу на пользователя
  Future<void> _submitReport() async {
    if (selectedReportId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите причину жалобы')),
      );
      return;
    }

    try {
      await ApiService.reportUser(
        userId: widget.userId,
        reportId: selectedReportId!,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жалоба успешно отправлена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
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
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    "Пожаловаться",
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF00B7FF),
                  ),
                ),
              )
            else if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              )
            else if (reportTypes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Нет доступных типов жалоб',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              )
            else
              ...List.generate(
                reportTypes.length,
                (index) {
                  final reportType = reportTypes[index];
                  final reportId = reportType['id'] as int?;
                  final reportName = reportType['name'] as String? ?? 'Неизвестная причина';
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
                },
              ),
            const SizedBox(height: 34),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: const Text(
                    "Отмена",
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
                  onPressed: selectedReportId != null ? _submitReport : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: selectedReportId != null ? activeIconColor : Colors.white24,
                      width: 1.4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "Отправить",
                    style: TextStyle(
                      color: selectedReportId != null ? activeIconColor : Colors.white24,
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

  /// Создаёт строку с чекбоксом и текстом причины жалобы
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
          CustomCheckbox(
            value: isChecked,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

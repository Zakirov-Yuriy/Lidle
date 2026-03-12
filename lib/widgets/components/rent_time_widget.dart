// ============================================================
//  "Виджет выбора времени и даты для аренды"
// ============================================================

import 'package:flutter/material.dart';
import '../../constants.dart';

class RentTimeWidget extends StatelessWidget {
  final String? dateFrom;
  final String? timeFrom;
  final String? dateTo;
  final String? timeTo;
  final VoidCallback? onEditFrom;
  final VoidCallback? onEditTo;

  const RentTimeWidget({
    super.key,
    this.dateFrom,
    this.timeFrom,
    this.dateTo,
    this.timeTo,
    this.onEditFrom,
    this.onEditTo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const Text(
          //   'Время и дата аренды',
          //   style: TextStyle(
          //     color: textSecondary,
          //     fontSize: 14,
          //   ),
          // ),
          // const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onEditFrom,
                  child: _TimeColumn(
                    label: 'От',
                    date: dateFrom ?? 'Выбрать дату',
                    time: timeFrom ?? '00:00',
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: GestureDetector(
                  onTap: onEditTo,
                  child: _TimeColumn(
                    label: 'До',
                    date: dateTo ?? 'Выбрать дату',
                    time: timeTo ?? '00:00',
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

class _TimeColumn extends StatelessWidget {
  final String label;
  final String date;
  final String time;

  const _TimeColumn({
    required this.label,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                date,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 1,
                color: Colors.white24,
              ),
              // const SizedBox(height: 6),
              Text(
                time,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

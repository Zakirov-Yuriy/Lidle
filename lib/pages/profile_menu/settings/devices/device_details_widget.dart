// ============================================================
// "Виджет: Подробная информация об устройстве"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/services/device_info_service.dart';
import 'dart:io';

class DeviceDetailsWidget extends StatefulWidget {
  final VoidCallback? onClose;

  const DeviceDetailsWidget({Key? key, this.onClose}) : super(key: key);

  @override
  State<DeviceDetailsWidget> createState() => _DeviceDetailsWidgetState();
}

class _DeviceDetailsWidgetState extends State<DeviceDetailsWidget> {
  late Future<DeviceInfo> _deviceInfoFuture;

  @override
  void initState() {
    super.initState();
    _deviceInfoFuture = DeviceInfoService.getDeviceInfo();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceInfo>(
      future: _deviceInfoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00B7FF)),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'Не удалось загрузить информацию об устройстве',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final deviceInfo = snapshot.data!;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Информация об устройстве',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.onClose != null)
                      GestureDetector(
                        onTap: widget.onClose,
                        child: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Имя устройства
                _buildInfoItem(
                  label: 'Имя устройства',
                  value: deviceInfo.getFullName(),
                ),
                const SizedBox(height: 12),

                // Модель
                if (deviceInfo.model.isNotEmpty)
                  _buildInfoItem(
                    label: 'Модель',
                    value: deviceInfo.model,
                  ),
                if (deviceInfo.model.isNotEmpty)
                  const SizedBox(height: 12),

                // Производитель
                if (deviceInfo.manufacturer.isNotEmpty)
                  _buildInfoItem(
                    label: 'Производитель',
                    value: deviceInfo.manufacturer,
                  ),
                if (deviceInfo.manufacturer.isNotEmpty)
                  const SizedBox(height: 12),

                // Версия ОС
                _buildInfoItem(
                  label: 'Версия ОС',
                  value: deviceInfo.osVersion,
                ),
                const SizedBox(height: 12),

                // Версия сборки (для Android)
                if (deviceInfo.buildVersion != null &&
                    deviceInfo.buildVersion!.isNotEmpty)
                  _buildInfoItem(
                    label: 'Версия сборки',
                    value: deviceInfo.buildVersion!,
                  ),
                if (deviceInfo.buildVersion != null &&
                    deviceInfo.buildVersion!.isNotEmpty)
                  const SizedBox(height: 12),

                // Версия приложения
                _buildInfoItem(
                  label: 'Версия приложения',
                  value: deviceInfo.appVersion,
                ),
                const SizedBox(height: 12),

                // Платформа
                _buildInfoItem(
                  label: 'Платформа',
                  value: deviceInfo.platform,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

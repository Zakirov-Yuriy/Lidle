// ============================================================
// "Виджет: Экран управления устройствами"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/devices/devices_bloc.dart';
import 'package:lidle/blocs/devices/devices_event.dart';
import 'package:lidle/blocs/devices/devices_state.dart';
import 'package:lidle/models/device_model.dart';
import 'package:lidle/services/device_info_service.dart';
import 'package:lidle/hive_service.dart';
import 'device_details_widget.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const dangerColor = Color(0xFFFF3B30);
  static const textSecondary = Colors.white54;

  @override
  void initState() {
    super.initState();
    // Загружаем список устройств при открытии экрана
    context.read<DevicesBloc>().add(const LoadDevicesEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───── Header ─────
             Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 23),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [const Header()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Color.fromARGB(255, 255, 255, 255),
                      size: 16,
                    ),
                  ),
                  const Text(
                    'Устройства',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                 
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ───── Description ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Вы можете зайти в приложение ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    TextSpan(
                      children: getAppTitleSpans(),
                    ),
                    const TextSpan(
                      text: ' с помощью QR-кода.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ───── Connect device button ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 47,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/qr_scanner');
                  },
                  child: const Text(
                    'Подключить устройства',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 47),

            // ───── BLoC Consumer для отображения устройств ─────
            Expanded(
              child: BlocConsumer<DevicesBloc, DevicesState>(
                listener: (context, state) {
                  // Показываем сообщения об ошибках
                  if (state is DevicesError) {
                    _showErrorSnackbar(context, state.message);
                  } else if (state is DeviceRemoved) {
                    _showSuccessSnackbar(context, state.message);
                  } else if (state is DeviceRemoveError) {
                    _showErrorSnackbar(context, state.message);
                  } else if (state is AllOtherSessionsRemoved) {
                    _showSuccessSnackbar(
                      context,
                      'Все другие сеансы завершены',
                    );
                  } else if (state is RemoveAllOtherSessionsError) {
                    _showErrorSnackbar(context, state.message);
                  }
                },
                builder: (context, state) {
                  if (state is DevicesLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: accentColor),
                    );
                  }

                  if (state is DevicesEmpty) {
                    return Center(
                      child: Text(
                        'Нет активных устройств',
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  if (state is DevicesError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: dangerColor,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                            ),
                            onPressed: () {
                              context.read<DevicesBloc>().add(
                                const LoadDevicesEvent(forceRefresh: true),
                              );
                            },
                            child: const Text('Попробовать снова'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is DevicesLoaded) {
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ───── This device ─────
                            if (state.currentDevice != null) ...[
                              const Text(
                                'Это устройство',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Divider(color: Colors.white24),
                              GestureDetector(
                                onTap: () => _showDeviceDetailsModal(context),
                                child: _buildDeviceItem(
                                  device: state.currentDevice!,
                                  isCurrentDevice: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Маленькая информация о клике
                              // GestureDetector(
                              //   onTap: () => _showDeviceDetailsModal(context),
                              //   child: Padding(
                              //     padding: const EdgeInsets.symmetric(
                              //       horizontal: 25,
                              //     ),
                              //     child: Row(
                              //       mainAxisAlignment:
                              //           MainAxisAlignment.spaceBetween,
                              //       children: const [
                              //         Text(
                              //           'Подробнее',
                              //           style: TextStyle(
                              //             color: Color(0xFF00B7FF),
                              //             fontSize: 14,
                              //             fontWeight: FontWeight.w400,
                              //           ),
                              //         ),
                              //         Icon(
                              //           Icons.arrow_forward_ios,
                              //           color: Color(0xFF00B7FF),
                              //           size: 14,
                              //         ),
                              //       ],
                              //     ),
                              //   ),
                              // ),
                              const SizedBox(height: 24),
                            ],

                            // ───── Active sessions ─────
                            if (state.activeSessions.isNotEmpty) ...[
                              const Text(
                                'Активные сеансы',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...state.activeSessions.map(
                                (device) => _buildDeviceItem(device: device),
                              ),
                              const SizedBox(height: 24),

                              // ───── End sessions button ─────
                              GestureDetector(
                                onTap: () => _showConfirmDialog(context),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.cancel_outlined,
                                      color: dangerColor,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Завершить все другие сеансы',
                                      style: TextStyle(
                                        color: dangerColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Построить элемент устройства с возможностью удаления
  Widget _buildDeviceItem({
    required DeviceModel device,
    bool isCurrentDevice = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Для текущего устройства показываем реальное имя
                    Text(
                      isCurrentDevice
                          ? _getCurrentDeviceName()
                          : device.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCurrentDevice
                          ? _getCurrentDeviceInfo(device)
                          : _formatDeviceInfo(device),
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCurrentDevice)
                GestureDetector(
                  onTap: () => _showDeleteConfirmDialog(context, device),
                  child: const Icon(
                    Icons.close,
                    color: textSecondary,
                    size: 20,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Получить реальное имя текущего устройства
  String _getCurrentDeviceName() {
    final cachedInfo = DeviceInfoService.getCachedDeviceInfo();
    if (cachedInfo != null) {
      return cachedInfo.getFullName();
    }
    
    if (Platform.isIOS) {
      return 'iPhone (Это устройство)';
    } else if (Platform.isAndroid) {
      return 'Android Device (Это устройство)';
    } else {
      return 'This Device';
    }
  }

  /// Форматировать информацию текущего устройства
  String _getCurrentDeviceInfo(DeviceModel device) {
    final platform = Platform.isIOS ? 'iOS' : (Platform.isAndroid ? 'Android' : 'Web');
    final osVersion = Platform.operatingSystemVersion.split(' ').first;
    return '$platform • ${device.appVersion} • В сети';
  }

  /// Форматировать информацию об устройстве (для других устройств)
  static String _formatDeviceInfo(DeviceModel device) {
    // Конвертируем тип устройства из API формата в понятный
    String platformDisplay = _convertDeviceType(device.deviceType);

    // Добавляем информацию о локации и статусе
    String info = '';
    
    // Локация (если доступна)
    if (device.country != null && device.country!.isNotEmpty) {
      info += '${device.country}';
    }
    
    // Добавляем платформу и версию
    info += info.isNotEmpty ? ' • $platformDisplay • ${device.appVersion}' : '$platformDisplay • ${device.appVersion}';
    
    // Статус "в сети" (если было использовано недавно)
    if (device.lastUsedAt.year == DateTime.now().year) {
      info += ' • в сети';
    }

    return info;
  }

  /// Конвертировать тип устройства из API в понятный вид
  static String _convertDeviceType(String apiDeviceType) {
    switch (apiDeviceType.toLowerCase()) {
      case 'ios':
        return 'iOS';
      case 'android':
        return 'Android';
      case 'web':
        return 'Web';
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      default:
        return apiDeviceType;
    }
  }

  /// Форматировать дату в читаемый формат
  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} д назад';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  /// Показать диалог подтверждения удаления одного устройства
  void _showDeleteConfirmDialog(BuildContext context, DeviceModel device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C3A),
        title: const Text(
          'Удалить устройство?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Вы уверены, что хотите удалить ${device.name}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: accentColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DevicesBloc>().add(RemoveDeviceEvent(device.id));
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: dangerColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Показать диалог подтверждения удаления всех других сеансов
  void _showConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C3A),
        title: const Text(
          'Завершить все другие сеансы?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Все активные сеансы на других устройствах будут закрыты. '
          'Вы останетесь в сети только на этом устройстве.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: accentColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context
                  .read<DevicesBloc>()
                  .add(const RemoveAllOtherDevicesEvent());
            },
            child: const Text(
              'Завершить',
              style: TextStyle(color: dangerColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Показать модальное окно с подробной информацией об устройстве
  void _showDeviceDetailsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF243241),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => DeviceDetailsWidget(
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  /// Показать snackbar с сообщением об ошибке
  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: dangerColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Показать snackbar с сообщением об успехе
  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}


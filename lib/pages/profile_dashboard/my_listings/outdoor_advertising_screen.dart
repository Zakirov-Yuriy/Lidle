import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:lidle/core/config/app_config.dart';

class OutdoorAdvertisingScreen extends StatefulWidget {
  static const routeName = '/outdoor-advertising';

  const OutdoorAdvertisingScreen({super.key});

  @override
  State<OutdoorAdvertisingScreen> createState() =>
      _OutdoorAdvertisingScreenState();
}

class _OutdoorAdvertisingScreenState extends State<OutdoorAdvertisingScreen> {
  static const accentColor = Color(0xFF00B7FF);

  /// Перезагружает данные экрана при восстановлении подключения
  void _reloadScreenData() {
    // Экран не требует загрузки данных - это статический UI
    // При необходимости добавить API запросы, добавить их сюда
    if (mounted) {
      setState(() {
        // UI перестроится автоматически
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        if (connectivityState is ConnectedState) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _reloadScreenData();
            }
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(onRetry: () {
              context.read<ConnectivityBloc>().add(const CheckConnectivityEvent());
            });
          }
          return Scaffold(
            backgroundColor: primaryBackground,
            body: SafeArea(
              child: Column(
                children: [
                  // ───── Header ─────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 21, right: 23),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Header(),
                        Padding(
                          padding: const EdgeInsets.only(top: 19.0),
                          child: GestureDetector(
                            onTap: () => Share.share(
                              'Присоединяйся к LIDLE! 🚀\n\n'
                              'Удобный маркетплейс для покупки и продажи автомобилей, недвижимости и товаров.\n\n'
                              'Скачай приложение и получи эксклюзивные предложения!\n\n'
                              '${AppConfig().websiteUrl}',
                            ),
                            child: SvgPicture.asset(
                              'assets/home_page/share_outlined.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ───── Title ─────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        // const SizedBox(width: 8),
                        const Text(
                          'Наружная реклама',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Назад',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ───── Description ─────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Text(
                      'Вы можете оставить рекламу вашего объявления на сторонах ресурсов',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ───── Content ─────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...List.generate(
                            1,
                            (index) {
                              final isFirstItem = index == 0;
                              final imageAsset = isFirstItem
                                  ? 'assets/home_page/click.png'
                                  : 'assets/home_page/ozon.png';
                              final linkUrl = 'https://click.ru/ref/6ea890b0a61974fe';
                              final displayText = isFirstItem ? 'Click.ru' : 'Ссылка';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        imageAsset,
                                        width: 45,
                                        height: 45,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: isFirstItem
                                          ? InkWell(
                                              onTap: () async {
                                                try {
                                                  final uri = Uri.parse(linkUrl);
                                                  await launchUrl(
                                                    uri,
                                                    mode: LaunchMode.externalApplication,
                                                  );
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Не удалось открыть ссылку')),
                                                    );
                                                  }
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(13),
                                                decoration: BoxDecoration(
                                                  color: formBackground,
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      displayText,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.all(13),
                                              decoration: BoxDecoration(
                                                color: formBackground,
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    displayText,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // ───── Publish Button ─────
                  // Padding(
                  //   padding: const EdgeInsets.symmetric(horizontal: 25),
                  //   child: SizedBox(
                  //     height: 48,
                  //     width: double.infinity,
                  //     child: ElevatedButton(
                  //       style: ElevatedButton.styleFrom(
                  //         backgroundColor: accentColor,
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(8),
                  //         ),
                  //       ),
                  //       onPressed: () {
                  //         ScaffoldMessenger.of(context).showSnackBar(
                  //           const SnackBar(content: Text('Реклама опубликована')),
                  //         );
                  //       },
                  //       child: const Text(
                  //         'Опубликовать',
                  //         style: TextStyle(
                  //           color: Colors.white,
                  //           fontSize: 16,
                  //           fontWeight: FontWeight.w600,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

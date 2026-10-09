import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/response_model.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/core/logger.dart';

class UserAccountPage extends StatefulWidget {
  final ResponseModel response;

  const UserAccountPage({super.key, required this.response});

  @override
  State<UserAccountPage> createState() => _UserAccountPageState();
}

class _UserAccountPageState extends State<UserAccountPage> {
  /// Настоящие данные человека (09.10.2026, задача 15).
  ///
  /// В самом отклике их нет и быть не должно: список откликов не место для
  /// телефонов и адресов. Поэтому профиль спрашиваем отдельно, той же
  /// ручкой, что и экран аккаунта в предложениях цены.
  ///
  /// Пока ответ не пришёл, экран показывает то, что известно из отклика:
  /// имя и аватарку. Это лучше, чем крутилка на весь экран.
  Map<String, dynamic> _profile = const {};

  double? _rating;
  String? _city;
  String? _nickname;
  List<String> _phones = const [];
  List<String> _telegrams = const [];
  List<String> _whatsapps = const [];
  List<String> _maxes = const [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final id = int.tryParse('${widget.response.userId ?? ''}');
    final token = TokenService.currentToken;

    if (id == null || token == null) {
      return;
    }

    try {
      final profile = await ApiService.getUserProfile(userId: id, token: token);

      if (!mounted || profile.isEmpty) {
        return;
      }

      List<String> pick(dynamic list, String key) {
        if (list is! List) return const [];

        return list
            .whereType<Map>()
            .map((item) => '${item[key] ?? ''}'.trim())
            .where((value) => value.isNotEmpty)
            .toList();
      }

      final contacts = profile['contacts'] as Map<String, dynamic>?;
      final address = profile['address'] as Map<String, dynamic>?;
      final city = address?['city'] as Map<String, dynamic>?;
      final nick = '${profile['nickname'] ?? ''}'.trim();
      final rating = profile['rating'];

      var phones = pick(contacts?['phones'], 'phone');

      // Только два последних номера, как на экране предложений цены
      // (решение заказчика 09.10.2026): у давних пользователей их
      // накапливается с десяток, и карточка превращается в простыню.
      if (phones.length > 2) {
        phones = phones.sublist(phones.length - 2);
      }

      setState(() {
        _profile = profile;
        _rating = rating is num ? rating.toDouble() : null;
        _city = '${city?['name'] ?? ''}'.trim().isEmpty
            ? null
            : '${city!['name']}'.trim();
        _nickname = nick.isEmpty ? null : (nick.startsWith('@') ? nick : '@$nick');
        _phones = phones;
        _telegrams = pick(contacts?['telegrams'], 'username');
        _whatsapps = pick(contacts?['whatsapps'], 'number');
        _maxes = pick(contacts?['maxes'], 'username');
      });
    } catch (e) {
      log.d('Не удалось загрузить профиль откликнувшегося: $e');
    }
  }

  /// Аватарка из сети, а нет её — общая заглушка приложения.
  ///
  /// Прежде здесь стоял безусловный `AssetImage` от пути, которого у
  /// настоящих данных не бывает: получался пустой фиолетовый круг.
  Widget _avatar() {
    final url = widget.response.avatarUrl ?? '${_profile['avatar'] ?? ''}';

    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF374B5C),
      ),
      child: ClipOval(
        child: url.startsWith('http')
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => SvgPicture.asset(
                  'assets/profile_dashboard/default-photo.svg',
                  fit: BoxFit.cover,
                ),
              )
            : SvgPicture.asset(
                'assets/profile_dashboard/default-photo.svg',
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  bool _spamChecked = false;
  bool _incorrectDataChecked = false;
  bool _inappropriateLanguageChecked = false;
  bool _strangeResourcesChecked = false;

  static const backgroundColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── Header ─────
              Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 23),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [const Header(), const Spacer()],
                ),
              ),

              // ───── Title ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      // Нажатие на всю строку, а не только на стрелку: попасть пальцем
                      // в иконку шириной 16 точек трудно, а заголовок рядом читается
                      // как часть той же кнопки «назад».
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Аккаунт пользователя',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(color: accentColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ───── User Info Card ─────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 25),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _avatar(),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.response.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_nickname != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _nickname!,
                                  style: const TextStyle(
                                    color: accentColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              // Оценка показывается ТОЛЬКО когда она есть.
                              // Пять пустых звёзд читаются как «плохой
                              // исполнитель», а не как «его ещё никто не
                              // оценивал».
                              if (_rating != null) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Рейтинг',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  children: [
                                    ...List.generate(5, (index) {
                                      return Icon(
                                        index < _rating!.floor()
                                            ? Icons.star
                                            : index < _rating!
                                                ? Icons.star_half
                                                : Icons.star_border,
                                        color: Colors.orange,
                                        size: 18,
                                      );
                                    }),
                                    const SizedBox(width: 6),
                                    Text(
                                      _rating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Контакты человека (09.10.2026). Берутся из его
                    // профиля, а не из отклика: в отклике их нет и быть не
                    // должно. Чего у человека не указано, то и не
                    // показываем, пустых строк на экране не остаётся.
                    if (_phones.isNotEmpty) ...[
                      const Text(
                        'Номер',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ..._phones.map(
                        (phone) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            phone,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_telegrams.isNotEmpty) ...[
                      const Text(
                        'Телеграм',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      ..._telegrams.map(
                        (value) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: accentColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_whatsapps.isNotEmpty) ...[
                      const Text(
                        'WhatsApp',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      ..._whatsapps.map(
                        (value) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: accentColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_maxes.isNotEmpty) ...[
                      const Text(
                        'MAX',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      ..._maxes.map(
                        (value) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: accentColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Divider
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 16),

                    // City
                    const Text(
                      'Город',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _city ?? widget.response.city ?? 'Не указан',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ───── Complaint Card ─────
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 25),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Оставить жалобу на исполнителя',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'Вы можете оставить жалобу на\nисполнителя в случаи нарушения\nим ',
                          ),
                          TextSpan(
                            text: 'правил',
                            style: const TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        _showComplaintDialog(context);
                      },
                      child: const Text(
                        'Пожаловаться',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        onItemSelected: (index) {
          if (index == 3) {
            context.read<NavigationBloc>().add(NavigateToMyPurchasesEvent());
          } else {
            context.read<NavigationBloc>().add(
              SelectNavigationIndexEvent(index),
            );
          }
        },
      ),
    );
  }

  void _showComplaintDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: primaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),

                    // Title
                    const Text(
                      'Оставить жалобу\nна исполнителя',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Checkboxes
                    _buildCheckboxRow('Спам', _spamChecked, (value) {
                      setStateDialog(() {
                        _spamChecked = value ?? false;
                      });
                      setState(() {
                        _spamChecked = value ?? false;
                      });
                    }),
                    _buildCheckboxRow(
                      'Не корректные данные',
                      _incorrectDataChecked,
                      (value) {
                        setStateDialog(() {
                          _incorrectDataChecked = value ?? false;
                        });
                        setState(() {
                          _incorrectDataChecked = value ?? false;
                        });
                      },
                    ),
                    _buildCheckboxRow(
                      'Не цензурная лексика\nв объявлении',
                      _inappropriateLanguageChecked,
                      (value) {
                        setStateDialog(() {
                          _inappropriateLanguageChecked = value ?? false;
                        });
                        setState(() {
                          _inappropriateLanguageChecked = value ?? false;
                        });
                      },
                    ),
                    _buildCheckboxRow(
                      'Ссылки на странные\nресурсы',
                      _strangeResourcesChecked,
                      (value) {
                        setStateDialog(() {
                          _strangeResourcesChecked = value ?? false;
                        });
                        setState(() {
                          _strangeResourcesChecked = value ?? false;
                        });
                      },
                    ),

                    const SizedBox(height: 28),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Отмена',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: accentColor,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            'Отправить',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
          CustomCheckbox(value: isChecked, onChanged: onChanged),
        ],
      ),
    );
  }
}

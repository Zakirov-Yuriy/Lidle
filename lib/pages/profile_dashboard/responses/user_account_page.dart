import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/response_model.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';

class UserAccountPage extends StatefulWidget {
  final ResponseModel response;

  const UserAccountPage({super.key, required this.response});

  @override
  State<UserAccountPage> createState() => _UserAccountPageState();
}

class _UserAccountPageState extends State<UserAccountPage> {
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
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 16,
                      ),
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
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: AssetImage(
                            widget.response.userAvatar,
                          ),
                        ),
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
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Рейтинг',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              Row(
                                children: List.generate(5, (index) {
                                  return Icon(
                                    index < widget.response.rating.floor()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.orange,
                                    size: 18,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Phone numbers
                    if (widget.response.phoneNumbers != null) ...[
                      const Text(
                        'Номер',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ...widget.response.phoneNumbers!.map(
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

                    // Telegram
                    if (widget.response.telegram != null) ...[
                      const Text(
                        'Телеграмм',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.response.telegram!,
                        style: const TextStyle(
                          color: accentColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // WhatsApp
                    if (widget.response.whatsapp != null) ...[
                      const Text(
                        'WhatsApp',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.response.whatsapp!,
                        style: const TextStyle(
                          color: accentColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // VK
                    if (widget.response.vk != null) ...[
                      const Text(
                        'VK',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.response.vk!,
                        style: const TextStyle(
                          color: accentColor,
                          fontSize: 16,
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
                      widget.response.city ?? 'Не указан',
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

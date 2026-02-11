import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/response_model.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/pages/profile_dashboard/responses/user_account_page.dart';

class AcceptResponsePage extends StatefulWidget {
  final ResponseModel response;
  final String? status;
  final VoidCallback? onArchive;

  const AcceptResponsePage({
    super.key,
    required this.response,
    this.status,
    this.onArchive,
  });

  @override
  State<AcceptResponsePage> createState() => _AcceptResponsePageState();
}

class _AcceptResponsePageState extends State<AcceptResponsePage> {
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
                      'Принять заявку',
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

              // ───── Message text ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: const Text(
                  'Вы приняли сделку с исполнителем',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),

              const SizedBox(height: 16),

              // ───── Executor Info Card ─────
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
                    // User info header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: AssetImage(
                            widget.response.userAvatar,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.response.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
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
                                    color: Colors.amber,
                                    size: 16,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Кнопка сообщение
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: Реализовать функцию отправки сообщения
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: accentColor,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Написать',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ───── Package info sections ─────
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
                    // Pickup location
                    _buildInfoSection(
                      'Откуда забрать посылку',
                      widget.response.category,
                      '${widget.response.city ?? ""}',
                      showMapButton: true,
                    ),

                    const SizedBox(height: 20),

                    // Delivery location
                    _buildInfoSection(
                      'Куда доставить посылку',
                      '${widget.response.city ?? ""}, д. 1, кв. 33',
                      '',
                      showMapButton: true,
                    ),

                    const SizedBox(height: 20),

                    // Elevator available
                    _buildInfoItem('Лифт на месте доставки', 'Да'),

                    const SizedBox(height: 12),

                    // Package category
                    _buildInfoItem(
                      'Категория посылки',
                      widget.response.category,
                    ),

                    const SizedBox(height: 12),

                    // Weight
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Вес посылки ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: '(грамм.)',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '500 г.',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Payment
                    _buildInfoItem('Оплата посылки', 'Оплачена'),
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
                          fontSize: 16,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 127),
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

  Widget _buildInfoSection(
    String title,
    String location,
    String address, {
    bool showMapButton = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          location,
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            address,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
        if (showMapButton) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      UserAccountPage(response: widget.response),
                ),
              );
            },
            child: const Text(
              'Показать карту',
              style: TextStyle(
                color: accentColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ],
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

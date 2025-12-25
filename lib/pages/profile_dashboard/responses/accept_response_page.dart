import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/response_model.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';

class AcceptResponsePage extends StatefulWidget {
  final ResponseModel response;
  final String? status;
  final VoidCallback? onArchive;

  const AcceptResponsePage({super.key, required this.response, this.status, this.onArchive});

  @override
  State<AcceptResponsePage> createState() => _AcceptResponsePageState();
}

class _AcceptResponsePageState extends State<AcceptResponsePage> {
  bool _spamChecked = false;
  bool _incorrectDataChecked = false;
  bool _inappropriateLanguageChecked = false;
  bool _strangeResourcesChecked = false;
  int _selectedRating = 0;

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

              // ───── Back / Cancel ─────
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
                    Text(
                      widget.status == 'Выполянется' ? 'Завершение работы' : 'Принять заявку',
                      style: const TextStyle(
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  'Вы хотите принять сделку с исполнителем',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),

              const SizedBox(height: 16),

              // ───── User Info Card ─────
              if (widget.status == 'Выполянется') ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.response.category,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          if (widget.status != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              widget.status!,
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.response.title}: ${widget.response.price.toInt()} ₽ за услугу',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: AssetImage(widget.response.userAvatar),
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
                                          : index < widget.response.rating
                                              ? Icons.star_half
                                              : Icons.star_border,
                                      color: Colors.orange,
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
                      const Divider(color: Color(0xFF474747), height: 8),
                      const SizedBox(height: 7),
                      const Text(
                        'Оставить оценку',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onPanUpdate: (details) {
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final localPosition = box.globalToLocal(details.globalPosition);
                          final starWidth = 32.0; // icon size + padding
                          final tappedIndex = (localPosition.dx / starWidth).floor();
                          if (tappedIndex >= 0 && tappedIndex < 5) {
                            setState(() {
                              _selectedRating = tappedIndex + 1;
                            });
                          }
                        },
                        child: Row(
                          children: List.generate(5, (index) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedRating = index + 1;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 0.0),
                                child: Icon(
                                  Icons.star,
                                  color: index < _selectedRating ? Colors.orange : Colors.grey,
                                  size: 24,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // TODO: Implement delete functionality
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text(
                                'Удалить',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                widget.onArchive?.call();
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF00B7FF)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text(
                                'Добавить в архив',
                                style: TextStyle(color: Color(0xFF00B7FF)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 25),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundImage: AssetImage(widget.response.userAvatar),
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
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),
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
              ],

              const SizedBox(height: 16),

              // ───── Complaint Card ─────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 25),
                padding: const EdgeInsets.all(20),
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
                          fontSize: 14,
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'Вы можете оставить жалобу на \nисполнителя в случаи нарушения \nим ',
                          ),
                          TextSpan(
                            text: 'правил',
                            style: const TextStyle(color: accentColor),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
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
                                              "Оставить жалобу\nна исполнителя",
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
                                      _buildCheckboxRow("Спам", _spamChecked, (bool? value) {
                                        setState(() {
                                          _spamChecked = value ?? false;
                                        });
                                      }),
                                      _buildCheckboxRow("Не корректные данные", _incorrectDataChecked, (
                                        bool? value,
                                      ) {
                                        setState(() {
                                          _incorrectDataChecked = value ?? false;
                                        });
                                      }),
                                      _buildCheckboxRow(
                                        "Не цензурная лексика\nв объявлении",
                                        _inappropriateLanguageChecked,
                                        (bool? value) {
                                          setState(() {
                                            _inappropriateLanguageChecked = value ?? false;
                                          });
                                        },
                                      ),
                                      _buildCheckboxRow(
                                        "Ссылки на странные ресурсы",
                                        _strangeResourcesChecked,
                                        (bool? value) {
                                          setState(() {
                                            _strangeResourcesChecked = value ?? false;
                                          });
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
                                              splashFactory:
                                                  NoSplash.splashFactory,
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
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: activeIconColor, width: 1.4),
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
                                                color: activeIconColor,
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
                            },
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Пожаловаться',
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 142),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        onItemSelected: (index) {
          if (index == 3) {
            context.read<NavigationBloc>().add(NavigateToMyPurchasesEvent());
          } else {
            context.read<NavigationBloc>().add(SelectNavigationIndexEvent(index));
          }
        },
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
          CustomCheckbox(
            value: isChecked,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

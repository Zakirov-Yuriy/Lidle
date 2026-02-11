import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/models/response_model.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/pages/profile_dashboard/responses/user_account_page.dart';

class CompletionDealPage extends StatefulWidget {
  final ResponseModel response;
  final VoidCallback? onArchive;

  const CompletionDealPage({super.key, required this.response, this.onArchive});

  @override
  State<CompletionDealPage> createState() => _CompletionDealPageState();
}

class _CompletionDealPageState extends State<CompletionDealPage> {
  bool _selectAllChecked = false;
  bool _archiveChecked = false;
  int _userRating = 0;
  bool _cardDeleted = false;
  bool _cardArchived = false;
  bool _spamChecked = false;
  bool _incorrectDataChecked = false;
  bool _inappropriateLanguageChecked = false;
  bool _strangeResourcesChecked = false;
  bool _isSelectionMode = false;

  static const backgroundColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile ||
            state is NavigationToHome ||
            state is NavigationToFavorites ||
            state is NavigationToAddListing ||
            state is NavigationToMyPurchases ||
            state is NavigationToMessages ||
            state is NavigationToSignIn) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: Scaffold(
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
                        'Завершение сделки',
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
                    'Вы завершили сделку с исполнителем',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 16),

                // ───── Select all section ─────
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Row(
                      children: [
                        CustomCheckbox(
                          value: _selectAllChecked,
                          onChanged: (value) {
                            setState(() {
                              _selectAllChecked = value;
                              _archiveChecked = value;
                              if (!value) {
                                _isSelectionMode = false;
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Выбрать все',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            if (_archiveChecked) {
                              setState(() {
                                _cardArchived = true;
                              });
                              widget.onArchive?.call();
                            }
                          },
                          child: const Text(
                            'В архив',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 1,
                          height: 19,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            if (_archiveChecked) {
                              setState(() {
                                _cardDeleted = true;
                              });
                            }
                          },
                          child: const Text(
                            'Удалить',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_isSelectionMode) const SizedBox(height: 16),

                // ───── Deal Info Card ─────
                if (!_cardDeleted && !_cardArchived) ...[
                  GestureDetector(
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                          _archiveChecked = true;
                        });
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 25),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: formBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category with checkbox
                          Row(
                            children: [
                              if (_isSelectionMode)
                                CustomCheckbox(
                                  value: _archiveChecked,
                                  onChanged: (value) {
                                    setState(() {
                                      _archiveChecked = value;
                                      if (!value) {
                                        _isSelectionMode = false;
                                      }
                                    });
                                  },
                                ),
                              if (_isSelectionMode) const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.response.category,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Выполнено',
                                style: TextStyle(
                                  color: Color(0xFF19D849),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Deal title and price
                          Text(
                            '${widget.response.title}: ${widget.response.price.toInt()} ₽ за услугу',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Executor info
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => UserAccountPage(
                                        response: widget.response,
                                      ),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 32,
                                  backgroundImage: AssetImage(
                                    widget.response.userAvatar,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                UserAccountPage(
                                                  response: widget.response,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        widget.response.userName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
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

                          const Divider(color: Color(0xFF474747), height: 11),

                          // ───── Rating Section ─────
                          const Text(
                            'Оставить оценку',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _userRating = index + 1;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  child: Icon(
                                    _userRating > index
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: const Color.fromARGB(
                                      255,
                                      204,
                                      204,
                                      203,
                                    ),
                                    size: 24,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ───── Complaint Section ─────
                if (!_cardDeleted && !_cardArchived) ...[
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
                ],

                const SizedBox(height: 80), // Space for bottom nav
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
              backgroundColor: const Color(0xFF243241),
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

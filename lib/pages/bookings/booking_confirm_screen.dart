import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Экран подтверждения записи: показывает выбранное время, спрашивает имя,
/// телефон и комментарий, отправляет бронь.
///
/// Возвращает через Navigator.pop:
///   true  — бронь создана, календарь в карточке надо перечитать;
///   false — время заняли, пока человек заполнял форму (409), календарь тоже
///           надо перечитать, но экран мы закрываем, чтобы человек выбрал
///           другое время из свежих данных;
///   null  — просто ушли назад, ничего не изменилось.
class BookingConfirmScreen extends StatefulWidget {
  final int advertId;
  final String advertTitle;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool needsConfirmation;
  final int? maxGuests;

  const BookingConfirmScreen({
    super.key,
    required this.advertId,
    required this.advertTitle,
    required this.startsAt,
    required this.endsAt,
    required this.needsConfirmation,
    this.maxGuests,
  });

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();

  int _guests = 1;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  /// Имя и телефон подставляем из профиля: человек уже вошёл, спрашивать его
  /// же данные заново невежливо. Поля остаются редактируемыми, записаться
  /// можно и не на себя.
  Future<void> _prefillFromProfile() async {
    try {
      final token = await TokenService.getCurrentToken();
      if (token == null || token.isEmpty) return;

      final profile = await UserService.getProfile(token: token);
      if (!mounted) return;

      setState(() {
        if (_nameController.text.isEmpty) {
          _nameController.text = profile.name;
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = profile.phone ?? '';
        }
      });
    } catch (_) {
      // Профиль не обязателен: поля просто останутся пустыми.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSending) return;

    setState(() => _isSending = true);

    final result = await BookingsService.create(
      advertId: widget.advertId,
      startsAt: widget.startsAt,
      endsAt: widget.endsAt,
      guestsCount: widget.maxGuests == null ? null : _guests,
      comment: _commentController.text,
      contactName: _nameController.text,
      contactPhone: _phoneController.text,
    );

    if (!mounted) return;

    setState(() => _isSending = false);

    switch (result.kind) {
      case BookingResultKind.created:
        SnackBarHelper.showSuccess(
          context,
          result.needsOwnerAnswer
              ? 'Заявка отправлена, ждём ответа владельца'
              : 'Время забронировано',
        );
        Navigator.pop(context, true);
        break;

      case BookingResultKind.conflict:
        // Не вина человека: пока он заполнял форму, время заняли. Уводим
        // назад к свежему календарю вместо того, чтобы держать его на форме
        // с уже невозможным временем.
        SnackBarHelper.showWarning(
          context,
          'Это время только что заняли. Выберите другое, календарь обновлён.',
        );
        Navigator.pop(context, false);
        break;

      case BookingResultKind.rejected:
        SnackBarHelper.showError(context, result.message);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios, color: activeIconColor, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Назад',
                      style: TextStyle(
                        color: activeIconColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Подтверждение записи',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Как к вам обращаться',
                    controller: _nameController,
                    hint: 'Имя',
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Телефон для связи',
                    controller: _phoneController,
                    hint: '+7',
                    keyboardType: TextInputType.phone,
                  ),
                  if (widget.maxGuests != null) ...[
                    const SizedBox(height: 12),
                    _buildGuestsPicker(),
                  ],
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Комментарий, необязательно',
                    controller: _commentController,
                    hint: 'Что важно знать заранее',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                  const SizedBox(height: 12),
                  Text(
                    widget.needsConfirmation
                        ? 'Владелец подтвердит запись. Пока он не ответил, время держится за вами.'
                        : 'Время закрепится за вами сразу после отправки.',
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.advertTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.event, color: activeIconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                _humanDate(widget.startsAt),
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, color: activeIconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                '${_time(widget.startsAt)} — ${_time(widget.endsAt)}',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textMuted, fontSize: 15),
            filled: true,
            fillColor: formBackground,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestsPicker() {
    final maxGuests = widget.maxGuests ?? 1;

    return Row(
      children: [
        const Text(
          'Гостей',
          style: TextStyle(color: textSecondary, fontSize: 13),
        ),
        const Spacer(),
        IconButton(
          onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
          icon: const Icon(Icons.remove_circle_outline, color: activeIconColor),
        ),
        Text(
          '$_guests',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          onPressed:
              _guests < maxGuests ? () => setState(() => _guests++) : null,
          icon: const Icon(Icons.add_circle_outline, color: activeIconColor),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: activeIconColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _isSending ? null : _submit,
        child: _isSending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.needsConfirmation ? 'Отправить заявку' : 'Забронировать',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  String _time(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _humanDate(DateTime date) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${date.day} ${months[(date.month - 1).clamp(0, 11)]}';
  }
}

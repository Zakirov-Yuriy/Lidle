// ============================================================
//  Диалог «Откликнуться» (09.10.2026, задача 15)
// ============================================================
//
// Сделан по образцу диалога предложения цены, но поля поменялись местами по
// смыслу: у предложения главное сумма, а у отклика сообщение. Человек
// откликается на вакансию или разовую задачу, и автору объявления важно
// прочитать, кто это и когда готов выйти, а не увидеть одну цифру.
//
// Цена здесь НЕОБЯЗАТЕЛЬНА: в вакансии её называет работодатель, а в разовой
// задаче исполнитель вполне может предложить свою.
//
// Отдельно писать в переписку не нужно: сервер сам заводит сообщение автору
// с этим же текстом и плашкой объявления в шапке.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';

class ResponseDialog extends StatefulWidget {
  final int advertId;
  final String advertTitle;

  const ResponseDialog({
    super.key,
    required this.advertId,
    this.advertTitle = '',
  });

  @override
  State<ResponseDialog> createState() => _ResponseDialogState();
}

class _ResponseDialogState extends State<ResponseDialog> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _messageController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = TokenService.currentToken;

    if (token == null || token.isEmpty) {
      setState(() => _errorMessage = 'Требуется авторизация');

      return;
    }

    final message = _messageController.text.trim();

    // Те же границы, что на сервере: от 5 до 500 знаков. Проверяем здесь,
    // чтобы человек увидел подсказку сразу, а не после запроса.
    if (message.length < 5) {
      setState(() => _errorMessage = 'Напишите хотя бы пару слов о себе');

      return;
    }

    double? price;
    final priceText = _priceController.text.trim().replaceAll(',', '.');

    if (priceText.isNotEmpty) {
      price = double.tryParse(priceText);

      if (price == null || price <= 0) {
        setState(() => _errorMessage = 'Цена указана неверно');

        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.submitResponse(
        advertId: widget.advertId,
        message: message,
        price: price,
      );

      if (!mounted) {
        return;
      }

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Отклик отправлен, сообщение ушло автору'),
            backgroundColor: Colors.green,
          ),
        );

        // Возвращаем true: карточка по этому ответу гасит кнопку, второй
        // отклик на то же объявление сервер не примет.
        Navigator.of(context).pop(true);

        return;
      }

      setState(() {
        _errorMessage = response['message']?.toString() ?? 'Не удалось отправить отклик';
      });
    } catch (e) {
      final text = e.toString();

      setState(() {
        _errorMessage = text.contains('авторизация') || text.contains('401')
            ? 'Требуется авторизация'
            : 'Ошибка: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9 > 500 ? 500.0 : screenWidth * 0.9;

    return Dialog(
      backgroundColor: primaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.only(
          top: 10.0,
          left: 16.0,
          right: 16.0,
          bottom: 20.0,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              ),
              const Center(
                child: Text(
                  'Откликнуться',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.advertTitle.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.advertTitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 13),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ваше сообщение',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              _buildInputField(
                controller: _messageController,
                hintText: 'Расскажите о себе и когда готовы начать',
                maxLines: 5,
                maxLength: 500,
              ),
              const SizedBox(height: 9),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ваша цена, если хотите назвать',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              _buildInputField(
                controller: _priceController,
                hintText: 'Необязательно',
                keyboardType: TextInputType.number,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Отправить',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isLoading,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: formBackground,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        counterStyle: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      buildCounter: maxLength != null
          ? (context, {required currentLength, required isFocused, maxLength}) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Символов осталось: $currentLength / $maxLength',
                  style: TextStyle(
                    color: currentLength > maxLength! * 0.8
                        ? Colors.orange
                        : Colors.white54,
                    fontSize: 12,
                  ),
                ),
              );
            }
          : null,
    );
  }
}

// ============================================================
//  "Диалог предложения цены"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';

class OfferPriceDialog extends StatefulWidget {
  final int advertId;
  final String advertSlug;

  const OfferPriceDialog({
    super.key,
    required this.advertId,
    required this.advertSlug,
  });

  @override
  State<OfferPriceDialog> createState() => _OfferPriceDialogState();
}

class _OfferPriceDialogState extends State<OfferPriceDialog> {
  late TextEditingController _priceController;
  late TextEditingController _messageController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Отправить предложение цены на сервер
  Future<void> _submitOffer() async {
    // ✅ Проверяем авторизацию перед отправкой
    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'Требуется авторизация';
      });
      return;
    }

    if (_priceController.text.isEmpty || _messageController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Заполните все поля';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final price = double.parse(_priceController.text);

      // 💰 Отправляем предложение через API
      final response = await ApiService.submitPriceOffer(
        advertId: widget.advertId,
        price: price,
        message: _messageController.text,
      );

      if (mounted) {
        if (response['success'] == true) {
          // ✅ Успешно отправлено
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Предложение отправлено продавцу'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          // ❌ Ошибка от сервера
          setState(() {
            _errorMessage =
                response['message'] ?? 'Ошибка при отправке предложения';
          });
        }
      }
    } on FormatException {
      setState(() {
        _errorMessage = 'Введите корректную цену';
      });
    } catch (e) {
      // Проверяем если ошибка о авторизации
      final errorText = e.toString();
      if (errorText.contains('авторизация') || errorText.contains('401') || errorText.contains('Unauthorized')) {
        setState(() {
          _errorMessage = 'Требуется авторизация';
        });
      } else {
        setState(() {
          _errorMessage = 'Ошибка: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Предложить свою цену",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Text(
                    "Ваша цена",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              _buildInputField(
                controller: _priceController,
                hintText: "Сумма в рублях",
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 9),
              Flexible(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Почему вы предлагаете другую цену?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              _buildInputField(
                controller: _messageController,
                hintText: "Сообщение продавцу",
                maxLines: 5,
                maxLength: 100,
              ),
              // Вывод ошибки, если есть
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
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitOffer,
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          "Отправить",
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

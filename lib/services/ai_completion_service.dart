// Глобальный наблюдатель за завершением ИИ-обработки объявлений из фида.
//
// Пока пользователь залогинен, тихо опрашивает лёгкий эндпоинт
//   GET /me/adverts/moderation-ai-status  ->  { total, processed, all_done }
// и, как только обработка переходит из «идёт» в «всё готово» (all_done
// становится true), показывает оповещение поверх ЛЮБОГО экрана через
// глобальный navigatorKey. Кнопка «Опубликовать» ведёт на экран
// предпросмотра объявлений из фида.
//
// Запускается/останавливается из main.dart в BlocListener<AuthBloc>:
//   AiCompletionService.instance.start();  // при AuthAuthenticated
//   AiCompletionService.instance.stop();   // при логауте / истечении токена

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lidle/main.dart' show navigatorKey;
import 'package:lidle/services/api_service.dart';
import 'package:lidle/pages/profile_menu/crm_feed/crm_feed_preview_screen.dart';

class AiCompletionService {
  AiCompletionService._();
  static final AiCompletionService instance = AiCompletionService._();

  static const Color _bgColor = Color(0xFF1E2732);
  static const Color _greenColor = Color(0xFF00D084);

  /// Как часто опрашивать статус (запрос лёгкий, это просто счётчики).
  static const Duration _interval = Duration(seconds: 20);

  Timer? _timer;

  /// Было ли на прошлом опросе «всё готово». Стартуем с true, чтобы НЕ
  /// сработать на первом же чтении, если у пользователя и так всё обработано.
  /// Оповещение показываем только на ПЕРЕХОДЕ false -> true.
  bool _wasAllDone = true;

  /// Открыт ли сейчас наш диалог (чтобы не открывать поверх себя же).
  bool _dialogOpen = false;

  /// Запустить наблюдение (вызывать при авторизации).
  void start() {
    _timer?.cancel();
    _wasAllDone = true;
    _dialogOpen = false;
    _timer = Timer.periodic(_interval, (_) => _check());
  }

  /// Остановить наблюдение (вызывать при логауте / истечении токена).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    try {
      final resp =
          await ApiService.get('/me/adverts/moderation-ai-status');

      final int total = (resp['total'] as num?)?.toInt() ?? 0;
      final bool allDone = resp['all_done'] == true;

      // Нет объявлений на модерации — не трогаем пользователя.
      // Держим _wasAllDone = true, чтобы при появлении новой партии и её
      // последующем завершении оповещение сработало.
      if (total == 0) {
        _wasAllDone = true;
        return;
      }

      // Переход «идёт обработка» -> «всё готово»: показываем оповещение раз.
      if (allDone && !_wasAllDone) {
        _showCompletionDialog();
      }
      _wasAllDone = allDone;
    } catch (_) {
      // Молча: сеть/401/таймаут — не мешаем пользователю, попробуем снова.
    }
  }

  void _showCompletionDialog() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || _dialogOpen) return;
    _dialogOpen = true;

    showDialog<void>(
      context: ctx,
      builder: (dctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Обработка ИИ завершена',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ИИ завершил обработку всех ваших объявлений. '
                'Зайдите и опубликуйте их.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _dialogButton(
                      text: 'Отмена',
                      color: Colors.white54,
                      onTap: () => Navigator.pop(dctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dialogButton(
                      text: 'Опубликовать',
                      color: _greenColor,
                      onTap: () {
                        Navigator.pop(dctx);
                        navigatorKey.currentState?.push(
                          MaterialPageRoute(
                            builder: (_) => const CrmFeedPreviewScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) => _dialogOpen = false);
  }

  Widget _dialogButton({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

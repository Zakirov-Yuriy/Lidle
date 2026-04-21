// ============================================================
// "Менеджер кеша экранов"
// ============================================================
// Централизованное хранилище кешированных значений для экранов
// профиля. Вынесено из виджетов, чтобы AuthBloc мог сбрасывать
// кеш при logout без импорта UI-слоя.
// ============================================================

class ScreenCacheManager {
  // ── ProfileMenuScreen ──────────────────────────────────────
  static DateTime? profileMenuLastLoadTime;
  static DateTime? profileMenuLastPhoneLoadTime;
  static String? profileMenuCachedPhone;

  // ── SettingsScreen ─────────────────────────────────────────
  static DateTime? settingsLastLoadTime;

  // ── ContactDataScreen ──────────────────────────────────────
  static DateTime? contactDataLastLoadTime;

  // ── Общий сброс (вызывается при logout) ───────────────────
  /// Сбрасывает все кеши экранов профиля.
  /// Вызывается из AuthBloc при LogoutEvent и TokenExpiredEvent.
  static void clearAll() {
    profileMenuLastLoadTime = null;
    profileMenuLastPhoneLoadTime = null;
    profileMenuCachedPhone = null;
    settingsLastLoadTime = null;
    contactDataLastLoadTime = null;
  }
}

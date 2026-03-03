/// Централизованное хранилище всех ключей кеша приложения.
///
/// Используйте эти константы везде, где нужно обратиться к кешу.
/// Это предотвращает опечатки и позволяет легко найти все точки
/// инвалидации при изменении данных.
///
/// Соглашение по именованию:
///   - Статические данные: `feature_entity`       (например, `listings_data`)
///   - Данные с ID:        `feature_entity_{id}`  (используйте методы-билдеры)
///   - Профиль / сессия:  `profile_*`
abstract final class CacheKeys {
  // ─────────────────────────────────────────────
  // Объявления
  // ─────────────────────────────────────────────

  /// Ключ общего списка объявлений (все каталоги, страницы 1–3).
  static const String listingsData = 'listings_data';

  /// Ключ для отдельного объявления. Используйте [advertKey].
  static const String _advertPrefix = 'advert_';

  /// Строит ключ кеша для одного объявления по его ID.
  static String advertKey(String advertId) => '$_advertPrefix$advertId';

  /// Префикс для массовой инвалидации всех объявлений.
  static const String advertsPrefix = _advertPrefix;

  // ─────────────────────────────────────────────
  // Профиль
  // ─────────────────────────────────────────────

  /// Ключ данных профиля текущего пользователя.
  static const String profileData = 'profile_data';

  /// Ключ счётчиков (активные / архив / черновики) в профиле.
  static const String profileListingsCounts = 'profile_listings_counts';

  /// Ключ счётчика предложений цен в профиле.
  static const String profilePriceOffersCount = 'profile_price_offers_count';

  // ─────────────────────────────────────────────
  // Сообщения
  // ─────────────────────────────────────────────

  /// Ключ сообщений пользователя (личные).
  static const String messagesData = 'messages_data';

  /// Ключ сообщений компании.
  static const String companyMessagesData = 'company_messages_data';

  // ─────────────────────────────────────────────
  // Каталог / категории
  // ─────────────────────────────────────────────

  /// Ключ списка категорий/каталогов.
  static const String catalogsData = 'catalogs_data';

  // ─────────────────────────────────────────────
  // Профиль продавца
  // ─────────────────────────────────────────────

  /// Строит ключ кеша профиля продавца по его ID.
  static String sellerProfileKey(String sellerId) => 'seller_profile_$sellerId';

  /// Префикс для массовой инвалидации профилей продавцов.
  static const String sellerProfilePrefix = 'seller_profile_';
}

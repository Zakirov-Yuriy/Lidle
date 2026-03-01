import 'package:lidle/models/home_models.dart';
import 'dart:convert';

class Advert {
  final int id;
  final String date;
  final String name;
  final String price;
  final String? thumbnail;
  final List<String> images;
  final AdvertStatus status;
  final String address;
  final int viewsCount;
  final int clickCount;
  final int shareCount;
  final AdvertType type;
  final String? sellerName;
  final String? sellerAvatar;
  final String? sellerRegistrationDate;

  /// ID продавца (из поля user.id детального ответа)
  final String? sellerId;
  final String? description;

  final Map<String, dynamic>? characteristics;

  Advert({
    required this.id,
    required this.date,
    required this.name,
    required this.price,
    this.thumbnail,
    this.images = const [],
    required this.status,
    required this.address,
    required this.viewsCount,
    required this.clickCount,
    required this.shareCount,
    required this.type,
    this.sellerName,
    this.sellerAvatar,
    this.sellerRegistrationDate,
    this.sellerId,
    this.description,
    this.characteristics,
  });

  factory Advert.fromJson(Map<String, dynamic> json) {
    // print('Advert ${json['id']} images in JSON: ${json['images']}');

    // Парсим информацию о продавце из поля 'user' или 'seller'
    String? sellerName;
    String? sellerAvatar;
    String? sellerRegistrationDate;

    // Также берём id продавца из user.id детального ответа
    String? sellerId;

    if (json['user'] != null) {
      final user = json['user'] as Map<String, dynamic>;
      sellerName = user['name'] as String?;
      sellerAvatar = user['avatar'] as String?;
      sellerRegistrationDate = user['created_at'] as String?;
      sellerId = user['id']?.toString();
    }

    // Безопасный парсинг изображений
    final imagess = <String>[];
    if (json['images'] != null && json['images'] is List) {
      try {
        imagess.addAll(
          (json['images'] as List<dynamic>)
              .whereType<String>()
              .where((img) => img.isNotEmpty)
              .toList(),
        );
      } catch (e) {
        // print('Error parsing images for advert ${json['id']}: $e');
      }
    }

    // Парсим характеристики из attributes
    // 🟢 ВАЖНО: attributes могут быть двух форматов:
    // 1. List - когда API возвращает attributes как массив (старый формат)
    // 2. Map с 'value_selected' и 'values' ключами (новый структурированный формат)
    Map<String, dynamic>? characteristics;

    // DEBUG: Логирование структуры JSON
    print('📊 DEBUG Advert.fromJson for ID=${json['id']}:');
    print('   Available fields: ${json.keys.toList()}');
    print('   Has attributes? ${json.containsKey('attributes')}');
    if (json.containsKey('attributes')) {
      print('   attributes type: ${json['attributes'].runtimeType}');
      if (json['attributes'] is Map) {
        print(
          '   attributes[Map] keys: ${(json['attributes'] as Map).keys.toList()}',
        );
      } else if (json['attributes'] is List) {
        print(
          '   attributes[List] length: ${(json['attributes'] as List).length}',
        );
      }
    }

    if (json['attributes'] != null) {
      characteristics = {};

      if (json['attributes'] is List) {
        // Формат 1: List атрибутов
        final attrs = json['attributes'] as List<dynamic>;
        for (final item in attrs) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              // Сохраняем атрибут с его ID как ключ
              characteristics![id] = {
                'id': item['id'],
                'title': item['title'] ?? '',
                'value': item['value'],
                'max_value': item['max_value'],
              };
            }
          }
        }
      } else if (json['attributes'] is Map) {
        // Формат 2: Структурированный Map с value_selected и values
        final attrs = json['attributes'] as Map<String, dynamic>;

        // Парсим value_selected атрибуты (ID < 1000)
        if (attrs['value_selected'] != null && attrs['value_selected'] is Map) {
          final valueSelected = attrs['value_selected'] as Map;
          valueSelected.forEach((key, valueObj) {
            characteristics![key.toString()] = valueObj;
          });
        }

        // Парсим values атрибуты (ID >= 1000)
        if (attrs['values'] != null && attrs['values'] is Map) {
          final values = attrs['values'] as Map;
          values.forEach((key, valueObj) {
            characteristics![key.toString()] = valueObj;
          });
        }
      }
    } else {
      print('   ⚠️ NO attributes found in JSON');
    }

    if (characteristics != null && characteristics!.isNotEmpty) {
      print('   ✅ Parsed characteristics: ${characteristics!.keys.toList()}');
    }

    return Advert(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      name: json['name'] ?? '',
      price: json['price'] ?? '',
      thumbnail: json['thumbnail'],
      images: imagess,
      status: json['status'] != null
          ? AdvertStatus.fromJson(json['status'] as Map<String, dynamic>)
          : AdvertStatus(id: 1, title: 'Active'),
      address: json['address'] ?? '',
      viewsCount: json['views_count'] ?? 0,
      clickCount: json['click_count'] ?? 0,
      shareCount: json['share_count'] ?? 0,
      type: json['type'] != null
          ? AdvertType.fromJson(json['type'] as Map<String, dynamic>)
          : AdvertType(id: 1, type: 'adverts', path: 'adverts'),
      sellerName: sellerName,
      sellerAvatar: sellerAvatar,
      sellerRegistrationDate: sellerRegistrationDate,
      sellerId: sellerId,
      description: json['description'],
      characteristics: characteristics,
    );
  }
}

class AdvertStatus {
  final int id;
  final String title;

  AdvertStatus({required this.id, required this.title});

  factory AdvertStatus.fromJson(Map<String, dynamic> json) {
    return AdvertStatus(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown', // Обрабатываем null значения
    );
  }
}

class AdvertType {
  final int id;
  final String type;
  final String path;

  AdvertType({required this.id, required this.type, required this.path});

  factory AdvertType.fromJson(Map<String, dynamic> json) {
    return AdvertType(
      id: json['id'] ?? 0,
      type: json['type'] ?? '', // Обрабатываем null значения из API
      path: json['path'] ?? '',
    );
  }
}

class AdvertsResponse {
  final List<Advert> data;
  final Links links;
  final Meta meta;

  AdvertsResponse({
    required this.data,
    required this.links,
    required this.meta,
  });

  factory AdvertsResponse.fromJson(Map<String, dynamic> json) {
    return AdvertsResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => Advert.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      links: json['links'] != null ? Links.fromJson(json['links']) : Links(),
      meta: json['meta'] != null
          ? Meta.fromJson(json['meta'])
          : Meta(
              currentPage: 1,
              from: 1,
              lastPage: 1,
              links: [],
              path: '/adverts',
              perPage: 10,
              to: 10,
              total: (json['data'] as List<dynamic>?)?.length ?? 0,
            ),
    );
  }
}

class Links {
  final String? first;
  final String? last;
  final String? prev;
  final String? next;

  Links({this.first, this.last, this.prev, this.next});

  factory Links.fromJson(Map<String, dynamic> json) {
    return Links(
      first: json['first'],
      last: json['last'],
      prev: json['prev'],
      next: json['next'],
    );
  }
}

class Meta {
  final int currentPage;
  final int from;
  final int lastPage;
  final List<MetaLink> links;
  final String path;
  final int perPage;
  final int to;
  final int total;

  Meta({
    required this.currentPage,
    required this.from,
    required this.lastPage,
    required this.links,
    required this.path,
    required this.perPage,
    required this.to,
    required this.total,
  });

  factory Meta.fromJson(Map<String, dynamic> json) {
    return Meta(
      currentPage: json['current_page'] as int? ?? 1,
      from: json['from'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      links: ((json['links'] as List<dynamic>?) ?? [])
          .map((item) => MetaLink.fromJson(item as Map<String, dynamic>))
          .toList(),
      path: json['path'] as String? ?? '/adverts',
      perPage: json['per_page'] as int? ?? 10,
      to: json['to'] as int? ?? 10,
      total: json['total'] as int? ?? 0,
    );
  }
}

class MetaLink {
  final String? url;
  final String? label;
  final int? page;
  final bool active;

  MetaLink({this.url, this.label, this.page, required this.active});

  factory MetaLink.fromJson(Map<String, dynamic> json) {
    return MetaLink(
      url: json['url'],
      label: json['label'],
      page: json['page'],
      active: json['active'],
    );
  }
}

class AdvertToListing {
  // Static method to convert Advert to Listing
  static Listing toListing(Advert advert) {
    return Listing(
      id: advert.id.toString(),
      imagePath: advert.thumbnail ?? 'assets/home_page/image.png',
      title: advert.name,
      price: advert.price,
      location: advert.address,
      date: advert.date,
      isFavorited: false,
    );
  }
}

// Extension to convert Advert to Listing for compatibility with existing UI
extension AdvertToListingExtension on Advert {
  Listing toListing() {
    return Listing(
      id: id.toString(),
      imagePath: (thumbnail != null && thumbnail!.isNotEmpty) ? thumbnail! : '',
      images: images,
      title: name,
      price: price,
      location: address,
      date: date,
      isFavorited: false, // Default, can be updated later
      sellerName: sellerName,
      sellerAvatar: sellerAvatar,
      sellerRegistrationDate: sellerRegistrationDate,
      // sellerId берётся из user.id детального ответа API
      userId: sellerId,
      description: description,
      characteristics: characteristics ?? {},
    );
  }
}

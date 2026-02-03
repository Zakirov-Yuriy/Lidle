import 'package:lidle/models/home_models.dart';

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
  });

  factory Advert.fromJson(Map<String, dynamic> json) {
    print('Advert ${json['id']} images in JSON: ${json['images']}');
    return Advert(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      name: json['name'] ?? '',
      price: json['price'] ?? '',
      thumbnail: json['thumbnail'],
      images: List<String>.from(json['images'] ?? []),
      status: json['status'] != null
          ? AdvertStatus.fromJson(json['status'])
          : AdvertStatus(id: 1, title: 'Active'),
      address: json['address'] ?? '',
      viewsCount: json['views_count'] ?? 0,
      clickCount: json['click_count'] ?? 0,
      shareCount: json['share_count'] ?? 0,
      type: json['type'] != null
          ? AdvertType.fromJson(json['type'])
          : AdvertType(id: 1, type: 'adverts', path: 'adverts'),
    );
  }
}

class AdvertStatus {
  final int id;
  final String title;

  AdvertStatus({required this.id, required this.title});

  factory AdvertStatus.fromJson(Map<String, dynamic> json) {
    return AdvertStatus(id: json['id'], title: json['title']);
  }
}

class AdvertType {
  final int id;
  final String type;
  final String path;

  AdvertType({required this.id, required this.type, required this.path});

  factory AdvertType.fromJson(Map<String, dynamic> json) {
    return AdvertType(id: json['id'], type: json['type'], path: json['path']);
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
      data: (json['data'] as List<dynamic>)
          .map((item) => Advert.fromJson(item as Map<String, dynamic>))
          .toList(),
      links: Links.fromJson(json['links']),
      meta: Meta.fromJson(json['meta']),
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
      currentPage: json['current_page'],
      from: json['from'],
      lastPage: json['last_page'],
      links: (json['links'] as List<dynamic>)
          .map((item) => MetaLink.fromJson(item as Map<String, dynamic>))
          .toList(),
      path: json['path'],
      perPage: json['per_page'],
      to: json['to'],
      total: json['total'],
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
      imagePath:
          thumbnail ?? 'assets/home_page/image.png', // Fallback if no thumbnail
      images: images,
      title: name,
      price: price,
      location: address,
      date: date,
      isFavorited: false, // Default, can be updated later
    );
  }
}

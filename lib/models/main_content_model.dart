import 'package:json_annotation/json_annotation.dart';

part 'main_content_model.g.dart';

/// Модель для главной страницы (GET /content/main)
@JsonSerializable()
class MainContent {
  final MainContentData data;

  MainContent({required this.data});

  factory MainContent.fromJson(Map<String, dynamic> json) =>
      _$MainContentFromJson(json);
  Map<String, dynamic> toJson() => _$MainContentToJson(this);
}

@JsonSerializable()
class MainContentData {
  final List<MainCatalog> catalogs;
  final List<MainAdvert> adverts;

  MainContentData({required this.catalogs, required this.adverts});

  factory MainContentData.fromJson(Map<String, dynamic> json) =>
      _$MainContentDataFromJson(json);
  Map<String, dynamic> toJson() => _$MainContentDataToJson(this);
}

@JsonSerializable()
class MainCatalog {
  final int id;
  final String name;
  final String? thumbnail;
  final String slug;
  final ContentType type;
  final String order;

  MainCatalog({
    required this.id,
    required this.name,
    this.thumbnail,
    required this.slug,
    required this.type,
    required this.order,
  });

  factory MainCatalog.fromJson(Map<String, dynamic> json) =>
      _$MainCatalogFromJson(json);
  Map<String, dynamic> toJson() => _$MainCatalogToJson(this);
}

@JsonSerializable()
class MainAdvert {
  final int id;
  final String date;
  final String name;
  final String price;
  final String? thumbnail;
  final AdvertStatus status;
  final String address;
  final int views_count;
  final int click_count;
  final int share_count;
  final ContentType type;

  MainAdvert({
    required this.id,
    required this.date,
    required this.name,
    required this.price,
    this.thumbnail,
    required this.status,
    required this.address,
    required this.views_count,
    required this.click_count,
    required this.share_count,
    required this.type,
  });

  factory MainAdvert.fromJson(Map<String, dynamic> json) =>
      _$MainAdvertFromJson(json);
  Map<String, dynamic> toJson() => _$MainAdvertToJson(this);
}

@JsonSerializable()
class AdvertStatus {
  final int id;
  final String title;

  AdvertStatus({required this.id, required this.title});

  factory AdvertStatus.fromJson(Map<String, dynamic> json) =>
      _$AdvertStatusFromJson(json);
  Map<String, dynamic> toJson() => _$AdvertStatusToJson(this);
}

@JsonSerializable()
class ContentType {
  final int id;
  final String type;
  final String path;

  ContentType({required this.id, required this.type, required this.path});

  factory ContentType.fromJson(Map<String, dynamic> json) =>
      _$ContentTypeFromJson(json);
  Map<String, dynamic> toJson() => _$ContentTypeToJson(this);
}

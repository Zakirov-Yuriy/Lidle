class ResponseModel {
  final String id;
  final String category;
  final String title;
  final double price;
  final String userName;
  final String userAvatar;
  final double rating;
  final List<String>? phoneNumbers;
  final String? telegram;
  final String? whatsapp;
  final String? vk;
  final String? city;

  ResponseModel({
    required this.id,
    required this.category,
    required this.title,
    required this.price,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    this.phoneNumbers,
    this.telegram,
    this.whatsapp,
    this.vk,
    this.city,
  });
}

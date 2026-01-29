/// Модель для телефонного номера
class PhoneModel {
  final int id;
  final String phone;
  final DateTime createdAt;

  PhoneModel({required this.id, required this.phone, required this.createdAt});

  factory PhoneModel.fromJson(Map<String, dynamic> json) {
    return PhoneModel(
      id: json['id'] as int? ?? 0,
      phone: json['phone'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Модель для адреса электронной почты
class EmailModel {
  final int id;
  final String email;
  final DateTime createdAt;

  EmailModel({required this.id, required this.email, required this.createdAt});

  factory EmailModel.fromJson(Map<String, dynamic> json) {
    return EmailModel(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Модель для ответа со списком телефонов
class PhonesResponse {
  final List<PhoneModel> data;

  PhonesResponse({required this.data});

  factory PhonesResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> dataList = json['data'] as List<dynamic>? ?? [];
    return PhonesResponse(
      data: dataList
          .map((item) => PhoneModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Модель для ответа со списком email
class EmailsResponse {
  final List<EmailModel> data;

  EmailsResponse({required this.data});

  factory EmailsResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> dataList = json['data'] as List<dynamic>? ?? [];
    return EmailsResponse(
      data: dataList
          .map((item) => EmailModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Модель для универсального ответа при добавлении контакта
class ContactResponse {
  final bool success;
  final String? message;
  final List<PhoneModel>? phones;
  final List<EmailModel>? emails;

  ContactResponse({
    required this.success,
    this.message,
    this.phones,
    this.emails,
  });

  factory ContactResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? phonesList = json['data'] as List<dynamic>?;
    final List<dynamic>? emailsList = json['data'] as List<dynamic>?;

    List<PhoneModel>? parsedPhones;
    List<EmailModel>? parsedEmails;

    if (phonesList != null && phonesList.isNotEmpty) {
      final firstItem = phonesList.first as Map<String, dynamic>;
      if (firstItem.containsKey('phone')) {
        parsedPhones = phonesList
            .map((item) => PhoneModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    if (emailsList != null && emailsList.isNotEmpty) {
      final firstItem = emailsList.first as Map<String, dynamic>;
      if (firstItem.containsKey('email')) {
        parsedEmails = emailsList
            .map((item) => EmailModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    return ContactResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      phones: parsedPhones,
      emails: parsedEmails,
    );
  }
}

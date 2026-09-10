// ============================================================
// Сотрудники публикации (макет 10.09.2026).
// ============================================================
//
// Ручки повторяют доставку один в один: и там и там папка с обложкой, внутри
// карточки.
//
// Документация: back/api/product-publications-api.md

import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/services/api_service.dart';

class ProductsStaffApi {
  static Future<PublicationStaff> load(int publicationId) async {
    final response = await ApiService.get(
      '/me/product-publications/$publicationId/staff',
    );

    return PublicationStaff.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  /// Справочники доступов. Названия берём с сервера: пункты — это разделы
  /// приложения, и вторая копия названий рано или поздно разъедется.
  static Future<StaffAccessDictionary> access() async {
    final response = await ApiService.get(
      '/me/product-publications/staff-access',
    );

    return StaffAccessDictionary.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // ── Группы ────────────────────────────────────────────────────────

  static Future<StaffGroup> createGroup({
    required int publicationId,
    required String name,
  }) async {
    final response = await ApiService.post(
      '/me/product-publications/$publicationId/staff-groups',
      {'name': name},
    );

    return StaffGroup.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  static Future<void> renameGroup(int groupId, String name) async {
    await ApiService.put(
      '/me/product-publications/staff-groups/$groupId',
      {'name': name},
    );
  }

  static Future<void> deleteGroup(int groupId) async {
    await ApiService.delete('/me/product-publications/staff-groups/$groupId');
  }

  static Future<void> uploadGroupImage(int groupId, String filePath) async {
    await ApiService.uploadFile(
      '/me/product-publications/staff-groups/$groupId/image',
      filePath: filePath,
      fieldName: 'image',
    );
  }

  // ── Сотрудники ────────────────────────────────────────────────────

  static Future<StaffMember> createMember({
    required int publicationId,
    required String name,
    String? position,
    int? number,
    num? salary,
    List<String>? venueAccess,
    List<String>? accountAccess,
    String? description,
    int? groupId,
  }) async {
    final response = await ApiService.post(
      '/me/product-publications/$publicationId/staff',
      {
        'name': name,
        if (position != null) 'position': position,
        if (number != null) 'number': number,
        if (salary != null) 'salary': salary,
        if (venueAccess != null) 'venue_access': venueAccess,
        if (accountAccess != null) 'account_access': accountAccess,
        if (description != null) 'description': description,
        if (groupId != null) 'group_id': groupId,
      },
    );

    return StaffMember.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  /// Изменить сотрудника.
  ///
  /// Зарплату и доступы присылаем, только когда их трогали: пустое значение
  /// здесь означает «стереть», а не «не менял».
  static Future<void> updateMember(
    int memberId, {
    String? name,
    String? position,
    int? number,
    num? salary,
    bool touchSalary = false,
    List<String>? venueAccess,
    List<String>? accountAccess,
    String? description,
    int? groupId,
  }) async {
    await ApiService.put(
      '/me/product-publications/staff/$memberId',
      {
        if (name != null) 'name': name,
        if (position != null) 'position': position,
        if (number != null) 'number': number,
        if (touchSalary) 'salary': salary,
        if (venueAccess != null) 'venue_access': venueAccess,
        if (accountAccess != null) 'account_access': accountAccess,
        if (description != null) 'description': description,
        if (groupId != null) 'group_id': groupId,
      },
    );
  }

  static Future<void> deleteMember(int memberId) async {
    await ApiService.delete('/me/product-publications/staff/$memberId');
  }

  static Future<void> uploadMemberImage(int memberId, String filePath) async {
    await ApiService.uploadFile(
      '/me/product-publications/staff/$memberId/image',
      filePath: filePath,
      fieldName: 'image',
    );
  }
}

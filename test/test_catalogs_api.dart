import 'package:lidle/services/api_service.dart';

void main() async {
  print('═══════════════════════════════════════════════════════');
  print('🧪 CATALOGS API TEST');
  print('═══════════════════════════════════════════════════════\n');

  try {
    print('📥 Fetching catalogs from API...\n');
    final response = await ApiService.getCatalogs();

    print('\n✅ Successfully loaded catalogs!');
    print('Total catalogs: ${response.data.length}\n');

    if (response.data.isEmpty) {
      print('⚠️ WARNING: No catalogs returned from API!');
    } else {
      for (var i = 0; i < response.data.length; i++) {
        final catalog = response.data[i];
        print('┌─ Catalog [$i]');
        print('│  ID: ${catalog.id}');
        print('│  Name: ${catalog.name}');
        print('│  Slug: ${catalog.slug}');
        print('│  Thumbnail: ${catalog.thumbnail ?? 'NULL'}');
        print('│  Type.id: ${catalog.type.id}');
        print('│  Type.type: ${catalog.type.type ?? 'NULL'}');
        print('│  Type.path: ${catalog.type.path ?? 'NULL'}');
        print('│  Type.slug: ${catalog.type.slug ?? 'NULL'}');
        print('│  Order: ${catalog.order}');
        print('└─');
      }
    }

    print('\n═══════════════════════════════════════════════════════');
    print('✅ TEST COMPLETE');
    print('═══════════════════════════════════════════════════════');
  } catch (e, stackTrace) {
    print('\n❌ ERROR: $e');
    print('\nStackTrace:\n$stackTrace');
    print('═══════════════════════════════════════════════════════');
  }
}

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/core/logger.dart';

// ============================================================
// "Полный экран подкатегорий в выбранной категории недвижимости"
// ============================================================

class RealEstateFullApartmentsScreen extends StatefulWidget {
  final String selectedCategory;
  final List<dynamic>? categoryChildren;
  final int? parentCategoryId; // ID родительской категории (например, ID Квартир)

  const RealEstateFullApartmentsScreen({
    super.key,
    this.selectedCategory = 'Недвижимость',
    this.categoryChildren,
    this.parentCategoryId,
  });

  @override
  State<RealEstateFullApartmentsScreen> createState() =>
      _RealEstateFullApartmentsScreenState();
}

class _RealEstateFullApartmentsScreenState
    extends State<RealEstateFullApartmentsScreen> {
  bool _isNavigating = false; // Флаг для предотвращения множественных навигаций

  @override
  Widget build(BuildContext context) {
    log.d('🏗️ RealEstateFullApartmentsScreen.build() called - category="${widget.selectedCategory}", childrenCount=${widget.categoryChildren?.length ?? 0}');
    
    // Используем переданные подкатегории или статичный список по умолчанию
    final apartments = widget.categoryChildren?.isNotEmpty == true
        ? widget.categoryChildren!.map((child) => child.name as String).toList()
        : [
            'Продажа ${widget.selectedCategory.toLowerCase()}',
            'Долгосрочная аренда ${widget.selectedCategory.toLowerCase()}',
            'Посуточная аренда ${widget.selectedCategory.toLowerCase()}',
          ];
    
    log.d('📝 apartments.length=${apartments.length}, items=[${apartments.join(", ")}]');

    return Scaffold(
      backgroundColor: primaryBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 23, top: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [const Header()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.arrow_back_ios,
                            color: activeIconColor,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Назад',
                            style: TextStyle(
                              color: activeIconColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Отмена',
                        style: TextStyle(color: activeIconColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25, bottom: 55),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Недвижимость: ${widget.selectedCategory}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...apartments.map((apartment) => _buildOptionTile(context, apartment)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, String title) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          onTap: () async {
            // Защита от множественных нажатий
            if (_isNavigating) {
              log.d('🛑 Already navigating, ignoring tap on "$title"');
              return;
            }
            
            _isNavigating = true;
            
            try {
              // Ищем ID этого дочернего элемента в categoryChildren
              int childId = widget.parentCategoryId ?? 1; // Fallback
              dynamic selectedChild;
              
              if (widget.categoryChildren != null) {
                for (var child in widget.categoryChildren!) {
                  if (child.name == title) {
                    childId = child.id as int;
                    selectedChild = child;
                    break;
                  }
                }
              }
              
              log.d('🔍 [_buildOptionTile] title="$title", childId=$childId');
              log.d('   hasChildren=${selectedChild?.children != null && selectedChild.children!.isNotEmpty}');
              if (selectedChild?.children != null) {
                log.d('   children.length=${selectedChild.children.length}');
                for (int i = 0; i < selectedChild.children.length; i++) {
                  log.d('      [$i] ${selectedChild.children[i].name} (id=${selectedChild.children[i].id})');
                }
              }
              
              // ВАЖНО: Проверяем, есть ли у выбранной опции ещё дети
              // Если да, то это не конечная категория, нужен ещё один уровень
              if (selectedChild != null && selectedChild.children != null && selectedChild.children!.isNotEmpty) {
                log.d('ℹ️ "$title" имеет ${selectedChild.children!.length} подкатегорий, переходим на следующий уровень');
                log.d('🔴 [DEBUG] Push to next level: $title (ID=$childId)');
                // Переходим на следующий уровень (ВАЖНО: используем push, НЕ pushReplacement, чтобы сохранить стек)
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RealEstateFullApartmentsScreen(
                      selectedCategory: title, // Используем текущую как заголовок
                      categoryChildren: selectedChild.children,
                      parentCategoryId: childId, // ID текущей категории как parent
                    ),
                  ),
                );
                
                // Если получили результат с другого уровня, пробрасываем его выше
                if (result != null && mounted) {
                  log.d('🔴 [DEBUG] Got result from child level, passing up: $result');
                  Navigator.pop(context, result);
                }
                return;
              }
              
              // Если это конечная категория (нет детей), возвращаемся с ID
              log.d('✅ "$title" - конечная категория (ID: $childId), возвращаем result');
              log.d('🔴 [DEBUG] Pop returning from RealEstateFullApartmentsScreen with: name=$title, id=$childId');
              Navigator.pop(context, {'name': title, 'id': childId});
            } finally {
              _isNavigating = false;
            }
          },
        ),
        const Divider(color: Colors.white24, height: 0.9),
      ],
    );
  }
}

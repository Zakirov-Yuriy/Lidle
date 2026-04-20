import 'package:flutter/material.dart';
import 'package:lidle/models/filter_models.dart';

/// Заголовок стиля над полем фильтра.
///
/// В исходной версии рисовал текст `Style2: <код>` для отладки, но сам
/// Text был закомментирован. Этот виджет сохраняет то же поведение
/// 1-в-1: при непустом стиле атрибута добавляется отступ 4px, иначе
/// ничего. Сделан отдельным классом, чтобы потом легко вернуть дебаг-
/// текст при необходимости, не трогая код формы.
class StyleHeader extends StatelessWidget {
  const StyleHeader({
    super.key,
    required this.attribute,
    this.isSubmissionMode = true,
  });

  final Attribute attribute;
  final bool isSubmissionMode;

  @override
  Widget build(BuildContext context) {
    // В режиме подачи объявления используется styleSingle,
    // в режиме просмотра — style (обычно пустой от API).
    final displayStyle =
        isSubmissionMode ? (attribute.styleSingle ?? '') : attribute.style;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (displayStyle.isNotEmpty) const SizedBox(height: 4),
      ],
    );
  }
}

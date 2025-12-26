
class ReviewModel {
  final String id;
  final String productImage;
  final String productName;
  final String reviewDate;
  final double rating;
  final String reviewText;
  final int commentCount;
  final String? commentAuthor;
  final String? commentDate;
  final String? commentText;
  final bool canEdit;
  final bool canDelete;

  ReviewModel({
    required this.id,
    required this.productImage,
    required this.productName,
    required this.reviewDate,
    required this.rating,
    required this.reviewText,
    required this.commentCount,
    this.commentAuthor,
    this.commentDate,
    this.commentText,
    required this.canEdit,
    required this.canDelete,
  });
}

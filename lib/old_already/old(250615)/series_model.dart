import 'package:uuid/uuid.dart';

class Series {
  final String id;
  final String title;
  final String? description;
  final List<Map<String, dynamic>>? requiredBooks;

  Series({
    required this.id,
    required this.title,
    this.description,
    this.requiredBooks,
  });

  factory Series.fromMap(Map<String, dynamic> map) {
    return Series(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      requiredBooks: map['requiredBooks'] != null
          ? List<Map<String, dynamic>>.from(map['requiredBooks'])
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'requiredBooks': requiredBooks ?? [],
    };
  }
}
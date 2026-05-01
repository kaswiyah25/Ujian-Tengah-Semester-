class Todo {
  final int? id;
  final String title;
  final String description;
  final String createdAt;
  final bool isDone;
  final String? deadline;
  final int? categoryId; // ✅ TAMBAHAN: foreign key ke tabel categories

  Todo({
    this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.isDone = false,
    this.deadline,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt,
      'isDone': isDone ? 1 : 0,
      'deadline': deadline,
      'categoryId': categoryId, // ✅ TAMBAHAN
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      createdAt: map['createdAt'] as String,
      isDone: map['isDone'] == 1,
      deadline: map['deadline'] as String?,
      categoryId: map['categoryId'] as int?, // ✅ TAMBAHAN
    );
  }
}
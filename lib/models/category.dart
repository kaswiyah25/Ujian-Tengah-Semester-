// ✅ BARU: Kelas model untuk tabel categories
class Category {
  final int? id;
  final String name;

  Category({
    this.id,
    required this.name,
  });

  // Convert object → Map (untuk disimpan ke SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  // Convert Map → object (dari SQLite)
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }

  // Memudahkan tampilan nama kategori di dropdown
  @override
  String toString() => name;
}
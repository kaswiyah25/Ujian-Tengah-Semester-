import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../models/category.dart';
import '../database/database_helper.dart';
import 'todo_form_screen.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Todo> _todos = [];
  bool _isLoading = true;

  // State filter dan pencarian
  String _filterStatus = 'all';
  final TextEditingController _searchController = TextEditingController();

  // ✅ TAMBAHAN: state untuk daftar kategori dan filter kategori
  List<Category> _categories = [];
  int? _selectedCategoryId; // null = semua kategori

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadTodos();
    _searchController.addListener(_loadTodos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ TAMBAHAN: memuat daftar kategori untuk filter
  Future<void> _loadCategories() async {
    final categories = await _dbHelper.getAllCategories();
    setState(() => _categories = categories);
  }

  Future<void> _loadTodos() async {
    setState(() => _isLoading = true);
    final todos = await _dbHelper.getTodosFiltered(
      filterStatus: _filterStatus,
      keyword: _searchController.text,
      categoryId: _selectedCategoryId, // ✅ TAMBAHAN: kirim filter kategori
    );
    setState(() {
      _todos = todos;
      _isLoading = false;
    });
  }

  Future<void> _toggleTodo(Todo todo) async {
    await _dbHelper.toggleTodoStatus(todo.id!, !todo.isDone);
    _loadTodos();
  }

  Future<void> _deleteTodo(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tugas'),
        content: const Text('Tugas ini akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _dbHelper.deleteTodo(id);
      _loadTodos();
    }
  }

  Future<void> _navigateToAddForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TodoFormScreen()),
    );
    _loadTodos();
  }

  Future<void> _navigateToEditForm(Todo todo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TodoFormScreen(todo: todo)),
    );
    _loadTodos();
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildDeadlineBadge(String deadlineIso) {
    final deadline = DateTime.parse(deadlineIso);
    final now = DateTime.now();
    final diff = deadline.difference(now).inDays;

    Color bgColor;
    Color textColor;
    String label;

    if (now.isAfter(deadline)) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
      label = 'Lewat: ${_formatDate(deadlineIso)}';
    } else if (diff <= 3) {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
      label = 'Deadline: ${_formatDate(deadlineIso)}';
    } else {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
      label = 'Deadline: ${_formatDate(deadlineIso)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ✅ TAMBAHAN: badge nama kategori pada setiap item tugas
  Widget _buildCategoryBadge(int categoryId) {
    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(id: 0, name: ''),
    );
    if (category.name.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.name,
        style: TextStyle(
          fontSize: 11,
          color: Colors.blue.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Hapus semua yang selesai',
            onPressed: () async {
              await _dbHelper.clearCompletedTodos();
              _loadTodos();
            },
          ),
        ],
      ),

      body: Column(
        children: [

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari tugas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadTodos();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Filter status: Semua / Belum Selesai / Selesai
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                _buildStatusChip(label: 'Semua', value: 'all'),
                const SizedBox(width: 8),
                _buildStatusChip(label: 'Belum Selesai', value: 'active'),
                const SizedBox(width: 8),
                _buildStatusChip(label: 'Selesai', value: 'done'),
              ],
            ),
          ),

          // ✅ TAMBAHAN: Filter kategori — scrollable horizontal
          if (_categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                children: [
                  // Chip "Semua Kategori"
                  _buildCategoryChip(label: 'Semua Kategori', categoryId: null),
                  const SizedBox(width: 8),
                  // Chip untuk setiap kategori
                  ..._categories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildCategoryChip(
                        label: cat.name,
                        categoryId: cat.id,
                      ),
                    );
                  }),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // Daftar tugas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _todos.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada tugas yang ditemukan.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _todos.length,
                        itemBuilder: (context, index) {
                          final todo = _todos[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: Checkbox(
                                value: todo.isDone,
                                onChanged: (_) => _toggleTodo(todo),
                              ),

                              title: Text(
                                todo.title,
                                style: TextStyle(
                                  decoration: todo.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: todo.isDone ? Colors.grey : null,
                                ),
                              ),

                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (todo.description.isNotEmpty)
                                    Text(todo.description),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(todo.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // ✅ TAMBAHAN: Tampilkan badge kategori dan deadline berdampingan
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (todo.categoryId != null)
                                        _buildCategoryBadge(todo.categoryId!),
                                      if (todo.deadline != null &&
                                          todo.deadline!.isNotEmpty)
                                        _buildDeadlineBadge(todo.deadline!),
                                    ],
                                  ),
                                ],
                              ),

                              isThreeLine: true,

                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () =>
                                        _navigateToEditForm(todo),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 20, color: Colors.red),
                                    onPressed: () => _deleteTodo(todo.id!),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddForm,
        child: const Icon(Icons.add),
      ),
    );
  }

  // Chip untuk filter status
  Widget _buildStatusChip({required String label, required String value}) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _filterStatus = value);
        _loadTodos();
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  // ✅ TAMBAHAN: Chip untuk filter kategori
  Widget _buildCategoryChip(
      {required String label, required int? categoryId}) {
    final isSelected = _selectedCategoryId == categoryId;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedCategoryId = categoryId);
        _loadTodos();
      },
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade800,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.blue.shade800 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
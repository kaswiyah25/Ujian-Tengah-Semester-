import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../models/category.dart';
import '../database/database_helper.dart';

class TodoFormScreen extends StatefulWidget {
  final Todo? todo;

  const TodoFormScreen({super.key, this.todo});

  @override
  State<TodoFormScreen> createState() => _TodoFormScreenState();
}

class _TodoFormScreenState extends State<TodoFormScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  DateTime? _selectedDeadline;

  // ✅ TAMBAHAN: state untuk daftar kategori dan kategori yang dipilih
  List<Category> _categories = [];
  Category? _selectedCategory;

  bool get _isEditMode => widget.todo != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (_isEditMode) {
      _titleController.text = widget.todo!.title;
      _descController.text = widget.todo!.description;
      if (widget.todo!.deadline != null && widget.todo!.deadline!.isNotEmpty) {
        _selectedDeadline = DateTime.parse(widget.todo!.deadline!);
      }
    }
  }

  // ✅ TAMBAHAN: memuat daftar kategori dari database
  Future<void> _loadCategories() async {
    final categories = await _dbHelper.getAllCategories();
    setState(() {
      _categories = categories;
      // Jika mode edit, cocokkan kategori yang sudah tersimpan
      if (_isEditMode && widget.todo!.categoryId != null) {
        _selectedCategory = _categories.firstWhere(
          (c) => c.id == widget.todo!.categoryId,
          orElse: () => _categories.first,
        );
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal deadline',
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedDeadline != null
          ? TimeOfDay.fromDateTime(_selectedDeadline!)
          : TimeOfDay.now(),
      helpText: 'Pilih jam deadline',
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDeadline = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _clearDeadline() => setState(() => _selectedDeadline = null);

  String _formatDeadline(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $jam:$menit';
  }

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        final updatedTodo = Todo(
          id: widget.todo!.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          isDone: widget.todo!.isDone,
          createdAt: widget.todo!.createdAt,
          deadline: _selectedDeadline?.toIso8601String(),
          categoryId: _selectedCategory?.id, // ✅ TAMBAHAN
        );
        await _dbHelper.updateTodo(updatedTodo);
      } else {
        final newTodo = Todo(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          createdAt: DateTime.now().toIso8601String(),
          deadline: _selectedDeadline?.toIso8601String(),
          categoryId: _selectedCategory?.id, // ✅ TAMBAHAN
        );
        await _dbHelper.insertTodo(newTodo);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan tugas: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Tugas' : 'Tambah Tugas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Field judul
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul Tugas',
                  hintText: 'Masukkan judul tugas',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Judul tugas tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Field deskripsi
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  hintText: 'Masukkan deskripsi tugas',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // ✅ TAMBAHAN: Dropdown pilihan kategori
              DropdownButtonFormField<Category>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategori (opsional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline, size: 18),
                ),
                hint: const Text('Pilih kategori'),
                items: [
                  // Opsi "Tanpa Kategori"
                  const DropdownMenuItem<Category>(
                    value: null,
                    child: Text('Tanpa Kategori'),
                  ),
                  // Daftar kategori dari database
                  ..._categories.map((category) {
                    return DropdownMenuItem<Category>(
                      value: category,
                      child: Text(category.name),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 16),

              // Field deadline
              InkWell(
                onTap: _pickDeadline,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Deadline (opsional)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    suffixIcon: _selectedDeadline != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _clearDeadline,
                          )
                        : null,
                  ),
                  child: Text(
                    _selectedDeadline != null
                        ? _formatDeadline(_selectedDeadline!)
                        : 'Ketuk untuk memilih tanggal & jam',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedDeadline != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tombol simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTodo,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEditMode ? 'Simpan Perubahan' : 'Tambah Tugas',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
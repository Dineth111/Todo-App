import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final int tasks;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.tasks,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: selected ? const Color(0xFF2563EB) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$tasks tasks',
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white70 : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Todo {
  final String id;
  String title;
  String category;
  bool done;

  Todo({
    required this.id,
    required this.title,
    this.category = 'Personal',
    this.done = false,
  });

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String? ?? 'Personal',
    done: json['done'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'done': done,
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FB),
          elevation: 0,
          foregroundColor: Color(0xFF111827),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Segoe UI',
          bodyColor: const Color(0xFF111827),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: StadiumBorder(),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const TodoHomePage(),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<Todo> _todos = [];
  final TextEditingController _textController = TextEditingController();
  String _selectedCategory = 'All';
  static const _storageKey = 'todos_v1';

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    setState(() {
      _todos
        ..clear()
        ..addAll(
          raw.map((s) => Todo.fromJson(jsonDecode(s) as Map<String, dynamic>)),
        );
    });
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _todos.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  void _addTodoFromInput() {
    final title = _textController.text.trim();
    if (title.isEmpty) return;
    _addTodo(title);
    _textController.clear();
  }

  Future<void> _addTodo(String title, {String? categoryOverride}) async {
    final category =
        categoryOverride ??
        (_selectedCategory == 'All' ? 'Personal' : _selectedCategory);
    setState(() {
      _todos.insert(
        0,
        Todo(
          id: DateTime.now().toIso8601String(),
          title: title,
          category: category,
        ),
      );
    });
    await _saveTodos();
  }

  Future<void> _toggleTodo(Todo todo) async {
    setState(() {
      todo.done = !todo.done;
    });
    await _saveTodos();
  }

  Future<void> _deleteTodoAt(int index) async {
    final removed = _todos.removeAt(index);
    setState(() {});
    await _saveTodos();

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "${removed.title}"'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            setState(() {
              _todos.insert(index, removed);
            });
            await _saveTodos();
          },
        ),
      ),
    );
  }

  Future<void> _editTodo(Todo todo) async {
    final controller = TextEditingController(text: todo.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Update your task'),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        todo.title = result;
      });
      await _saveTodos();
    }
  }

  Future<void> _clearCompleted() async {
    final removed = _todos.where((t) => t.done).toList();
    if (removed.isEmpty) return;
    setState(() {
      _todos.removeWhere((t) => t.done);
    });
    await _saveTodos();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cleared ${removed.length} completed tasks'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            setState(() {
              _todos.insertAll(0, removed);
            });
            await _saveTodos();
          },
        ),
      ),
    );
  }

  List<Todo> get _filteredTodos {
    if (_selectedCategory == 'All') return _todos;
    return _todos.where((t) => t.category == _selectedCategory).toList();
  }

  int get _remainingCount => _todos
      .where(
        (t) =>
            !t.done &&
            (_selectedCategory == 'All' || t.category == _selectedCategory),
      )
      .length;

  int get _totalCount => _todos
      .where(
        (t) => _selectedCategory == 'All' || t.category == _selectedCategory,
      )
      .length;

  @override
  Widget build(BuildContext context) {
    final remaining = _remainingCount;
    final total = _totalCount;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "What's up, Joy!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              total == 0
                  ? 'You have no tasks for this category'
                  : '$remaining of $total tasks remaining',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _clearCompleted,
            icon: const Icon(Icons.done_all_outlined),
            tooltip: 'Clear completed',
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBottomSheet,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          const SizedBox(height: 8),
          _buildCategoryRow(),
          const SizedBox(height: 8),
          _buildInlineInput(),
          Expanded(
            child: _filteredTodos.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 96),
                    itemCount: _filteredTodos.length,
                    itemBuilder: (context, index) {
                      final todo = _filteredTodos[index];
                      final realIndex = _todos.indexOf(todo);
                      return _buildTodoTile(todo, realIndex);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = _totalCount;
    final remaining = _remainingCount;
    final completed = total == 0 ? 0 : total - remaining;
    final progress = total == 0 ? 0.0 : completed / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            total == 0 ? '0%' : '${(progress * 100).round()}%',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    int countFor(String category) {
      if (category == 'All') return _todos.length;
      return _todos.where((t) => t.category == category).length;
    }

    return SizedBox(
      height: 110,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          _CategoryCard(
            title: 'All',
            tasks: countFor('All'),
            selected: _selectedCategory == 'All',
            onTap: () => setState(() => _selectedCategory = 'All'),
          ),
          const SizedBox(width: 12),
          _CategoryCard(
            title: 'Business',
            tasks: countFor('Business'),
            selected: _selectedCategory == 'Business',
            onTap: () => setState(() => _selectedCategory = 'Business'),
          ),
          const SizedBox(width: 12),
          _CategoryCard(
            title: 'Personal',
            tasks: countFor('Personal'),
            selected: _selectedCategory == 'Personal',
            onTap: () => setState(() => _selectedCategory = 'Personal'),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  onSubmitted: (_) => _addTodoFromInput(),
                  decoration: const InputDecoration(
                    hintText: 'Add a new task...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addTodoFromInput,
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodoTile(Todo todo, int index) {
    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _deleteTodoAt(index),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          leading: InkWell(
            onTap: () => _toggleTodo(todo),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: todo.done
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: todo.done ? const Color(0xFF2563EB) : Colors.transparent,
              ),
              child: todo.done
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          title: Text(
            todo.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: todo.done
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF111827),
              decoration: todo.done ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            todo.category,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _editTodo(todo),
                icon: const Icon(Icons.edit_outlined),
                color: const Color(0xFF6B7280),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _deleteTodoAt(index),
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
          onTap: () => _toggleTodo(todo),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.inbox_rounded, size: 72, color: Color(0xFF2563EB)),
          SizedBox(height: 12),
          Text(
            'No tasks yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Add your first task to stay on top of your day.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showAddBottomSheet() {
    final controller = TextEditingController();
    String category = _selectedCategory == 'All'
        ? 'Personal'
        : _selectedCategory;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New task',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Business',
                      child: Text('Business'),
                    ),
                    DropdownMenuItem(
                      value: 'Personal',
                      child: Text('Personal'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      category = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'What do you need to do?',
                  ),
                  onSubmitted: (_) {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    _addTodo(text, categoryOverride: category);
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      _addTodo(text, categoryOverride: category);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Add task'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

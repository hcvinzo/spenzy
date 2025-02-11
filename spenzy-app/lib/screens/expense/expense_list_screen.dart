import 'package:flutter/material.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart';
import 'package:spenzy_app/services/expense_service.dart';
import 'package:spenzy_app/screens/expense/add_expense_screen.dart';
import 'package:spenzy_app/screens/expense/expense_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spenzy_app/utils/document_picker.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _expenseService = ExpenseService();
  final _scrollController = ScrollController();
  final List<Expense> _expenses = [];
  bool _isLoading = false;
  int _currentPage = 1;
  static const _pageSize = 20;
  bool _hasMore = true;
  late final DocumentPicker _documentPicker;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    _scrollController.addListener(_onScroll);
    _documentPicker = DocumentPicker(
      onLoadingChanged: (loading) => setState(() => _isLoading = loading),
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      },
      onDocumentProcessed: (response, file) async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddExpenseScreen(documentResponse: response),
          ),
        );

        if (result == true) {
          _refreshExpenses();
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final expenses = await _expenseService.listExpenses(
        page: _currentPage,
        pageSize: _pageSize,
        sortBy: 'expense_date',
        ascending: false,
      );

      setState(() {
        _expenses.addAll(expenses);
        _currentPage++;
        _hasMore = expenses.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expenses: $e')),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadExpenses();
    }
  }

  Future<void> _refreshExpenses() async {
    setState(() {
      _expenses.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    await _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshExpenses,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _expenses.length + (_isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _expenses.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final expense = _expenses[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(expense.vendorName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('MMM dd, yyyy').format(expense.expenseDate.toDateTime())),
                    if (expense.hasCategory()) Text(expense.category.name),
                    if (expense.tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: expense.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[800],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
                trailing: SizedBox(
                  width: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${expense.currency} ${expense.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: expense.isPaid ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          expense.isPaid ? 'Paid' : 'Unpaid',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExpenseDetailScreen(expense: expense),
                    ),
                  );
                  
                  if (result == true) {
                    _refreshExpenses();
                  }
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        spacing: 3,
        childPadding: const EdgeInsets.all(5),
        spaceBetweenChildren: 4,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.edit),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            label: 'Add Manually',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
              );
              if (result == true) {
                _refreshExpenses();
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.upload_file),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            label: 'Upload Document',
            onTap: _documentPicker.pickAndProcessFile,
          ),
          SpeedDialChild(
            child: const Icon(Icons.photo_library),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            label: 'Choose from Gallery',
            onTap: () => _documentPicker.pickAndProcessImage(ImageSource.gallery),
          ),
          SpeedDialChild(
            child: const Icon(Icons.camera_alt),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            label: 'Take Photo',
            onTap: () => _documentPicker.pickAndProcessImage(ImageSource.camera),
          ),
        ],
      ),
    );
  }
} 
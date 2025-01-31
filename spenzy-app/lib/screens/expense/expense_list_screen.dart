import 'package:flutter/material.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart';
import 'package:spenzy_app/services/expense_service.dart';
import 'package:spenzy_app/screens/expense/add_expense_screen.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    _scrollController.addListener(_onScroll);
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
                    Text(expense.category?.name ?? ''),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${expense.currency} ${expense.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (expense.isPaid)
                      const Chip(
                        label: Text('Paid'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                      )
                    else
                      const Chip(
                        label: Text('Unpaid'),
                        backgroundColor: Colors.orange,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                  ],
                ),
                onTap: () {
                  // TODO: Navigate to expense details
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
          if (result == true) {
            _refreshExpenses();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart';
import 'package:spenzy_app/services/expense_service.dart';
import 'package:spenzy_app/screens/expense/add_expense_screen.dart';
import 'package:spenzy_app/screens/expense/expense_detail_screen.dart';
import 'package:intl/intl.dart';
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
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
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
              color: const Color(0xFF2b2c34),
              shadowColor: Colors.black.withValues(alpha: 0.3),
              elevation: 10,
              child: ListTile(
                title: Text(expense.vendorName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        DateFormat('MMM dd, yyyy')
                            .format(expense.expenseDate.toDateTime()),
                        style: const TextStyle(color: Colors.white70)),
                    if (expense.hasCategory())
                      Text(expense.category.name,
                          style: const TextStyle(color: Colors.white70)),
                    if (expense.tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: expense.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2b2c34),
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
                  width: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${expense.currency} ${expense.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: const Color(0xFFce5e51),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                      builder: (context) =>
                          ExpenseDetailScreen(expense: expense),
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
    );
  }
}

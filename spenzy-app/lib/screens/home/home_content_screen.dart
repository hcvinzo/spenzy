import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart';
import 'package:spenzy_app/services/expense_service.dart';
import 'package:spenzy_app/screens/expense/add_expense_screen.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:intl/intl.dart';
import 'package:spenzy_app/utils/document_picker.dart';
import 'package:spenzy_app/screens/expense/expense_detail_screen.dart';
import 'package:spenzy_app/screens/expense/expense_list_screen.dart';

class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({super.key});

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final _expenseService = ExpenseService();
  late final DocumentPicker _documentPicker;
  bool _isLoading = true;
  List<Expense> _recentExpenses = [];
  double _totalIncome = 500.00; // TODO: Replace with actual income data
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
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
          _loadData();
        }
      },
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final expenses = await _expenseService.listExpenses(
        page: 1,
        pageSize: 5,
        sortBy: 'expense_date',
        ascending: false,
      );

      double total = 0;
      for (var expense in expenses) {
        if (expense.currency == 'USD') {
          total += expense.totalAmount;
        }
      }

      setState(() {
        _recentExpenses = expenses;
        _totalExpense = total;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSummaryCard(String title, String amount,
      {bool isIncome = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required String title,
    required String subtitle,
    required String amount,
    required IconData icon,
    required bool isIncome,
    required Expense expense,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseDetailScreen(expense: expense),
            ),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Text(
          amount,
          style: TextStyle(
            color: isIncome ? Colors.green : const Color(0xFFce5e51),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, Hakan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Good morning',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        centerTitle: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 24),

            // Monthly Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This month',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                            'income', '\$${_totalIncome.toStringAsFixed(2)}',
                            isIncome: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                            'expense', '\$${_totalExpense.toStringAsFixed(2)}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard('total',
                            '\$${(_totalIncome - _totalExpense).toStringAsFixed(2)}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recent Transactions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF2A2D3E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent transaction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ExpenseListScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'View all',
                          style: TextStyle(color: Color(0xFF39AE9A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_recentExpenses.isEmpty)
                    const Center(
                      child: Text(
                        'No recent transactions',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    Column(
                      children: _recentExpenses.map((expense) {
                        return _buildTransactionItem(
                          title: expense.vendorName,
                          subtitle: expense.hasCategory()
                              ? expense.category.name
                              : '',
                          amount:
                              '${expense.currency} ${expense.totalAmount.toStringAsFixed(2)}',
                          icon: Icons.receipt,
                          isIncome: false,
                          expense: expense,
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

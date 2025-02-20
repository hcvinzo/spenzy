import 'package:flutter/material.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart';
import 'package:spenzy_app/services/expense_service.dart';
import 'package:spenzy_app/screens/expense/expense_detail_screen.dart';
import 'package:spenzy_app/screens/expense/expense_list_screen.dart';

class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({super.key});

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final _expenseService = ExpenseService();
  bool _isLoading = true;
  List<Expense> _recentExpenses = [];
  double _totalIncome = 500.00; // TODO: Replace with actual income data
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
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
        color: const Color(0xFF2c2c34),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
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
        color: const Color(0xFF35353c),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
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
    Widget content = const Center(child: CircularProgressIndicator());

    if (!_isLoading) {
      content = Scaffold(
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
            physics: const AlwaysScrollableScrollPhysics(),
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
                          child: _buildSummaryCard('expense',
                              '\$${_totalExpense.toStringAsFixed(2)}'),
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
                padding: const EdgeInsets.all(16).copyWith(bottom: 150),
                decoration: const BoxDecoration(
                  color: Color(0xFF2c2c34),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
    return content;
  }
}

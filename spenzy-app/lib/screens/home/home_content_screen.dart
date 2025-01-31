import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart';
import 'package:spenzy_app/services/expense_service.dart';
import 'package:spenzy_app/screens/expense/add_expense_screen.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:intl/intl.dart';
import 'package:spenzy_app/utils/document_picker.dart';

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
  double _totalAmount = 0;
  int _totalExpenses = 0;

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
        if (expense.currency == 'USD') { // For simplicity, only counting USD
          total += expense.totalAmount;
        }
      }

      setState(() {
        _recentExpenses = expenses;
        _totalAmount = total;
        _totalExpenses = expenses.length;
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

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentExpenseItem(Expense expense) {
    return ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.receipt),
      ),
      title: Text(expense.vendorName),
      subtitle: Text(DateFormat('MMM dd, yyyy').format(expense.expenseDate.toDateTime())),
      trailing: Text(
        '${expense.currency} ${expense.totalAmount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
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
        title: const Text('Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Expenses',
                    _totalExpenses.toString(),
                    Icons.receipt_long,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Total Amount (USD)',
                    '\$${_totalAmount.toStringAsFixed(2)}',
                    Icons.attach_money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Recent Expenses',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_recentExpenses.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No recent expenses'),
                ),
              )
            else
              Card(
                child: Column(
                  children: _recentExpenses
                      .map((expense) => _buildRecentExpenseItem(expense))
                      .toList(),
                ),
              ),
          ],
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
                _loadData();
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
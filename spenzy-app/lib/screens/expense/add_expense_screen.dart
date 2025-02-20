import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart'
    as expense_pb;
import 'package:spenzy_app/providers/loading_provider.dart';
import 'package:spenzy_app/services/expense_service.dart';
import 'package:spenzy_app/services/document_service.dart';
import 'package:spenzy_app/generated/proto/google/protobuf/timestamp.pb.dart';
import 'package:spenzy_app/widgets/expense_form.dart';
import 'package:spenzy_app/widgets/loading_overlay.dart';

class AddExpenseScreen extends StatefulWidget {
  final DocumentResponse? documentResponse;

  const AddExpenseScreen({
    super.key,
    this.documentResponse,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _expenseService = ExpenseService();
  bool _isLoading = false;

  Future<void> _handleSave(Map<String, dynamic> formData) async {
    setState(() => _isLoading = true);

    // Show Loading Overlay while saving
    Provider.of<LoadingProvider>(context, listen: false).show();

    try {
      final request = expense_pb.CreateExpenseRequest()
        ..vendorName = formData['vendorName']
        ..totalAmount = formData['totalAmount']
        ..totalTax = formData['totalTax']
        ..expenseDate = Timestamp.fromDateTime(
            (formData['expenseDate'] as DateTime).toUtc())
        ..isPaid = formData['isPaid']
        ..currency = formData['currency'];

      final category = formData['category'] as expense_pb.Category?;
      if (category != null) {
        request.categoryId = category.id;
      }

      if (formData['isPaid']) {
        final paidOn = formData['paidOn'] as DateTime?;
        request.paidOn =
            Timestamp.fromDateTime((paidOn ?? DateTime.now()).toUtc());
      }

      final dueDate = formData['dueDate'] as DateTime?;
      if (dueDate != null) {
        request.dueDate = Timestamp.fromDateTime(dueDate.toUtc());
      }

      final tags = formData['tags'] as List<expense_pb.Tag>;
      request.tagIds.addAll(tags.map((t) => t.id));

      final response = await _expenseService.createExpense(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating expense: $e')),
        );
        Navigator.pop(context, false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // Hide Loading Overlay after saving
        Provider.of<LoadingProvider>(context, listen: false).hide();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Create a pre-filled expense object if we have document response
    expense_pb.Expense? prefilledExpense;
    if (widget.documentResponse != null) {
      final doc = widget.documentResponse!;
      final expenseDate = doc.invoiceDate.isNotEmpty
          ? DateFormat('yyyy-MM-dd').parse(doc.invoiceDate)
          : DateTime.now();

      prefilledExpense = expense_pb.Expense()
        ..vendorName = doc.vendorName
        ..totalAmount = doc.dueAmountValue
        ..totalTax = doc.totalTaxValue
        ..expenseDate = Timestamp.fromDateTime(expenseDate)
        ..currency = doc.currency;
    }

    return Stack(children: [
      Scaffold(
        backgroundColor: const Color(0xFF212029),
        appBar: AppBar(
          title: const Text('Add Expense'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ExpenseForm(
            expense: prefilledExpense,
            isEditing: true,
            onSave: _handleSave,
          ),
        ),
      ),
      const LoadingOverlay(),
    ]);
  }
}

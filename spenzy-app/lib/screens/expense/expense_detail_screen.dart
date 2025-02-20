import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart';
import 'package:spenzy_app/services/category_service.dart';
import 'package:spenzy_app/services/expense_service.dart';
import 'package:spenzy_app/generated/proto/google/protobuf/timestamp.pb.dart';
import 'package:spenzy_app/widgets/tag_input.dart';
import 'package:spenzy_app/widgets/expense_form.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final Expense expense;

  const ExpenseDetailScreen({
    super.key,
    required this.expense,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final _expenseService = ExpenseService();
  bool _isLoading = false;
  bool _isEditing = false;

  Future<void> _handleSave(Map<String, dynamic> formData) async {
    setState(() => _isLoading = true);

    try {
      final request = UpdateExpenseRequest()..id = widget.expense.id;

      if (formData['vendorName'] != widget.expense.vendorName) {
        request.vendorName = formData['vendorName'];
      }

      final newAmount = formData['totalAmount'] as double;
      if (newAmount != widget.expense.totalAmount) {
        request.totalAmount = newAmount;
      }

      final newTax = formData['totalTax'] as double;
      if (newTax != widget.expense.totalTax) {
        request.totalTax = newTax;
      }

      final newDate = formData['expenseDate'] as DateTime;
      if (newDate != widget.expense.expenseDate.toDateTime()) {
        request.expenseDate = Timestamp.fromDateTime(newDate.toUtc());
      }

      final newCategory = formData['category'] as Category?;
      if (newCategory?.id != widget.expense.category.id) {
        request.categoryId = newCategory?.id ?? 0;
      }

      final newCurrency = formData['currency'] as String;
      if (newCurrency != widget.expense.currency) {
        request.currency = newCurrency;
      }

      final newIsPaid = formData['isPaid'] as bool;
      if (newIsPaid != widget.expense.isPaid) {
        request.isPaid = newIsPaid;
      }

      // Handle paid on date
      final newPaidOn = formData['paidOn'] as DateTime?;
      if (newIsPaid) {
        request.paidOn =
            Timestamp.fromDateTime((newPaidOn ?? DateTime.now()).toUtc());
      } else if (widget.expense.hasPaidOn()) {
        request.paidOn = Timestamp.fromDateTime(
            DateTime.fromMillisecondsSinceEpoch(0).toUtc());
      }

      // Handle due date
      final newDueDate = formData['dueDate'] as DateTime?;
      if (newDueDate != null &&
          (!widget.expense.hasDueDate() ||
              newDueDate != widget.expense.dueDate.toDateTime())) {
        request.dueDate = Timestamp.fromDateTime(newDueDate.toUtc());
      } else if (widget.expense.hasDueDate() && newDueDate == null) {
        request.dueDate = Timestamp.fromDateTime(
            DateTime.fromMillisecondsSinceEpoch(0).toUtc());
      }

      // Handle tags
      final newTags = formData['tags'] as List<Tag>;
      final currentTagIds = widget.expense.tags.map((t) => t.id).toList();
      final newTagIds = newTags.map((t) => t.id).toList();
      if (!_areListsEqual(currentTagIds, newTagIds)) {
        request.tagIds.addAll(newTagIds);
      }

      final response = await _expenseService.updateExpense(request);

      if (mounted) {
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense updated successfully')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Failed to update expense: ${response.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating expense: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
      }
    }
  }

  bool _areListsEqual(List<int> list1, List<int> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  Future<void> _deleteExpense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await _expenseService.deleteExpense(widget.expense.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting expense: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

    return Scaffold(
      backgroundColor: const Color(0xFF212029),
      appBar: AppBar(
        title: const Text('Expense Detail'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteExpense,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _isEditing
            ? ExpenseForm(
                expense: widget.expense,
                isEditing: true,
                onSave: _handleSave,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header card with category and amount
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2b2c34),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.expense.vendorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.expense.hasCategory()
                                    ? widget.expense.category.name
                                    : 'Uncategorized',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expense details
                  _buildDetailSection(
                    'Expense Date',
                    DateFormat('dd MMM yyyy')
                        .format(widget.expense.expenseDate.toDateTime()),
                  ),
                  const SizedBox(height: 24),
                  _buildDetailSection(
                    'Amount',
                    '${widget.expense.currency} ${widget.expense.totalAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 24),
                  _buildDetailSection(
                    'Tax',
                    '${widget.expense.currency} ${widget.expense.totalTax.toStringAsFixed(2)}',
                  ),
                  if (widget.expense.isPaid) ...[
                    const SizedBox(height: 24),
                    _buildDetailSection(
                      'Paid On',
                      widget.expense.hasPaidOn()
                          ? DateFormat('dd MMM yyyy')
                              .format(widget.expense.paidOn.toDateTime())
                          : 'Not set',
                    ),
                  ],
                  if (widget.expense.hasDueDate()) ...[
                    const SizedBox(height: 24),
                    _buildDetailSection(
                      'Due Date',
                      DateFormat('dd MMM yyyy')
                          .format(widget.expense.dueDate.toDateTime()),
                    ),
                  ],
                  if (widget.expense.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Tags',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.expense.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            tag.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

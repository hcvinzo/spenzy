import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart';
import 'package:spenzy_app/services/category_service.dart';
import 'package:spenzy_app/services/expense_service.dart';
import 'package:spenzy_app/generated/proto/google/protobuf/timestamp.pb.dart';
import 'package:spenzy_app/widgets/tag_input.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _expenseService = ExpenseService();
  final _categoryService = CategoryService();
  bool _isLoading = false;
  bool _isEditing = false;

  // Form controllers
  late final TextEditingController _vendorNameController;
  late final TextEditingController _totalAmountController;
  late final TextEditingController _totalTaxController;
  late DateTime _expenseDate;
  late bool _isPaid;
  late DateTime? _paidOn;
  late DateTime? _dueDate;
  late String _selectedCurrency;
  late Category? _selectedCategory;
  List<Category> _categories = [];
  List<Tag> _selectedTags = [];

  final List<String> _currencies = ['USD', 'EUR', 'TL'];

  @override
  void initState() {
    super.initState();
    _initializeFormData();
    _loadCategories();
  }

  void _initializeFormData() {
    _vendorNameController = TextEditingController(text: widget.expense.vendorName);
    _totalAmountController = TextEditingController(text: widget.expense.totalAmount.toString());
    _totalTaxController = TextEditingController(text: widget.expense.totalTax.toString());
    _expenseDate = widget.expense.expenseDate.toDateTime();
    _isPaid = widget.expense.isPaid;
    _paidOn = widget.expense.hasPaidOn() ? widget.expense.paidOn.toDateTime() : null;
    _dueDate = widget.expense.hasDueDate() ? widget.expense.dueDate.toDateTime() : null;
    _selectedCurrency = widget.expense.currency;
    _selectedCategory = widget.expense.hasCategory() ? widget.expense.category : null;
    _selectedTags = List.from(widget.expense.tags);
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.listCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          // Find matching category from loaded categories
          if (_selectedCategory != null) {
            _selectedCategory = categories.firstWhere(
              (cat) => cat.id == _selectedCategory!.id,
              orElse: () => categories.first,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, String dateType) async {
    DateTime initialDate;
    DateTime lastDate;

    switch (dateType) {
      case 'expense':
        initialDate = _expenseDate;
        lastDate = DateTime.now();
        break;
      case 'paid':
        initialDate = _paidOn ?? DateTime.now();
        lastDate = DateTime.now();
        break;
      case 'due':
        initialDate = _dueDate ?? DateTime.now();
        lastDate = DateTime(2100);  // Allow future dates for due date
        break;
      default:
        return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: lastDate,
    );

    if (picked != null && mounted) {
      setState(() {
        switch (dateType) {
          case 'expense':
            _expenseDate = picked;
            break;
          case 'paid':
            _paidOn = picked;
            break;
          case 'due':
            _dueDate = picked;
            break;
        }
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final request = UpdateExpenseRequest()
        ..id = widget.expense.id;

      // Only set fields that have changed
      if (_vendorNameController.text != widget.expense.vendorName) {
        request.vendorName = _vendorNameController.text;
      }

      final newAmount = double.parse(_totalAmountController.text);
      if (newAmount != widget.expense.totalAmount) {
        request.totalAmount = newAmount;
      }

      final newTax = double.parse(_totalTaxController.text);
      if (newTax != widget.expense.totalTax) {
        request.totalTax = newTax;
      }

      if (_expenseDate != widget.expense.expenseDate.toDateTime()) {
        request.expenseDate = Timestamp.fromDateTime(_expenseDate.toUtc());
      }

      if (_selectedCategory?.id != widget.expense.category.id) {
        request.categoryId = _selectedCategory?.id ?? 0;
      }

      if (_selectedCurrency != widget.expense.currency) {
        request.currency = _selectedCurrency;
      }

      if (_isPaid != widget.expense.isPaid) {
        request.isPaid = _isPaid;
      }

      // Handle paid on date
      if (_isPaid) {
        // When expense is marked as paid, set the paid_on date
        request.paidOn = Timestamp.fromDateTime((_paidOn ?? DateTime.now()).toUtc());
      } else if (widget.expense.hasPaidOn()) {
        // When expense is marked as unpaid and it had a paid_on date, explicitly set it to null
        request.paidOn = Timestamp.fromDateTime(DateTime.fromMillisecondsSinceEpoch(0).toUtc());
      }

      // Handle due date
      if (_dueDate != null && (!widget.expense.hasDueDate() || _dueDate != widget.expense.dueDate.toDateTime())) {
        request.dueDate = Timestamp.fromDateTime(_dueDate!.toUtc());
      } else if (widget.expense.hasDueDate() && _dueDate == null) {
        // When due date is removed, explicitly set it to null
        request.dueDate = Timestamp.fromDateTime(DateTime.fromMillisecondsSinceEpoch(0).toUtc());
      }

      // Handle tags
      final currentTagIds = widget.expense.tags.map((t) => t.id).toList();
      final newTagIds = _selectedTags.map((t) => t.id).toList();
      if (!_areListsEqual(currentTagIds, newTagIds)) {
        request.tagIds.addAll(newTagIds);
      }

      final response = await _expenseService.updateExpense(request);
      
      if (mounted) {
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense updated successfully')),
          );
          Navigator.pop(context, true); // Return true to indicate update
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update expense: ${response.errorMessage}')),
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
        setState(() => _isLoading = false);
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
        Navigator.pop(context, true); // Return true to indicate update
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
  void dispose() {
    _vendorNameController.dispose();
    _totalAmountController.dispose();
    _totalTaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          if (!_isEditing) IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isLoading ? null : _deleteExpense,
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isLoading
                ? null
                : () {
                    if (_isEditing) {
                      _saveExpense();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _vendorNameController,
                      decoration: const InputDecoration(
                        labelText: 'Vendor Name',
                      ),
                      enabled: _isEditing,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter vendor name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _totalAmountController,
                            decoration: const InputDecoration(
                              labelText: 'Total Amount',
                            ),
                            enabled: _isEditing,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter amount';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _totalTaxController,
                            decoration: const InputDecoration(
                              labelText: 'Total Tax',
                            ),
                            enabled: _isEditing,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter tax amount';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCurrency,
                            decoration: const InputDecoration(
                              labelText: 'Currency',
                            ),
                            items: _currencies.map((String currency) {
                              return DropdownMenuItem<String>(
                                value: currency,
                                child: Text(currency),
                              );
                            }).toList(),
                            onChanged: _isEditing
                                ? (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedCurrency = newValue;
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<Category>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem<Category>(
                                value: category,
                                child: Text(category.name),
                              );
                            }).toList(),
                            onChanged: _isEditing
                                ? (Category? newValue) {
                                    setState(() {
                                      _selectedCategory = newValue;
                                    });
                                  }
                                : null,
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a category';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Expense Date'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(_expenseDate),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _isEditing ? () => _selectDate(context, 'expense') : null,
                    ),
                    if (_isPaid)
                      ListTile(
                        title: const Text('Payment Date'),
                        subtitle: Text(
                          _paidOn != null
                              ? DateFormat('yyyy-MM-dd').format(_paidOn!)
                              : 'Not set',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _isEditing ? () => _selectDate(context, 'paid') : null,
                      ),
                    ListTile(
                      title: const Text('Due Date'),
                      subtitle: Text(
                        _dueDate != null
                            ? DateFormat('yyyy-MM-dd').format(_dueDate!)
                            : 'Not set',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _isEditing ? () => _selectDate(context, 'due') : null,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Paid'),
                      value: _isPaid,
                      onChanged: _isEditing
                          ? (bool value) {
                              setState(() {
                                _isPaid = value;
                                if (!value) {
                                  _paidOn = null;
                                } else if (_paidOn == null) {
                                  _paidOn = DateTime.now();
                                }
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TagInput(
                      initialTags: _selectedTags,
                      enabled: _isEditing,
                      onTagsChanged: (tags) {
                        setState(() {
                          _selectedTags = tags;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 
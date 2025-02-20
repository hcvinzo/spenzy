import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart';
import 'package:spenzy_app/services/category_service.dart';
import 'package:spenzy_app/widgets/tag_input.dart';

class ExpenseForm extends StatefulWidget {
  final Expense? expense;
  final bool isEditing;
  final Function(Map<String, dynamic>) onSave;

  const ExpenseForm({
    super.key,
    this.expense,
    required this.isEditing,
    required this.onSave,
  });

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _categoryService = CategoryService();

  // Form controllers
  late final TextEditingController _vendorNameController;
  late final TextEditingController _totalAmountController;
  late final TextEditingController _totalTaxController;
  late DateTime _expenseDate;
  late bool _isPaid;
  DateTime? _paidOn;
  DateTime? _dueDate;
  late String _selectedCurrency;
  Category? _selectedCategory;
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
    final expense = widget.expense;
    _vendorNameController =
        TextEditingController(text: expense?.vendorName ?? '');
    _totalAmountController =
        TextEditingController(text: (expense?.totalAmount ?? 0.0).toString());
    _totalTaxController =
        TextEditingController(text: (expense?.totalTax ?? 0.0).toString());
    _expenseDate = expense?.expenseDate.toDateTime() ?? DateTime.now();
    _isPaid = expense?.isPaid ?? false;
    _paidOn =
        expense?.hasPaidOn() == true ? expense!.paidOn.toDateTime() : null;
    _dueDate =
        expense?.hasDueDate() == true ? expense!.dueDate.toDateTime() : null;
    _selectedCurrency = expense?.currency ?? 'USD';
    _selectedCategory =
        expense?.hasCategory() == true ? expense!.category : null;
    _selectedTags = expense?.tags.toList() ?? [];
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.listCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
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
        lastDate = DateTime(2100);
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

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final formData = {
      'vendorName': _vendorNameController.text,
      'totalAmount': double.parse(_totalAmountController.text),
      'totalTax': double.parse(_totalTaxController.text),
      'expenseDate': _expenseDate,
      'isPaid': _isPaid,
      'paidOn': _paidOn,
      'dueDate': _dueDate,
      'currency': _selectedCurrency,
      'category': _selectedCategory,
      'tags': _selectedTags,
    };

    widget.onSave(formData);
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Vendor Name'),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2b2c34),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: _vendorNameController,
              enabled: widget.isEditing,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter vendor name';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildLabel('Amount'),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2b2c34),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: _totalAmountController,
              enabled: widget.isEditing,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
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
          const SizedBox(height: 24),
          _buildLabel('Tax'),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2b2c34),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: _totalTaxController,
              enabled: widget.isEditing,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
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
          const SizedBox(height: 24),
          _buildLabel('Category'),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2b2c34),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<Category>(
              value: _selectedCategory,
              style: const TextStyle(color: Colors.white),
              dropdownColor: const Color(0xFF2b2c34),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem<Category>(
                  value: category,
                  child: Text(
                    category.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: widget.isEditing
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
          const SizedBox(height: 24),
          _buildLabel('Currency'),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2b2c34),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedCurrency,
              style: const TextStyle(color: Colors.white),
              dropdownColor: const Color(0xFF2b2c34),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              items: _currencies.map((String currency) {
                return DropdownMenuItem<String>(
                  value: currency,
                  child: Text(
                    currency,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: widget.isEditing
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
          const SizedBox(height: 24),
          _buildLabel('Expense Date'),
          GestureDetector(
            onTap:
                widget.isEditing ? () => _selectDate(context, 'expense') : null,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2b2c34),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(_expenseDate),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Icon(Icons.calendar_today, color: Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2b2c34),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile(
              title: const Text(
                'Paid',
                style: TextStyle(color: Colors.white),
              ),
              value: _isPaid,
              onChanged: widget.isEditing
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
          ),
          if (_isPaid) ...[
            const SizedBox(height: 24),
            _buildLabel('Payment Date'),
            GestureDetector(
              onTap:
                  widget.isEditing ? () => _selectDate(context, 'paid') : null,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2b2c34),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _paidOn != null
                          ? DateFormat('dd MMM yyyy').format(_paidOn!)
                          : 'Not set',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildLabel('Due Date'),
          GestureDetector(
            onTap: widget.isEditing ? () => _selectDate(context, 'due') : null,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2b2c34),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dueDate != null
                        ? DateFormat('dd MMM yyyy').format(_dueDate!)
                        : 'Not set',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Icon(Icons.calendar_today, color: Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildLabel('Tags'),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2b2c34),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: TagInput(
              initialTags: _selectedTags,
              enabled: widget.isEditing,
              onTagsChanged: (tags) {
                setState(() {
                  _selectedTags = tags;
                });
              },
            ),
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _handleSave,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF39AE9A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

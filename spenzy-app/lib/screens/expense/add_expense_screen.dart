import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart' as expense_pb;
import 'package:spenzy_app/generated/proto/document/document.pb.dart';
import 'package:spenzy_app/services/expense_service.dart';
import 'package:spenzy_app/services/document_service.dart';
import 'package:spenzy_app/generated/proto/google/protobuf/timestamp.pb.dart';
import 'package:spenzy_app/utils/document_picker.dart';
import 'package:spenzy_app/services/category_service.dart';
import 'package:spenzy_app/widgets/tag_input.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _expenseService = ExpenseService();
  final _categoryService = CategoryService();
  DocumentPicker? _documentPicker;
  bool _isLoading = false;
  bool _isInitializing = true;
  File? _selectedFile;

  // Form fields
  final _vendorNameController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _totalTaxController = TextEditingController();
  expense_pb.Category? _selectedCategory;
  String _selectedCurrency = 'USD';
  bool _isPaid = false;
  DateTime _expenseDate = DateTime.now();
  DateTime? _paidOn;
  DateTime? _dueDate;
  List<expense_pb.Tag> _selectedTags = [];

  final List<String> _currencies = ['USD', 'EUR', 'TL'];
  List<expense_pb.Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      await _loadCategories();
      
      _documentPicker = DocumentPicker(
        onLoadingChanged: (loading) => setState(() => _isLoading = loading),
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        },
        onDocumentProcessed: (response, file) {
          setState(() => _selectedFile = file);
          _fillFormWithDocumentData(response);
        },
      );
      
      if (widget.documentResponse != null) {
        _fillFormWithDocumentData(widget.documentResponse!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
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

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.listCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          if (categories.isNotEmpty) {
            _selectedCategory = categories.first;
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

  void _fillFormWithDocumentData(DocumentResponse response) {
    setState(() {
      _vendorNameController.text = response.vendorName;
      _totalAmountController.text = response.dueAmountValue.toString();
      _totalTaxController.text = response.totalTaxValue.toString();
      
      debugPrint('Document suggested category: ${response.category}');
      
      // Try to find category by name from document
      if (response.category.isNotEmpty && _categories.isNotEmpty) {
        
        debugPrint('Available categories: ${_categories.map((c) => c.name).join(', ')}');
        
        // First try exact match
        try {
          _selectedCategory = _categories.firstWhere(
            (category) => category.name.toLowerCase() == response.category.toLowerCase(),
          );
          debugPrint('Found exact category match: ${_selectedCategory!.name}');
        } catch (e) {
          // If no exact match, try partial match
          try {
            _selectedCategory = _categories.firstWhere(
              (category) => 
                category.name.toLowerCase().contains(response.category.toLowerCase()) ||
                response.category.toLowerCase().contains(category.name.toLowerCase()),
            );
            debugPrint('Found partial category match: ${_selectedCategory!.name}');
          } catch (e) {
            // If no match at all, use the first category
            _selectedCategory = _categories.first;
            debugPrint('No matching category found, using first category: ${_selectedCategory!.name}');
          }
        }
      } else {
        // If no category from document or no categories available
        _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
        debugPrint('Using default category: ${_selectedCategory?.name ?? 'none'}');
      }
      
      if (_currencies.contains(response.currency)) {
        _selectedCurrency = response.currency;
      }
      if (response.invoiceDate.isNotEmpty) {
        try {
          _expenseDate = DateFormat('yyyy-MM-dd').parse(response.invoiceDate);
        } catch (e) {
          debugPrint('Failed to parse invoice date: ${response.invoiceDate}');
        }
      }
      if (response.dueDate.isNotEmpty) {
        try {
          _dueDate = DateFormat('yyyy-MM-dd').parse(response.dueDate);
        } catch (e) {
          debugPrint('Failed to parse due date: ${response.dueDate}');
        }
      }
      _isPaid = response.isPaid;
      if (_isPaid) {
        _paidOn = _expenseDate;
      }
    });
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = expense_pb.CreateExpenseRequest(
        expenseDate: Timestamp.fromDateTime(_expenseDate),
        vendorName: _vendorNameController.text,
        totalAmount: double.parse(_totalAmountController.text),
        totalTax: double.parse(_totalTaxController.text),
        categoryId: _selectedCategory?.id ?? 0,
        currency: _selectedCurrency,
        isPaid: _isPaid,
        paidOn: _isPaid && _paidOn != null ? Timestamp.fromDateTime(_paidOn!) : null,
        dueDate: _dueDate != null ? Timestamp.fromDateTime(_dueDate!) : null,
      );

      // Add tags
      request.tagIds.addAll(_selectedTags.map((tag) => tag.id).toList());

      await _expenseService.createExpense(request);
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _documentPicker == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveExpense,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedFile == null)
                      _documentPicker!.buildDocumentPickerRow()
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Image.file(
                                _selectedFile!,
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Document uploaded',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    TextButton(
                                      onPressed: _documentPicker!.pickAndProcessFile,
                                      child: const Text('Change document'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _vendorNameController,
                      decoration: const InputDecoration(
                        labelText: 'Vendor Name',
                        border: OutlineInputBorder(),
                      ),
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
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Amount',
                              border: OutlineInputBorder(),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _totalTaxController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tax Amount',
                              border: OutlineInputBorder(),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<expense_pb.Category>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                      ),
                      items: _currencies.map((currency) {
                        return DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCurrency = value ?? 'USD';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Expense Date'),
                      subtitle: Text(
                        '${_expenseDate.year}-${_expenseDate.month}-${_expenseDate.day}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _expenseDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _expenseDate = date;
                          });
                        }
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Paid'),
                      value: _isPaid,
                      onChanged: (value) {
                        setState(() {
                          _isPaid = value;
                          if (!value) {
                            _paidOn = null;
                          }
                        });
                      },
                    ),
                    if (_isPaid)
                      ListTile(
                        title: const Text('Payment Date'),
                        subtitle: Text(
                          _paidOn != null
                              ? '${_paidOn!.year}-${_paidOn!.month}-${_paidOn!.day}'
                              : 'Not set',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _paidOn ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _paidOn = date;
                            });
                          }
                        },
                      ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Due Date'),
                      subtitle: Text(
                        _dueDate != null
                            ? '${_dueDate!.year}-${_dueDate!.month}-${_dueDate!.day}'
                            : 'Not set',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),  // Allow future dates for due date
                        );
                        if (date != null) {
                          setState(() {
                            _dueDate = date;
                          });
                        }
                      },
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
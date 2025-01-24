import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spenzy/generated/expense.pb.dart';
import 'package:spenzy/generated/document.pb.dart';
import 'package:spenzy/services/expense_service.dart';
import 'package:spenzy/services/document_service.dart';
import 'package:google/protobuf/timestamp.pb.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _expenseService = ExpenseService();
  final _documentService = DocumentService();
  bool _isLoading = false;
  File? _selectedFile;

  // Form fields
  final _vendorNameController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _totalTaxController = TextEditingController();
  final _categoryController = TextEditingController();
  String _selectedCurrency = 'USD';
  bool _isPaid = false;
  DateTime _expenseDate = DateTime.now();
  DateTime? _paidOn;

  final List<String> _currencies = ['USD', 'EUR', 'TRY'];
  final List<String> _categories = ['Office', 'Travel', 'Meals', 'Supplies', 'Other'];

  @override
  void dispose() {
    _vendorNameController.dispose();
    _totalAmountController.dispose();
    _totalTaxController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
        });
        
        // Upload and parse document
        final response = await _documentService.parseDocument(
          file: _selectedFile!,
          fileName: image.name,
        );
        
        // Fill form with parsed data
        _fillFormWithDocumentData(response);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing document: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _fillFormWithDocumentData(DocumentResponse response) {
    setState(() {
      _vendorNameController.text = response.vendorName;
      _totalAmountController.text = response.totalAmount.toString();
      _totalTaxController.text = response.totalTax.toString();
      if (_categories.contains(response.category)) {
        _categoryController.text = response.category;
      }
      if (_currencies.contains(response.currency)) {
        _selectedCurrency = response.currency;
      }
      if (response.hasDate()) {
        _expenseDate = response.date.toDateTime();
      }
    });
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = CreateExpenseRequest(
        expenseDate: Timestamp.fromDateTime(_expenseDate),
        vendorName: _vendorNameController.text,
        totalAmount: double.parse(_totalAmountController.text),
        totalTax: double.parse(_totalTaxController.text),
        category: _categoryController.text,
        currency: _selectedCurrency,
        isPaid: _isPaid,
        paidOn: _isPaid && _paidOn != null ? Timestamp.fromDateTime(_paidOn!) : null,
      );

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
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
                      ElevatedButton.icon(
                        onPressed: _pickDocument,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Document'),
                      )
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
                                      onPressed: _pickDocument,
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
                    DropdownButtonFormField<String>(
                      value: _categoryController.text.isEmpty ? null : _categoryController.text,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _categoryController.text = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
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
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveExpense,
                      child: const Text('Save Expense'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 
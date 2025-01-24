import 'package:flutter/material.dart';
import 'package:spenzy_app/services/document_service.dart';

class DocumentResultScreen extends StatelessWidget {
  final DocumentResponse result;

  const DocumentResultScreen({Key? key, required this.result}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Analysis Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultCard(
              'Document Type',
              result.documentType,
              Icons.description,
            ),
            _buildResultCard(
              'Language',
              result.language,
              Icons.language,
            ),
            _buildResultCard(
              'Currency',
              result.currency,
              Icons.attach_money,
            ),
            _buildResultCard(
              'Vendor',
              result.vendorName,
              Icons.store,
            ),
            _buildResultCard(
              'Customer',
              result.customerName,
              Icons.person,
            ),
            _buildResultCard(
              'Date',
              result.invoiceDate,
              Icons.calendar_today,
            ),
            _buildResultCard(
              'Amount Due',
              result.dueAmount,
              Icons.payment,
            ),
            _buildResultCard(
              'Total Tax',
              result.totalTax,
              Icons.receipt_long,
            ),
            _buildResultCard(
              'Category',
              result.category,
              Icons.category,
            ),
            const SizedBox(height: 16),
            const Text(
              'Raw Text:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.rawText,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(value),
      ),
    );
  }
} 
import 'dart:io';
import 'dart:convert';
import 'package:grpc/grpc.dart';
import 'package:path/path.dart' as path;
import 'package:spenzy_app/generated/proto/document/document.pbgrpc.dart' as document;
import 'auth_service.dart';
import 'service_auth.dart';

class DocumentResponse {
  final String documentType;
  final String language;
  final String currency;
  final String vendorName;
  final String customerName;
  final String invoiceDate;
  final String dueAmount;
  final String totalTax;
  final String category;
  final String rawText;
  final bool success;
  final String errorMessage;
  final bool isPaid;

  DocumentResponse({
    required this.documentType,
    required this.language,
    required this.currency,
    required this.vendorName,
    required this.customerName,
    required this.invoiceDate,
    required this.dueAmount,
    required this.totalTax,
    required this.category,
    required this.rawText,
    required this.success,
    required this.errorMessage,
    required this.isPaid,
  });

  // Helper methods to convert string amounts to numbers
  double get dueAmountValue => double.tryParse(dueAmount.replaceAll(',', '.')) ?? 0.0;
  double get totalTaxValue => double.tryParse(totalTax.replaceAll(',', '.')) ?? 0.0;

  factory DocumentResponse.fromProto(dynamic response) {
    if (response is document.ParseDocumentResponse) {
      return DocumentResponse(
        documentType: response.documentType,
        language: response.language,
        currency: response.currency,
        vendorName: response.vendorName,
        customerName: response.customerName,
        invoiceDate: response.invoiceDate,
        dueAmount: response.dueAmount,
        totalTax: response.totalTax,
        category: response.category,
        rawText: response.rawText,
        success: response.success,
        errorMessage: response.errorMessage,
        isPaid: response.isPaid,
      );
    } else if (response is document.ParseDocumentTextResponse) {
      return DocumentResponse(
        documentType: response.documentType,
        language: response.language,
        currency: response.currency,
        vendorName: response.vendorName,
        customerName: response.customerName,
        invoiceDate: response.invoiceDate,
        dueAmount: response.dueAmount,
        totalTax: response.totalTax,
        category: response.category,
        rawText: '',  // ParseDocumentTextResponse doesn't have rawText
        success: response.success,
        errorMessage: response.errorMessage,
        isPaid: response.isPaid,
      );
    } else {
      throw ArgumentError('Unsupported response type: ${response.runtimeType}');
    }
  }
}

class DocumentService {
  static final DocumentService _instance = DocumentService._internal();
  factory DocumentService() => _instance;

  DocumentService._internal() {
    _channel = ClientChannel(
      ServiceAuth.grpcHost,
      port: ServiceAuth.documentServicePort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    _client = document.DocumentServiceClient(_channel);
  }

  late final ClientChannel _channel;
  late final document.DocumentServiceClient _client;
  final _serviceAuth = ServiceAuth();

  Future<void> dispose() async {
    await _channel.shutdown();
  }

  Future<DocumentResponse> parseDocument({
    required File file,
    required String fileName,
  }) async {
    try {
      print('DocumentService.parseDocument - Starting document parsing');
      print('- File name: $fileName');
      print('- File size: ${await file.length()} bytes');
      print('- File path: ${file.path}');
      print('- File absolute path: ${file.absolute.path}');
      print('- File extension: ${path.extension(fileName).toLowerCase()}');

      final token = await _serviceAuth.getServiceToken('spenzy-document.service');
      if (token == null) throw Exception('Not authenticated');
      print('- Authentication token obtained');

      final bytes = await file.readAsBytes();
      print('- File bytes read successfully: ${bytes.length} bytes');
      print('- First 20 bytes (hex): ${bytes.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
      // Validate bytes are not empty or corrupted
      if (bytes.isEmpty) {
        throw Exception('File bytes are empty');
      }

      // For PDF files, check for PDF signature
      if (fileName.toLowerCase().endsWith('.pdf')) {
        final pdfSignature = '%PDF-';
        final firstBytes = String.fromCharCodes(bytes.take(5));
        print('- PDF signature check: ${firstBytes == pdfSignature ? 'valid' : 'invalid'} (found: $firstBytes)');
        if (firstBytes != pdfSignature) {
          throw Exception('Invalid PDF file format');
        }
      }
      
      final request = document.ParseDocumentRequest()
        ..fileContent = bytes
        ..fileName = fileName;
      print('- gRPC request created');
      print('- Request details:');
      print('  - File name: ${request.fileName}');
      print('  - Content length: ${request.fileContent.length}');
      print('  - Content type: ${request.fileContent.runtimeType}');
        
      try {
        print('- Sending gRPC request to document service...');
        print('  - Service host: ${ServiceAuth.grpcHost}');
        print('  - Service port: ${ServiceAuth.documentServicePort}');
        final response = await _client.parseDocument(
          request,
          options: CallOptions(
            metadata: {'authorization': 'Bearer $token'},
            timeout: const Duration(seconds: 30),
          ),
        );
        print('- Received gRPC response');
        print('- Response details:');
        print('  - Success: ${response.success}');
        print('  - Error message: ${response.errorMessage}');
        print('  - Document type: ${response.documentType}');
        
        if (!response.success) {
          throw Exception(response.errorMessage);
        }
        
        return DocumentResponse.fromProto(response);
      } catch (grpcError) {
        print('- gRPC call failed with error:');
        print('  - Error type: ${grpcError.runtimeType}');
        print('  - Error details: $grpcError');
        if (grpcError is GrpcError) {
          print('  - gRPC code: ${grpcError.code}');
          print('  - gRPC codeName: ${grpcError.codeName}');
          print('  - gRPC message: ${grpcError.message}');
          print('  - gRPC trailers: ${grpcError.trailers}');
        }
        rethrow;
      }
    } catch (e) {
      print('DocumentService.parseDocument - Failed with error:');
      print('- Error type: ${e.runtimeType}');
      print('- Error message: $e');
      throw Exception('Failed to parse document: $e');
    }
  }

  Future<Stream<List<int>>> getDocumentFile(String fileId) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-document.service');
      if (token == null) throw Exception('Not authenticated');

      final request = document.GetDocumentRequest()
        ..fileId = fileId;
        
      final response = await _client.getDocumentFile(
        request,
        options: CallOptions(metadata: {'authorization': 'Bearer $token'}),
      );

      return response.map((chunk) => chunk.content);
    } catch (e) {
      throw Exception('Failed to get document file: $e');
    }
  }

  Future<DocumentResponse> parseDocumentText(String text) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-document.service');
      if (token == null) throw Exception('Not authenticated');

      final request = document.ParseDocumentTextRequest()
        ..text = text;
        
      final response = await _client.parseDocumentText(
        request,
        options: CallOptions(metadata: {'authorization': 'Bearer $token'}),
      );
      return DocumentResponse.fromProto(response);
    } catch (e) {
      throw Exception('Failed to parse document text: $e');
    }
  }
} 
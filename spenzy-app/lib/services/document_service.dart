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
  });

  factory DocumentResponse.fromProto(document.ParseDocumentResponse response) {
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
    );
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

  Future<List<document.Document>> listDocuments() async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-document.service');
      if (token == null) throw Exception('Not authenticated');

      final request = document.ListDocumentsRequest();
      final response = await _client.listDocuments(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );
      return response.documents;
    } catch (e) {
      throw Exception('Failed to list documents: $e');
    }
  }

  Future<document.Document> createDocument(String filePath) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-document.service');
      if (token == null) throw Exception('Not authenticated');

      final request = document.CreateDocumentRequest()
        ..filePath = filePath;

      final response = await _client.createDocument(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );
      return response.document;
    } catch (e) {
      throw Exception('Failed to create document: $e');
    }
  }

  Future<void> deleteDocument(String id) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-document.service');
      if (token == null) throw Exception('Not authenticated');

      final request = document.DeleteDocumentRequest()
        ..id = id;

      await _client.deleteDocument(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  Future<DocumentResponse> parseDocument(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final fileName = path.basename(filePath);
    
    final request = document.ParseDocumentRequest()
      ..fileContent = bytes
      ..fileName = fileName;
      
    final response = await _client.parseDocument(
      request,
      options: CallOptions(metadata: {'authorization': 'Bearer $token'}),
    );
    return DocumentResponse.fromProto(response);
  }

  Future<List<int>> getDocumentFile(String fileId) async {
    final request = document.GetDocumentFileRequest()
      ..fileId = fileId;
      
    final token = await _serviceAuth.getServiceToken('spenzy-document.service');
    
    final response = await _client.getDocumentFile(
      request,
      options: CallOptions(metadata: {'authorization': 'Bearer $token'}),
    );
    return response.fileContent;
  }

  Future<DocumentResponse> parseDocumentText(String text) async {
    final request = document.ParseDocumentTextRequest()
      ..text = text;
      
    final token = await _serviceAuth.getServiceToken('spenzy-document.service');
    
    final response = await _client.parseDocumentText(
      request,
      options: CallOptions(metadata: {'authorization': 'Bearer $token'}),
    );
    return DocumentResponse.fromProto(response);
  }
} 
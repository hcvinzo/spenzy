import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spenzy_app/services/document_service.dart';

class DocumentPicker {
  final DocumentService _documentService;
  final Function(bool) onLoadingChanged;
  final Function(String) onError;
  final Function(DocumentResponse, File) onDocumentProcessed;

  DocumentPicker({
    DocumentService? documentService,
    required this.onLoadingChanged,
    required this.onError,
    required this.onDocumentProcessed,
  }) : _documentService = documentService ?? DocumentService();

  Future<void> pickAndProcessFile() async {
    onLoadingChanged(true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      
      if (result != null) {
        final file = File(result.files.single.path!);
        
        // Upload and parse document
        final response = await _documentService.parseDocument(
          file: file,
          fileName: result.files.single.name,
        );
        
        onDocumentProcessed(response, file);
      }
    } catch (e) {
      onError('Error processing document: $e');
    } finally {
      onLoadingChanged(false);
    }
  }

  Future<void> pickAndProcessImage(ImageSource source) async {
    onLoadingChanged(true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        final file = File(image.path);
        
        // Upload and parse document
        final response = await _documentService.parseDocument(
          file: file,
          fileName: image.name,
        );
        
        onDocumentProcessed(response, file);
      }
    } catch (e) {
      onError('Error processing document: $e');
    } finally {
      onLoadingChanged(false);
    }
  }

  Widget buildDocumentPickerRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: pickAndProcessFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => pickAndProcessImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => pickAndProcessImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ),
      ],
    );
  }
} 
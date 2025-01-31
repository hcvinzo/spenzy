import grpc
import logging
import json
import tempfile
import os
import base64
import magic
from proto import document_pb2
from proto import document_pb2_grpc
from spenzy_common.middleware.auth_interceptor import AuthInterceptor
from app.services.document_parser import perform_ocr, process_with_openai, save_ocr_result, process_document

CHUNK_SIZE = 1024 * 1024  # 1MB chunks for file streaming

class DocumentService(document_pb2_grpc.DocumentServiceServicer):
    """
    Service for processing and analyzing documents using OCR and AI.
    """
    
    def ParseDocument(self, request, context):
        """
        Process and analyze a document file.
        """
        temp_file_path = None
        try:
            # Detect file type from content
            file_content = request.file_content
            try:
                file_ext = self._detect_file_type(file_content)
            except ValueError as e:
                return document_pb2.ParseDocumentResponse(
                    success=False,
                    error_message=str(e)
                )

            # Create a temporary file with proper extension
            with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file_ext}") as temp_file:
                temp_file.write(file_content)
                temp_file_path = temp_file.name

            # First perform OCR to get the text
            text = perform_ocr(temp_file_path)
            if not text:
                return document_pb2.ParseDocumentResponse(
                    success=False,
                    error_message="Failed to extract text from document"
                )

            # Then process with OpenAI, passing the context
            ai_response, usage_data = process_with_openai(text, context)
            if not ai_response:
                return document_pb2.ParseDocumentResponse(
                    success=False,
                    error_message="Failed to process text with OpenAI"
                )

            # Save OCR results with original file name
            try:
                save_ocr_result(request.file_name, text, ai_response, usage_data)
            except Exception as e:
                logging.warning(f"Failed to save OCR result: {e}")
                # Continue even if saving fails

            # Parse AI response
            try:
                analysis_dict = json.loads(ai_response)
            except json.JSONDecodeError as e:
                return document_pb2.ParseDocumentResponse(
                    success=False,
                    error_message=f"Failed to parse AI response: {str(e)}"
                )

            # Create response
            return document_pb2.ParseDocumentResponse(
                document_type=analysis_dict.get('type', 'n/a'),
                language=analysis_dict.get('language', ''),
                currency=analysis_dict.get('currency', ''),
                vendor_name=analysis_dict.get('vendor', ''),
                customer_name=analysis_dict.get('customer', ''),
                invoice_date=analysis_dict.get('date', ''),
                due_amount=str(analysis_dict.get('amount', '')),
                total_tax=str(analysis_dict.get('tax', '')),
                category=analysis_dict.get('category', ''),
                raw_text=text,  # Use the OCR text here
                is_paid=analysis_dict.get('paid', False),
                success=True,
                error_message=''
            )

        except Exception as e:
            logging.error(f"Error in ParseDocument: {str(e)}")
            return document_pb2.ParseDocumentResponse(
                success=False,
                error_message=str(e)
            )
        finally:
            # Clean up the temporary file
            if temp_file_path and os.path.exists(temp_file_path):
                try:
                    os.unlink(temp_file_path)
                except Exception as e:
                    logging.warning(f"Failed to remove temporary file {temp_file_path}: {e}")
                    # Don't raise the exception as this is just cleanup

    def GetDocumentFile(self, request, context):
        """
        Stream a document file back to the client.
        """
        try:
            # Get file path based on document_id
            file_path = self._get_document_file_path(request.document_id)
            if not os.path.exists(file_path):
                raise ValueError(f"Document file not found for ID: {request.document_id}")

            file_name = os.path.basename(file_path)
            file_type = os.path.splitext(file_name)[1][1:]  # Get extension without dot

            # Stream file in chunks
            with open(file_path, 'rb') as f:
                while True:
                    chunk = f.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    yield document_pb2.FileChunk(
                        content=chunk,
                        file_name=file_name,
                        file_type=file_type,
                        success=True,
                        error_message=''
                    )

        except Exception as e:
            logging.error(f"Error in GetDocumentFile: {str(e)}")
            yield document_pb2.FileChunk(
                content=b"",
                success=False,
                error_message=str(e)
            )

    def ParseDocumentText(self, request, context):
        """
        Analyze document text directly.
        """
        try:
            # Process with OpenAI, passing the context
            ai_analysis, usage_data = process_with_openai(request.text, context)
            if not ai_analysis:
                raise ValueError("Failed to analyze the text")

            # Save results with a generic name since we don't have a file
            save_ocr_result(f"text_analysis_{context.user_id}", request.text, ai_analysis, usage_data)

            # Parse AI response
            analysis_dict = json.loads(ai_analysis)

            # Create response
            return document_pb2.ParseDocumentTextResponse(
                document_type=analysis_dict.get('type', ''),
                language=analysis_dict.get('language', ''),
                currency=analysis_dict.get('currency', ''),
                vendor_name=analysis_dict.get('vendor', ''),
                customer_name=analysis_dict.get('customer', ''),
                invoice_date=analysis_dict.get('date', ''),
                due_amount=analysis_dict.get('amount', ''),
                total_tax=analysis_dict.get('tax', ''),
                category=analysis_dict.get('category', ''),
                success=True,
                error_message=''
            )

        except Exception as e:
            logging.error(f"Error in ParseDocumentText: {str(e)}")
            return document_pb2.ParseDocumentTextResponse(
                success=False,
                error_message=str(e)
            )

    def _detect_file_type(self, file_content):
        """
        Detect file type from file content using python-magic.
        Returns the appropriate file extension.
        """
        mime = magic.Magic(mime=True)
        mime_type = mime.from_buffer(file_content)
        
        # Map MIME types to file extensions
        mime_to_ext = {
            'application/pdf': 'pdf',
            'image/jpeg': 'jpg',
            'image/png': 'png',
            'image/tiff': 'tiff',
            'image/bmp': 'bmp'
        }
        
        ext = mime_to_ext.get(mime_type)
        if not ext:
            raise ValueError(f"Unsupported file type: {mime_type}")
            
        return ext

    def _get_document_file_path(self, document_id):
        """
        Get the file path for a given document ID.
        You should implement your own logic to map document IDs to file paths.
        """
        # This is a simple example. In a real application, you might:
        # - Query a database to get the file path
        # - Use a more sophisticated file storage system
        return os.path.join("datas", f"document_{document_id}") 
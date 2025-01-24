import os
from PIL import Image
import pytesseract
from openai import OpenAI
from dotenv import load_dotenv
from pdf2image import convert_from_path

# Load environment variables
load_dotenv()

# Configure OpenAI API key
OpenAI.api_key = os.getenv('OPENAI_API_KEY')
client = OpenAI();

# Configure directories
DATA_DIR = "datas"
OCR_DIR = os.path.join(DATA_DIR, "ocr_results")

# Configure OCR languages - this will use multiple languages for better accuracy
# eng (English), tur (Turkish), fra (French), deu (German), spa (Spanish), 
# ara (Arabic), rus (Russian), chi_sim (Simplified Chinese), jpn (Japanese)
OCR_LANGUAGES = 'eng+tur+fra+deu+spa+ara+rus+chi_sim+jpn'

def convert_pdf_to_images(pdf_path):
    """
    Convert PDF file to a list of PIL Images.
    """
    try:
        return convert_from_path(pdf_path)
    except Exception as e:
        print(f"Error converting PDF: {str(e)}")
        return None

def perform_ocr_on_image(image):
    """
    Perform OCR on a single image and return the extracted text.
    Uses multiple languages for better accuracy.
    """
    try:
        # Perform OCR with multiple languages
        text = pytesseract.image_to_string(image, lang=OCR_LANGUAGES,config='--psm 6')
        return text.strip()
    except Exception as e:
        print(f"Error performing OCR: {str(e)}")
        if "Invalid language" in str(e):
            print("\nError: Some language packs are not installed for Tesseract.")
            print("Please install additional language packs using one of the following methods:")
            print("\nFor macOS:")
            print("1. brew install tesseract-lang")
            print("\nFor Ubuntu/Debian:")
            print("1. sudo apt-get install tesseract-ocr-all")
            print("\nFor Windows:")
            print("1. Download the language data files (*.traineddata)")
            print("2. Place them in the Tesseract tessdata directory")
        return None

def perform_ocr(file_path):
    """
    Perform OCR on the given file (image or PDF) and return the extracted text.
    """
    try:
        # Check if file is PDF
        if file_path.lower().endswith('.pdf'):
            print("Processing PDF file...")
            images = convert_pdf_to_images(file_path)            
            if not images:
                return None
            
            # Process each page
            all_text = []
            for i, image in enumerate(images, 1):
                print(f"Processing page {i}...")
                text = perform_ocr_on_image(image)
                if text:
                    all_text.append(f"--- Page {i} ---\n{text}")
            
            return "\n\n".join(all_text)
        else:
            # Process single image
            image = Image.open(file_path)
            return perform_ocr_on_image(image)
            
    except Exception as e:
        print(f"Error processing file: {str(e)}")
        return None

def process_with_openai(text):
    """
    Send the extracted text to OpenAI API for processing.
    OpenAI can automatically detect and handle multiple languages.
    Returns a tuple of (analysis_json, usage_data)
    """
    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": """extract information from invoice data.
                 answer these questions in json format.
                 Type of document (invoice,bill or receipt) as type.n/a if none of them.
                 language of document as language,currency as currency,vendor name as vendor,customer name as customer,
                 invoice date as date,due amount as amount,total tax as tax and category. 
                 categories are Groceries,Restaurants,Electricity,Communication,Water,Gas/Fuel,
                 Clothing,Medical/Healthcare,Houshold Item/Supplies, Personal, Education,
                 Entertainment and Others"""},
                {"role": "user", "content": text}
            ],
            response_format={
                "type": "json_object"
            }
        )
        
        # Extract token usage data
        usage_data = {
            "prompt_tokens": response.usage.prompt_tokens,
            "completion_tokens": response.usage.completion_tokens,
            "total_tokens": response.usage.total_tokens,
            "model": response.model
        }
        
        return response.choices[0].message.content, usage_data
    except Exception as e:
        print(f"Error processing with OpenAI: {str(e)}")
        return None, None

def save_ocr_result(file_name, text, ai_response, usage_data=None):
    """
    Save OCR and AI response results to a file.
    """
    base_name = os.path.splitext(file_name)[0]
    output_path = os.path.join(OCR_DIR, f"{base_name}.ocr")
    
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write("=== OCR EXTRACTED TEXT ===\n")
            f.write("=" * 50 + "\n")
            f.write(text)
            f.write("\n\n")
            f.write("=== OPENAI ANALYSIS ===\n")
            f.write("=" * 50 + "\n")
            f.write(ai_response if ai_response else "No AI analysis available")
            if usage_data:
                f.write("\n\n")
                f.write("=== OPENAI TOKEN USAGE ===\n")
                f.write("=" * 50 + "\n")
                f.write(f"Model: {usage_data['model']}\n")
                f.write(f"Prompt Tokens: {usage_data['prompt_tokens']}\n")
                f.write(f"Completion Tokens: {usage_data['completion_tokens']}\n")
                f.write(f"Total Tokens: {usage_data['total_tokens']}\n")
        print(f"\nResults saved to: {output_path}")
    except Exception as e:
        print(f"Error saving results: {str(e)}")
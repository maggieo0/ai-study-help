import functions_framework
from flask import jsonify
import vertexai
from vertexai.generative_models import GenerativeModel
import PyPDF2
import io
import json
import os

# Initialize Vertex AI
PROJECT_ID = os.environ.get('GCP_PROJECT_ID', 'your-project-id')
LOCATION = 'us-central1'

vertexai.init(project=PROJECT_ID, location=LOCATION)

# Initialize Gemini model
model = GenerativeModel('gemini-1.5-flash')

@functions_framework.http
def generate(request):
    """
    HTTP Cloud Function to generate study materials from text or PDF.
    """
    # Enable CORS
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)

    headers = {
        'Access-Control-Allow-Origin': '*'
    }

    try:
        # Extract content from request
        content = ''
        material_type = 'flashcards'

        if request.content_type and 'multipart/form-data' in request.content_type:
            # Handle PDF upload
            file = request.files.get('file')
            material_type = request.form.get('materialType', 'flashcards')
            
            if file:
                content = extract_text_from_pdf(file)
        else:
            # Handle JSON text input
            request_json = request.get_json(silent=True)
            if request_json:
                content = request_json.get('text', '')
                material_type = request_json.get('materialType', 'flashcards')

        if not content or len(content.strip()) < 50:
            return jsonify({
                'error': 'Content too short. Please provide more study material.'
            }), 400, headers

        # Generate materials based on type
        if material_type == 'flashcards':
            materials = generate_flashcards(content)
        else:
            materials = generate_questions(content)

        return jsonify({
            'success': True,
            'materials': materials,
            'materialType': material_type
        }), 200, headers

    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({
            'error': 'Failed to generate materials. Please try again.'
        }), 500, headers


def extract_text_from_pdf(file):
    """Extract text from uploaded PDF file."""
    try:
        pdf_reader = PyPDF2.PdfReader(io.BytesIO(file.read()))
        text = ''
        for page in pdf_reader.pages:
            text += page.extract_text() + '\n'
        return text
    except Exception as e:
        print(f"PDF extraction error: {str(e)}")
        raise Exception("Could not read PDF file")


def generate_flashcards(content):
    """Generate flashcards using Gemini."""
    prompt = f"""You are a study assistant. Based on the following study material, create exactly 10 flashcards that will help a student learn the key concepts.

Study Material:
{content[:4000]}  

Instructions:
- Create 10 flashcards with clear, concise terms and definitions
- Focus on the most important concepts, terms, and ideas
- Make definitions clear and educational
- Return ONLY a valid JSON array with this exact format:

[
  {{"term": "concept or term", "definition": "clear explanation"}},
  {{"term": "another concept", "definition": "another explanation"}}
]

Return only the JSON array, no other text."""

    try:
        response = model.generate_content(prompt)
        text = response.text.strip()
        
        # Extract JSON from response
        if '```json' in text:
            text = text.split('```json')[1].split('```')[0].strip()
        elif '```' in text:
            text = text.split('```')[1].split('```')[0].strip()
        
        flashcards = json.loads(text)
        
        # Validate format
        if isinstance(flashcards, list) and len(flashcards) > 0:
            return flashcards[:10]  # Limit to 10 cards
        else:
            raise Exception("Invalid flashcard format")
            
    except Exception as e:
        print(f"Flashcard generation error: {str(e)}")
        # Return fallback flashcards
        return [
            {"term": "Study Tip", "definition": "There was an error generating flashcards. Please try again with different content."}
        ]


def generate_questions(content):
    """Generate multiple choice questions using Gemini."""
    prompt = f"""You are a study assistant. Based on the following study material, create exactly 8 multiple choice questions to test understanding.

Study Material:
{content[:4000]}

Instructions:
- Create 8 multiple choice questions
- Each question should have 4 options (A, B, C, D)
- Make questions challenging but fair
- Ensure correct answers are accurate
- Return ONLY a valid JSON array with this exact format:

[
  {{
    "question": "What is...?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0
  }}
]

The correctIndex is 0 for A, 1 for B, 2 for C, 3 for D.
Return only the JSON array, no other text."""

    try:
        response = model.generate_content(prompt)
        text = response.text.strip()
        
        # Extract JSON from response
        if '```json' in text:
            text = text.split('```json')[1].split('```')[0].strip()
        elif '```' in text:
            text = text.split('```')[1].split('```')[0].strip()
        
        questions = json.loads(text)
        
        # Validate format
        if isinstance(questions, list) and len(questions) > 0:
            return questions[:8]  # Limit to 8 questions
        else:
            raise Exception("Invalid question format")
            
    except Exception as e:
        print(f"Question generation error: {str(e)}")
        # Return fallback question
        return [
            {
                "question": "There was an error generating questions. Please try again.",
                "options": ["Try again", "Check content", "Verify format", "Contact support"],
                "correctIndex": 0
            }
        ]

import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from ultralytics import YOLO
import torch
from PIL import Image
from io import BytesIO
import requests
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS

# Load the trained YOLO model
model_path = 'model.pt'
model = YOLO(model_path)

# Initialize Firebase
cred = credentials.Certificate('firebase-key.json')
firebase_admin.initialize_app(cred)

# Initialize Firestore DB
db = firestore.client()

def is_offensive(predictions):
    offensive_classes = ['adult', 'racism', 'substance', 'violence', 'weapons']
    for pred in predictions:
        if model.names[int(pred.cls)] in offensive_classes and float(pred.conf) > 0.5:
            return True
    return False

# https://www.derek.com/predict
@app.route('/predict', methods=['POST'])
def predict():
    data = request.get_json()

    # Get the image URL
    if 'url' not in data:
        return jsonify({"error": "Missing 'url' parameter"}), 400

    url = data['url']
    
    print(f"attempting to read image from {url}")

    try:
        # Download the image
        response = requests.get(url)
        response.raise_for_status()
        print("image downloaded")

        # Check the content type of the image
        content_type = response.headers['Content-Type']
        print(content_type)
        if 'image' not in content_type:
            return jsonify({"error": "Invalid image"}), 400

        with open('test.jpg', 'wb') as f:
            f.write(response.content)
        print("image saved")

        # Read the image file
        img = Image.open(BytesIO(response.content))
        
        # Perform prediction
        results = model([img])

        # Extract predictions
        predictions = results[0].boxes  # Assuming 'results[0].boxes' contains the bounding boxes and labels

        # Prepare response
        response = {
            "predictions": []
        }

        for pred in predictions:
            response["predictions"].append({
                "class": model.names[int(pred.cls)],  # Class name
                "confidence": float(pred.conf),  # Confidence score
            })

        return jsonify(response), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
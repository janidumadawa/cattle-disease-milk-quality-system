
CATTLE DISEASE CLASSIFICATION + GRAD-CAM
========================================

Files:
- cattle_disease_classifier.keras : trained classifier
- labels.json                     : class label order
- gradcam_function.py             : Grad-CAM function source

Input:
- RGB image, resized to 224 x 224
- Pixel values in the range 0-255
- Do not divide input values by 255 for this model.

Usage in Google Colab:
1. Load the classifier with tensorflow.keras.models.load_model.
2. Load labels.json.
3. Run the Grad-CAM function after initializing its dependencies.
4. Pass an actual cattle image path to generate the heatmap.

Important:
Grad-CAM highlights regions influencing the prediction.
It does not guarantee an exact lesion boundary or diagnosis.

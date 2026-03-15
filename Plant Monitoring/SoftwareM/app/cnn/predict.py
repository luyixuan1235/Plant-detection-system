import torch
import torch.nn as nn
from torchvision import transforms, models
from PIL import Image
import os
import random

# ==========================================
# 1. Basic Configuration
# ==========================================
# Path to the test dataset (your local cleaned 'test' folder)
TEST_DIR = r"D:\SoftwareM\PlantDoc-Dataset-master\test"
# Path to the model weights file
MODEL_PATH = r"D:\SoftwareM\app\cnn\plant_disease_cnn.pth"

# List of class names (MUST match exactly what was printed during training, 28 classes in total)
CLASS_NAMES = [
    'Apple Scab Leaf', 'Apple leaf', 'Apple rust leaf', 'Bell_pepper leaf', 
    'Bell_pepper leaf spot', 'Blueberry leaf', 'Cherry leaf', 'Corn Gray leaf spot', 
    'Corn leaf blight', 'Corn rust leaf', 'Peach leaf', 'Potato leaf early blight', 
    'Potato leaf late blight', 'Raspberry leaf', 'Soyabean leaf', 'Squash Powdery mildew leaf', 
    'Strawberry leaf', 'Tomato Early blight leaf', 'Tomato Septoria leaf spot', 'Tomato leaf', 
    'Tomato leaf bacterial spot', 'Tomato leaf late blight', 'Tomato leaf mosaic virus', 
    'Tomato leaf yellow virus', 'Tomato mold leaf', 'Tomato two spotted spider mites leaf', 
    'grape leaf', 'grape leaf black rot'
]
NUM_CLASSES = len(CLASS_NAMES)

# Automatically detect device (CPU is usually sufficient for local testing)
device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")

# ==========================================
# 2. Data Preprocessing Pipeline
# ==========================================
# Must be exactly the same as the 'test' transform used during training
data_transform = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

# ==========================================
# 3. Load the Model
# ==========================================
print("Loading model...")
model = models.resnet18(weights=None) # No need to download pre-trained weights for testing
num_ftrs = model.fc.in_features
model.fc = nn.Linear(num_ftrs, NUM_CLASSES)

# Load your trained .pth file (map_location ensures it runs even without a GPU)
model.load_state_dict(torch.load(MODEL_PATH, map_location=device))
model = model.to(device)
model.eval() # CRITICAL: Switch model to evaluation mode (disables Dropout and BatchNorm updates)

# ==========================================
# 4. Pick a Random Test Image
# ==========================================
def get_random_image_path(base_dir):
    # Get all disease category folders
    categories = [d for d in os.listdir(base_dir) if os.path.isdir(os.path.join(base_dir, d))]
    # Randomly select a disease category
    random_category = random.choice(categories)
    category_path = os.path.join(base_dir, random_category)
    
    # Randomly select an image within this category
    images = [f for f in os.listdir(category_path) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
    if not images:
        return get_random_image_path(base_dir) # If the folder is empty, pick again
        
    random_image = random.choice(images)
    image_path = os.path.join(category_path, random_image)
    
    return image_path, random_category # Return the image path and its true label

# ==========================================
# 5. Execute Prediction
# ==========================================
image_path, true_label = get_random_image_path(TEST_DIR)
print(f"\n--- Starting Test ---")
print(f"Randomly selected image path: {image_path}")
print(f"True category: {true_label}")

# Open the image and apply preprocessing
image = Image.open(image_path).convert('RGB')
input_tensor = data_transform(image)
input_batch = input_tensor.unsqueeze(0) # Add a batch dimension (the model expects a batch input)
input_batch = input_batch.to(device)

# Disable gradient calculation (no backprop needed for inference, saves memory and speeds up)
with torch.no_grad():
    output = model(input_batch)
    # Get the index of the highest probability
    _, predicted_idx = torch.max(output, 1)
    
    predicted_label = CLASS_NAMES[predicted_idx.item()]

print(f"-> CNN Model Prediction: {predicted_label}")

if predicted_label.replace("_", " ") == true_label.replace("_", " "):
    print("✅ Prediction Correct!")
else:
    print("❌ Prediction Incorrect.")

print("\n(This predicted string will be used as the input parameter for the subsequent API call)")
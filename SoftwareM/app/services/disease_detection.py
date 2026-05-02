import torch
import torch.nn as nn
from torchvision import transforms, models
from PIL import Image
from app.core.config import settings

class DiseaseDetector:
    def __init__(self):
        self.device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
        self.class_names = [
            'Apple Scab Leaf', 'Apple leaf', 'Apple rust leaf', 'Bell_pepper leaf',
            'Bell_pepper leaf spot', 'Blueberry leaf', 'Cherry leaf', 'Corn Gray leaf spot',
            'Corn leaf blight', 'Corn rust leaf', 'Peach leaf', 'Potato leaf early blight',
            'Potato leaf late blight', 'Raspberry leaf', 'Soyabean leaf', 'Squash Powdery mildew leaf',
            'Strawberry leaf', 'Tomato Early blight leaf', 'Tomato Septoria leaf spot', 'Tomato leaf',
            'Tomato leaf bacterial spot', 'Tomato leaf late blight', 'Tomato leaf mosaic virus',
            'Tomato leaf yellow virus', 'Tomato mold leaf', 'Tomato two spotted spider mites leaf',
            'grape leaf', 'grape leaf black rot'
        ]
        self.num_classes = len(self.class_names)
        self.model = None
        self.transform = transforms.Compose([
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ])

    def _load_model(self):
        model = models.resnet18(weights=None)
        num_ftrs = model.fc.in_features
        model.fc = nn.Linear(num_ftrs, self.num_classes)
        model.load_state_dict(torch.load(settings.model_path, map_location=self.device, weights_only=True))
        model = model.to(self.device)
        model.eval()
        return model

    def predict(self, image_path: str):
        if self.model is None:
            self.model = self._load_model()

        image = Image.open(image_path).convert('RGB')
        input_tensor = self.transform(image)
        input_batch = input_tensor.unsqueeze(0).to(self.device)

        with torch.no_grad():
            output = self.model(input_batch)
            probabilities = torch.nn.functional.softmax(output, dim=1)
            confidence, predicted_idx = torch.max(probabilities, 1)

            predicted_label = self.class_names[predicted_idx.item()]
            confidence_score = confidence.item()

        # Check if the leaf is diseased (contains disease keywords)
        disease_keywords = ['scab', 'rust', 'spot', 'blight', 'mildew', 'bacterial', 'mosaic', 'virus', 'mold', 'mites', 'rot']
        is_diseased = any(disease in predicted_label.lower() for disease in disease_keywords)

        return {
            "disease_name": predicted_label,
            "is_diseased": is_diseased,
            "confidence": confidence_score
        }

# Global instance
disease_detector = DiseaseDetector()

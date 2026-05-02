from __future__ import annotations

import os
from pathlib import Path

import torch
import torch.nn as nn
from PIL import Image
from torchvision import models, transforms


class DiseaseDetector:
	def __init__(self) -> None:
		self.device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
		self.class_names = [
			"Apple Scab Leaf", "Apple leaf", "Apple rust leaf", "Bell_pepper leaf",
			"Bell_pepper leaf spot", "Blueberry leaf", "Cherry leaf", "Corn Gray leaf spot",
			"Corn leaf blight", "Corn rust leaf", "Peach leaf", "Potato leaf early blight",
			"Potato leaf late blight", "Raspberry leaf", "Soyabean leaf", "Squash Powdery mildew leaf",
			"Strawberry leaf", "Tomato Early blight leaf", "Tomato Septoria leaf spot", "Tomato leaf",
			"Tomato leaf bacterial spot", "Tomato leaf late blight", "Tomato leaf mosaic virus",
			"Tomato leaf yellow virus", "Tomato mold leaf", "Tomato two spotted spider mites leaf",
			"grape leaf", "grape leaf black rot",
		]
		self.model = None
		self.transform = transforms.Compose([
			transforms.Resize(256),
			transforms.CenterCrop(224),
			transforms.ToTensor(),
			transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
		])

	def _model_path(self) -> Path:
		env_path = os.getenv("MODEL_PATH")
		if env_path:
			# If relative path, resolve from SoftwareM directory
			p = Path(env_path)
			if not p.is_absolute():
				base = Path(__file__).resolve().parents[4] / "SoftwareM"
				return base / env_path
			return p

		# Fallback to default path
		project_root = Path(__file__).resolve().parents[4]
		return project_root / "SoftwareM" / "app" / "cnn" / "plant_disease_cnn.pth"

	def _load_model(self):
		model_path = self._model_path()
		if not model_path.exists():
			raise FileNotFoundError(model_path)

		model = models.resnet18(weights=None)
		num_ftrs = model.fc.in_features
		model.fc = nn.Linear(num_ftrs, len(self.class_names))
		model.load_state_dict(torch.load(model_path, map_location=self.device, weights_only=True))
		model = model.to(self.device)
		model.eval()
		return model

	def predict(self, image_path: str | Path) -> dict:
		if self.model is None:
			self.model = self._load_model()

		image = Image.open(image_path).convert("RGB")
		input_tensor = self.transform(image)
		input_batch = input_tensor.unsqueeze(0).to(self.device)

		with torch.no_grad():
			output = self.model(input_batch)
			probabilities = torch.nn.functional.softmax(output, dim=1)
			confidence, predicted_idx = torch.max(probabilities, 1)

		predicted_label = self.class_names[predicted_idx.item()]
		disease_keywords = [
			"scab", "rust", "spot", "blight", "mildew", "bacterial",
			"mosaic", "virus", "mold", "mites", "rot",
		]

		return {
			"disease_name": predicted_label,
			"is_diseased": any(keyword in predicted_label.lower() for keyword in disease_keywords),
			"confidence": confidence.item(),
		}


disease_detector = DiseaseDetector()

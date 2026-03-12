import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models
import os

DATA_DIR = "/root/autodl-tmp/PlantDoc-Dataset-master"
TRAIN_DIR = os.path.join(DATA_DIR, "train")
TEST_DIR = os.path.join(DATA_DIR, "test")

BATCH_SIZE = 32
EPOCHS = 50  

def safe_file_check(path):
    if not path.lower().endswith(('.png', '.jpg', '.jpeg')): return False
    if len(os.path.abspath(path)) >= 245: return False
    return os.path.exists(path)

def main():
    device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
    print(f"Beginning and use {device}")

    
    data_transforms = {
        'train': transforms.Compose([
            transforms.RandomResizedCrop(224, scale=(0.7, 1.0)), 
            transforms.RandomHorizontalFlip(), 
            transforms.RandomVerticalFlip(),  
            transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2), 
            transforms.RandomRotation(15),     
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]) 
        ]),
        'test': transforms.Compose([
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ]),
    }

    image_datasets = {
        'train': datasets.ImageFolder(TRAIN_DIR, transform=data_transforms['train'], is_valid_file=safe_file_check),
        'test': datasets.ImageFolder(TEST_DIR, transform=data_transforms['test'], is_valid_file=safe_file_check)
    }

    dataloaders = {
        'train': torch.utils.data.DataLoader(image_datasets['train'], batch_size=BATCH_SIZE, shuffle=True, num_workers=8),
        'test': torch.utils.data.DataLoader(image_datasets['test'], batch_size=BATCH_SIZE, shuffle=False, num_workers=8)
    }
    
    num_classes = len(image_datasets['train'].classes)

    model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
    num_ftrs = model.fc.in_features
    model.fc = nn.Linear(num_ftrs, num_classes)
    model = model.to(device)

    criterion = nn.CrossEntropyLoss()
    
    optimizer = optim.Adam(model.parameters(), lr=1e-4, weight_decay=1e-4) 
    scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=15, gamma=0.5)

    print("Beginning...")
    for epoch in range(EPOCHS):
        print(f'Epoch {epoch+1}/{EPOCHS}')
        print('-' * 10)

        for phase in ['train', 'test']:
            if phase == 'train':
                model.train()  
            else:
                model.eval()   

            running_loss = 0.0
            running_corrects = 0

            for inputs, labels in dataloaders[phase]:
                inputs = inputs.to(device)
                labels = labels.to(device)

                optimizer.zero_grad()

                with torch.set_grad_enabled(phase == 'train'):
                    outputs = model(inputs)
                    _, preds = torch.max(outputs, 1)
                    loss = criterion(outputs, labels)

                    if phase == 'train':
                        loss.backward()
                        optimizer.step()

                running_loss += loss.item() * inputs.size(0)
                running_corrects += torch.sum(preds == labels.data)

            epoch_loss = running_loss / len(image_datasets[phase])
            epoch_acc = running_corrects.double() / len(image_datasets[phase])

            print(f'{phase.capitalize()} Loss: {epoch_loss:.4f} Acc: {epoch_acc:.4f}')
        
        scheduler.step()

    print("Finish")
    save_path = "/root/autodl-tmp/plant_disease_cnn_v2.pth"
    torch.save(model.state_dict(), save_path)
    print(f"Saved to: {save_path}")

if __name__ == '__main__':
    main()
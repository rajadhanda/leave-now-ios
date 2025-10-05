import torch
from transformers import CLIPProcessor, CLIPModel

class CLIPModelWrapper:
    def __init__(self):
        self.model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
        self.processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")

    def encode_image(self, image):
        # Always process as a list for batching
        if not isinstance(image, list):
            image = [image]
        # Resize all images to 224x224
        image = [img.resize((224, 224)) for img in image]
        inputs = self.processor(images=image, return_tensors="pt", padding=True)
        image_features = self.model.get_image_features(**inputs)
        return image_features

    def encode_text(self, text):
        inputs = self.processor(text=text, return_tensors="pt", padding=True)
        text_features = self.model.get_text_features(**inputs)
        return text_features

    def compute_similarity(self, image_features, text_features):
        similarity = torch.nn.functional.cosine_similarity(image_features, text_features)
        return similarity 
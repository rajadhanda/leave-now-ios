from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os
from fastapi.responses import FileResponse
from app.models.clip_model import CLIPModelWrapper
from PIL import Image
import pyheif
import io
import numpy as np
import faiss
import pickle

app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

PHOTOS_DIR = os.path.join(os.path.dirname(__file__), 'photos')
INDEX_FILE = os.path.join(os.path.dirname(__file__), 'photos.index')
index = None
filenames = []
os.makedirs(PHOTOS_DIR, exist_ok=True)

clip_model = CLIPModelWrapper()

@app.post("/upload/")
async def upload_photo(file: UploadFile = File(...)):
    file_location = os.path.join(PHOTOS_DIR, file.filename)
    with open(file_location, "wb") as f:
        f.write(await file.read())
    return {"filename": file.filename}

@app.post("/build-index/")
async def build_index():
    global index, filenames
    features_list = []
    filenames = []
    for filename in os.listdir(PHOTOS_DIR):
        file_path = os.path.join(PHOTOS_DIR, filename)
        try:
            if filename.lower().endswith(".heic"):
                heif_file = pyheif.read(file_path)
                image = Image.frombytes(
                    heif_file.mode, heif_file.size, heif_file.data, "raw"
                )
            else:
                image = Image.open(file_path).convert("RGB")
            feat = clip_model.encode_image(image)[0].numpy()
            features_list.append(feat)
            filenames.append(filename)
        except Exception:
            continue
    if features_list:
        features = np.vstack(features_list).astype('float32')
        d = features.shape[1]
        index = faiss.IndexFlatL2(d)
        index.add(features)
        with open(INDEX_FILE, 'wb') as f:
            pickle.dump((index, filenames), f)
    return {"indexed": len(filenames)}

@app.get("/search/")
async def search_photos(query: str):
    global index, filenames
    # Load index if not yet loaded
    if index is None:
        with open(INDEX_FILE, 'rb') as f:
            index, filenames = pickle.load(f)
    # Encode the query and search
    q_feat = clip_model.encode_text([query])[0].numpy().astype('float32')
    D, I = index.search(np.expand_dims(q_feat, axis=0), k=10)
    results = []
    for dist, idx in zip(D[0], I[0]):
        filename = filenames[idx]
        results.append({
            "filename": filename,
            "url": f"/photos/{filename}",
            "score": float(1 / (1 + dist))
        })
    return {"query": query, "results": results}

@app.get("/photos/")
def list_photos():
    files = os.listdir(PHOTOS_DIR)
    return [{"filename": f, "url": f"/photos/{f}"} for f in files]

@app.get("/photos/{filename}")
def get_photo(filename: str):
    file_path = os.path.join(PHOTOS_DIR, filename)
    if os.path.exists(file_path):
        return FileResponse(file_path)
    return {"detail": "Not Found"}

@app.get("/profile-photo")
def get_profile_photo():
    profile_photo_path = os.path.join(PHOTOS_DIR, "profile_photo.png")
    if os.path.exists(profile_photo_path):
        return FileResponse(profile_photo_path)
    return {"detail": "Profile photo not found"}

@app.get("/")
def read_root():
    return {"message": "Welcome to the Photos App API!"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
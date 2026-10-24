"""Explicit one-time download of the pinned experimental model (several GB)."""
from huggingface_hub import snapshot_download
from .config import MODEL_ID, MODEL_REVISION

if __name__ == "__main__":
    print(snapshot_download(repo_id=MODEL_ID, revision=MODEL_REVISION))

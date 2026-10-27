"""Trains a tiny classifier at BUILD TIME (inside the Docker image), not at
runtime. This is the pattern used from class 5 onward: weights live outside
the app code, baked into the image (or, in a fancier setup, pulled from
object storage on startup). Here the versioned model file is stored under
/app/weights inside the image.
"""

from __future__ import annotations

import os
from pathlib import Path

import joblib
from sklearn.datasets import load_iris
from sklearn.linear_model import LogisticRegression

MODEL_VERSION = os.environ.get("MODEL_VERSION", "iris-logreg-v1")
MODEL_PATH = Path(
    os.environ.get("MODEL_PATH", f"weights/model-{MODEL_VERSION}.joblib")
)


def main() -> None:
    data = load_iris()
    clf = LogisticRegression(max_iter=200)
    clf.fit(data.data, data.target)
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": clf, "target_names": list(data.target_names)}, MODEL_PATH)
    print(f"Trained iris classifier {MODEL_VERSION}, saved to {MODEL_PATH}")


if __name__ == "__main__":
    main()

"""Duygu analizi (FinBERT) + Gemini özetleme adaptörleri.

- FinBERT: transformers varsa 'ProsusAI/finbert' ile; yoksa sözlük-tabanlı mock.
- Gemini: GEMINI_API_KEY varsa gerçek özet; yoksa çıkarımsal mock özet.

Çıktı: sentiment_score ∈ [-1, 1] (negatif..pozitif).
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass

POSITIVE = {"büyüme", "kâr", "kar", "artış", "yükseliş", "rekor", "güçlü", "olumlu",
            "growth", "profit", "surge", "beat", "strong", "bullish", "upgrade"}
NEGATIVE = {"zarar", "düşüş", "kayıp", "risk", "kriz", "daralma", "olumsuz", "iflas",
            "loss", "decline", "drop", "weak", "bearish", "downgrade", "recession"}


@dataclass
class SentimentResult:
    score: float          # -1..1
    label: str            # negatif/nötr/pozitif
    backend: str
    summary: str


def _label(score: float) -> str:
    if score > 0.15:
        return "pozitif"
    if score < -0.15:
        return "negatif"
    return "nötr"


def _lexicon_score(text: str) -> float:
    words = re.findall(r"\w+", text.lower())
    pos = sum(w in POSITIVE for w in words)
    neg = sum(w in NEGATIVE for w in words)
    if pos + neg == 0:
        return 0.0
    return (pos - neg) / (pos + neg)


def _finbert_score(text: str):
    from transformers import pipeline  # type: ignore
    nlp = pipeline("text-classification", model="ProsusAI/finbert")
    out = nlp(text[:512])[0]
    mapping = {"positive": 1.0, "neutral": 0.0, "negative": -1.0}
    return mapping.get(out["label"].lower(), 0.0) * float(out["score"])


def _gemini_summary(text: str) -> str | None:
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        return None
    try:
        import google.generativeai as genai
        genai.configure(api_key=key)
        model = genai.GenerativeModel("gemini-1.5-flash")
        resp = model.generate_content(
            f"Aşağıdaki finansal bülteni 2 cümlede özetle:\n\n{text[:4000]}")
        return resp.text.strip()
    except Exception as exc:  # pragma: no cover
        print(f"[gemini] özetleme başarısız: {exc}")
        return None


def analyze_bulletin(text: str) -> SentimentResult:
    # Sentiment
    try:
        score = _finbert_score(text)
        backend = "finbert"
    except Exception:
        score = _lexicon_score(text)
        backend = "lexicon-mock"
    # Özet
    summary = _gemini_summary(text)
    if summary is None:
        sents = re.split(r"(?<=[.!?])\s+", text.strip())
        summary = " ".join(sents[:2]) if sents else text[:200]
        backend += "+mock-summary"
    return SentimentResult(round(float(score), 3), _label(score), backend, summary)

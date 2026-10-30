# AI Journal Companion Backend

FastAPI backend for the AI Journal Companion Android application. It uses Ollama with the `gemma:2b` model to detect an emotion and provide supportive advice.

## Requirements

- Python 3.11 or later
- Ollama
- `gemma:2b`

## Setup

```powershell
ollama pull gemma:2b
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Run

Start Ollama:

```powershell
ollama serve
```

Start FastAPI:

```powershell
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

API documentation:

```text
http://localhost:8000/docs
```

## Analyze Endpoint

Send a `POST` request to `/analyze`:

```json
{
  "text": "I feel relaxed and peaceful today."
}
```

Example response:

```json
{
  "emotion": "CALM",
  "advice": "Continue making time for activities that support this peaceful feeling."
}
```

## Related Repositories

- [Android App](https://github.com/datrulesok/AI-Journal-Companion)
- [Data Structures Library](https://github.com/datrulesok/AI-Journal-Companion-DataStructures)

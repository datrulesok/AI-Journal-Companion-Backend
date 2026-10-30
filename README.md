# AI Journal Companion Backend

FastAPI backend for the AI Journal Companion Android application. It sends journal text to a locally hosted Ollama `gemma:2b` model and returns a detected emotion and supportive advice.

## Requirements

- Python 3.11 or later
- Ollama
- `gemma:2b` model

## Setup

Download the model:

```powershell
ollama pull gemma:2b

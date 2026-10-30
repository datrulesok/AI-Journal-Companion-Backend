from fastapi import FastAPI
from pydantic import BaseModel
from typing import Literal
import requests
import traceback


app = FastAPI()


# --------------------------------------------------
# Request model
# --------------------------------------------------

class PromptInput(BaseModel):
    text: str


# --------------------------------------------------
# Response model
# --------------------------------------------------

class AnalysisOutput(BaseModel):
    emotion: Literal[
        "JOY",
        "ANGER",
        "SADNESS",
        "ANXIETY",
        "CALM",
        "SURPRISE",
        "FRUSTRATION",
        "EXCITEMENT",
        "FEAR",
        "CONTENTMENT",
        "JEALOUSY",
        "BOREDOM",
        "LOVE",
        "DISGUST",
        "NEUTRAL"
    ]

    advice: str


# --------------------------------------------------
# Emotion analysis
# --------------------------------------------------

@app.post("/analyze", response_model=AnalysisOutput)
def generate_emotion_analysis(input: PromptInput):

    try:

        prompt = (
            "You are an emotion classification system.\n\n"

            "Analyze the journal entry and determine the SINGLE "
            "dominant emotion expressed by the writer.\n\n"

            "Allowed emotions:\n"
            "JOY\n"
            "ANGER\n"
            "SADNESS\n"
            "ANXIETY\n"
            "CALM\n"
            "SURPRISE\n"
            "FRUSTRATION\n"
            "EXCITEMENT\n"
            "FEAR\n"
            "CONTENTMENT\n"
            "JEALOUSY\n"
            "BOREDOM\n"
            "LOVE\n"
            "DISGUST\n"
            "NEUTRAL\n\n"

            "Classification rules:\n"
            "- Use JOY for clear happiness, delight, or pleasure.\n"
            "- Use ANGER for rage, hostility, or strong irritation directed "
            "at someone or something.\n"
            "- Use SADNESS for unhappiness, grief, disappointment, or loneliness.\n"
            "- Use ANXIETY for worry, stress, nervousness, uncertainty, or "
            "feeling overwhelmed.\n"
            "- Use CALM for peacefulness, relaxation, or emotional stillness.\n"
            "- Use SURPRISE for shock, astonishment, or unexpected events.\n"
            "- Use FRUSTRATION for annoyance caused by difficulty, failure, "
            "delay, or blocked goals.\n"
            "- Use EXCITEMENT for strong enthusiasm, anticipation, or high-energy "
            "positive emotion.\n"
            "- Use FEAR when the writer clearly feels frightened, threatened, "
            "or afraid.\n"
            "- Use CONTENTMENT for satisfaction, comfort, fulfilment, or being "
            "pleased with the current situation.\n"
            "- Use JEALOUSY for envy, possessiveness, resentment, or fear that "
            "someone may take a valued relationship or advantage.\n"
            "- Use BOREDOM for lack of interest, stimulation, or engagement.\n"
            "- Use LOVE for affection, caring, closeness, or strong emotional "
            "attachment.\n"
            "- Use DISGUST for revulsion, repulsion, or strong dislike.\n"
            "- Use NEUTRAL when there is no clear dominant emotion.\n\n"

            "IMPORTANT:\n"
            "- Return exactly one emotion from the allowed emotion list.\n"
            "- Do not return emotions outside the allowed list.\n"
            "- Do not assume an emotion that is not expressed in the text.\n"
            "- Distinguish ANGER from FRUSTRATION: use FRUSTRATION when the "
            "emotion results mainly from difficulty, delay, or failure.\n"
            "- Distinguish JOY from EXCITEMENT: use EXCITEMENT for energetic "
            "anticipation and JOY for happiness or delight.\n"
            "- Distinguish CALM from CONTENTMENT: use CALM for peacefulness and "
            "CONTENTMENT for satisfaction with the current situation.\n"
            "- Short greetings such as 'hello' or 'hi' are NEUTRAL.\n"
            "- A swear word alone does not automatically mean ANGER.\n"
            "- Base the classification only on the journal entry.\n"
            "- Give one short sentence of appropriate supportive advice.\n\n"

            f"Journal entry:\n{input.text}"
        )

        schema = {
            "type": "object",
            "properties": {
                "emotion": {
                    "type": "string",
                    "enum": [
                        "JOY",
                        "ANGER",
                        "SADNESS",
                        "ANXIETY",
                        "CALM",
                        "SURPRISE",
                        "FRUSTRATION",
                        "EXCITEMENT",
                        "FEAR",
                        "CONTENTMENT",
                        "JEALOUSY",
                        "BOREDOM",
                        "LOVE",
                        "DISGUST",
                        "NEUTRAL"
                    ]
                },
                "advice": {
                    "type": "string"
                }
            },
            "required": [
                "emotion",
                "advice"
            ]
        }

        response = requests.post(
            "http://localhost:11434/api/chat",
            json={
                "model": "gemma:2b",

                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "You classify emotions in journal entries. "
                            "Return exactly one emotion from the allowed list. "
                            "Be conservative. If there is no clear emotion, "
                            "classify the entry as NEUTRAL."
                        )
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],

                "format": schema,

                "options": {
                    "temperature": 0
                },

                "stream": False
            },

            timeout=120
        )

        print("OLLAMA STATUS:")
        print(response.status_code)

        print("OLLAMA RESPONSE:")
        print(response.text)

        response.raise_for_status()

        ollama_response = response.json()
        content = ollama_response["message"]["content"]

        print("AI CONTENT:")
        print(content)

        analysis = AnalysisOutput.model_validate_json(content)

        return analysis

    except Exception as error:

        print("\n========== ERROR ==========")
        traceback.print_exc()
        print("===========================\n")

        return {
            "emotion": "NEUTRAL",
            "advice": (
                "Unable to analyse the journal entry: "
                f"{str(error)}"
            )
        }
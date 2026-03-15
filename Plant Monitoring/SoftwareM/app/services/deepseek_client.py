import httpx
from app.core.config import settings

class DeepSeekClient:
    def __init__(self):
        self.api_key = settings.deepseek_api_key
        self.api_url = settings.deepseek_api_url

    async def get_treatment_plan(self, disease_name: str) -> str:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        prompt = f"""You are a plant disease expert. A tree has been diagnosed with: {disease_name}

Please provide a detailed treatment plan including:
1. Immediate actions to take
2. Recommended treatments or medications
3. Prevention measures for future
4. Expected recovery timeline

Keep the response concise and practical."""

        payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": "You are a professional plant pathologist providing treatment advice."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.7,
            "max_tokens": 500
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(self.api_url, json=payload, headers=headers)
                response.raise_for_status()
                result = response.json()
                treatment_plan = result["choices"][0]["message"]["content"]
                return treatment_plan
        except Exception as e:
            return f"Failed to generate treatment plan: {str(e)}"

# Global instance
deepseek_client = DeepSeekClient()

from __future__ import annotations

import os
import httpx


class DeepSeekService:
    def __init__(self) -> None:
        self.base_url = "https://api.deepseek.com/v1/chat/completions"

    async def get_treatment_advice(self, disease_name: str) -> str:
        api_key = os.getenv("DEEPSEEK_API_KEY")
        if not api_key:
            return "DeepSeek API key not configured"

        prompt = f"请为植物疾病'{disease_name}'提供简洁的治疗建议，包括：1) 病因 2) 治疗方法 3) 预防措施。请用中文回答，控制在200字以内。"

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    self.base_url,
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "deepseek-chat",
                        "messages": [{"role": "user", "content": prompt}],
                        "temperature": 0.7,
                    },
                )
                response.raise_for_status()
                data = response.json()
                return data["choices"][0]["message"]["content"]
        except Exception as e:
            return f"Failed to get treatment advice: {str(e)}"


deepseek_service = DeepSeekService()

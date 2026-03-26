from pydantic_settings import BaseSettings
from pydantic import ConfigDict

class Settings(BaseSettings):
    database_url: str = "sqlite:///./campus_plant.db"
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    deepseek_api_key: str
    deepseek_api_url: str = "https://api.deepseek.com/v1/chat/completions"
    model_path: str = "./app/cnn/plant_disease_cnn.pth"
    upload_dir: str = "./app/static/uploads"
    max_upload_size: int = 10485760

    model_config = ConfigDict(
        env_file=".env",
        protected_namespaces=('settings_',)
    )

settings = Settings()

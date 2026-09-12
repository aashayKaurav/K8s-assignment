import os


class Config:
    DB_HOST = os.environ.get("DB_HOST", "localhost")
    DB_PORT = os.environ.get("DB_PORT", "5432")
    DB_NAME = os.environ.get("DB_NAME", "appdb")
    DB_USER = os.environ.get("DB_USER", "appuser")
    DB_PASSWORD = os.environ.get("DB_PASSWORD", "apppassword")

    @classmethod
    def get_dsn(cls):
        return (
            f"host={cls.DB_HOST} port={cls.DB_PORT} dbname={cls.DB_NAME} "
            f"user={cls.DB_USER} password={cls.DB_PASSWORD}"
        )

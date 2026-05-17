# AGENTS.md

## Cursor Cloud specific instructions

### Overview

This is a Python/FastAPI proxy server with JWT authentication. It requires PostgreSQL and Redis as backing services.

### Services

| Service | How to run | Port |
|---------|-----------|------|
| PostgreSQL + Redis | `docker compose up -d db redis` | 5432, 6379 |
| FastAPI app (dev) | `source venv/bin/activate && uvicorn app.main:app --reload --host 0.0.0.0 --port 8080` | 8080 |

### Important notes

- **bcrypt compatibility**: `passlib==1.7.4` is incompatible with `bcrypt>=4.1`. After installing from `requirements.txt`, downgrade bcrypt: `pip install 'bcrypt==4.0.1'`. Without this, password hashing/verification will fail at runtime.
- **Docker required**: PostgreSQL and Redis must be running before starting the app. Use `docker compose up -d db redis` from the repo root. Wait for containers to be healthy before starting the app.
- **Database initialization**: After first start, run `python init_db.py` to create tables and seed a default admin user (`admin@example.com` / `admin123`).
- **Environment variables**: Copy `.env.example` to `.env`. The defaults work for local development with docker-composed db/redis.
- **No linting or test framework**: The project has no pytest, flake8, ruff, or other linting/testing tools. Use `python3 -m py_compile <file>` for basic syntax checks or import-check modules with `python3 -c "import app.main"`.
- **API docs**: Available at `http://localhost:8080/docs` (Swagger) and `http://localhost:8080/redoc` once the app is running.
- **Health check**: `GET /health` returns database and Redis connectivity status.
- Refer to `README.md` and `QUICKSTART.md` for full API endpoint documentation and usage examples.

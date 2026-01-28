"""
Скрипт для инициализации базы данных
"""
import sys
from sqlalchemy import create_engine, text
from app.database import Base, engine
from app.models import User, Session
from app.utils.security import get_password_hash
from app.config import settings

def init_database():
    """Инициализация базы данных"""
    print("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    print("Database tables created successfully!")
    
    # Создаем администратора по умолчанию (если нужно)
    from app.database import SessionLocal
    db = SessionLocal()
    
    try:
        # Проверяем, есть ли уже администратор
        admin = db.query(User).filter(User.email == "admin@example.com").first()
        if not admin:
            print("Creating default admin user...")
            admin = User(
                email="admin@example.com",
                username="admin",
                hashed_password=get_password_hash("admin123"),
                is_active=True,
                is_admin=True,
                is_verified=True
            )
            db.add(admin)
            db.commit()
            print("Default admin user created!")
            print("Email: admin@example.com")
            print("Password: admin123")
            print("⚠️  WARNING: Change the default admin password immediately!")
        else:
            print("Admin user already exists.")
    except Exception as e:
        print(f"Error creating admin user: {e}")
        db.rollback()
    finally:
        db.close()
    
    print("Database initialization completed!")

if __name__ == "__main__":
    try:
        init_database()
    except Exception as e:
        print(f"Error initializing database: {e}")
        sys.exit(1)

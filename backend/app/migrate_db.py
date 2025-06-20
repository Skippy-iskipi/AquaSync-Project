from .database import Base, engine
from .models import FishSpecies

def migrate():
    print("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    print("Database tables created successfully!")

if __name__ == "__main__":
    migrate() 
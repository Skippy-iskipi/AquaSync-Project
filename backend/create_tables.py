from app.database import Base, engine
from app.models.trained_model import TrainedModel

# Import all models that should be created
# The imports are needed even if not directly used in this file

def create_all_tables():
    print("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    print("Tables created successfully!")

if __name__ == "__main__":
    create_all_tables()

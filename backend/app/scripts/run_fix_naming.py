import os
import sys

# Add the parent directory to Python path so we can import our modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))))

from backend.app.scripts.fix_naming import fix_naming_consistency

if __name__ == "__main__":
    print("Starting to fix naming consistency...")
    fix_naming_consistency()
    print("Completed naming consistency fix.") 
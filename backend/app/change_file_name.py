import os
import re

# Path to the folder containing the images
FOLDER_PATH = os.path.join(
    os.path.dirname(__file__),
    "datasets",
    "raw_fish_images",
    "foxface rabbitfish"
)

def rename_files():
    if not os.path.exists(FOLDER_PATH):
        print(f"Folder not found: {FOLDER_PATH}")
        return

    for filename in os.listdir(FOLDER_PATH):
        old_path = os.path.join(FOLDER_PATH, filename)

        if os.path.isfile(old_path):
            # Keep the file extension
            name, ext = os.path.splitext(filename)

            # Replace CamelCase or spaces with underscores, then lowercase
            new_name = re.sub(r'(?<!^)(?=[A-Z])', '_', name)  # Insert _ before capital letters
            new_name = new_name.replace(" ", "_").lower()

            # Force start with "foxface_rabbitfish"
            if not new_name.startswith("foxface_rabbitfish"):
                # If it has an underscore number at the end, preserve it
                match = re.search(r'_(\d+)$', new_name)
                if match:
                    number = match.group(1)
                    new_name = f"foxface_rabbitfish_{number}"
                else:
                    new_name = "foxface_rabbitfish_" + new_name

            new_filename = new_name + ext.lower()
            new_path = os.path.join(FOLDER_PATH, new_filename)

            os.rename(old_path, new_path)
            print(f"Renamed: {filename} → {new_filename}")

if __name__ == "__main__":
    rename_files()

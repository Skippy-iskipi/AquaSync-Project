import pandas as pd

def build_feature(fish1_data, fish2_data):
    """Build feature vector for compatibility prediction using size, temperament, water type, and diet."""
    # Ensure data types are numeric for arithmetic operations
    features = pd.DataFrame({
        'size_diff': [abs(float(fish1_data['Max Size (cm)']) - float(fish2_data['Max Size (cm)']))],
        'temperament_diff': [abs(int(fish1_data['Temperament']) - int(fish2_data['Temperament']))],
        'water_type_match': [1 if fish1_data['Water Type'] == fish2_data['Water Type'] else 0],
        'diet_match': [1 if fish1_data['Diet'] == fish2_data['Diet'] else 0]
    })
    return features

def get_reason(fish1_data, fish2_data):
    """Get the reason for incompatibility based on size, temperament, water type, and diet."""
    reasons = []
    
    # Check size compatibility
    if abs(float(fish1_data['Max Size (cm)']) - float(fish2_data['Max Size (cm)'])) > 5:
        reasons.append("Size difference may cause issues")
    
    # Check temperament compatibility
    if int(fish1_data['Temperament']) != int(fish2_data['Temperament']):
        reasons.append("Temperament mismatch")
    
    # Check water type compatibility
    if fish1_data['Water Type'] != fish2_data['Water Type']:
        reasons.append("Water type mismatch")
    
    # Check diet compatibility
    if fish1_data['Diet'] != fish2_data['Diet']:
        reasons.append("Dietary requirements differ")
    
    return "; ".join(reasons) if reasons else "Compatible"


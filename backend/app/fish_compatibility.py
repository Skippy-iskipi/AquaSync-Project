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
        reasons.append("There's a significant size difference between these fish that could lead to bullying or predation")
    
    # Check temperament compatibility
    if int(fish1_data['Temperament']) != int(fish2_data['Temperament']):
        reasons.append("These fish have different temperaments that may cause stress and conflict")
    
    # Check water type compatibility
    if fish1_data['Water Type'] != fish2_data['Water Type']:
        reasons.append("These fish need different types of water - one needs freshwater while the other needs saltwater")
    
    # Check diet compatibility
    if fish1_data['Diet'] != fish2_data['Diet']:
        reasons.append("These fish have different dietary needs that may be difficult to meet in the same tank")
    
    return "; ".join(reasons) if reasons else "Compatible"


class FishSpecies {
  final String commonName;
  final String scientificName;
  final String maxSize;
  final String temperament;
  final String waterType;
  final String temperatureRange;
  final String phRange;
  final String habitatType;
  final String socialBehavior;
  final String tankLevel;
  final String minimumTankSize;
  final String compatibilityNotes;
  final String diet;
  final String lifespan;
  final String careLevel;
  final String preferredFood;
  final String feedingFrequency;
  
  // Additional columns from fish_species table
  final String? id;
  final String? updatedAt;
  final String? status;
  final String? tankZone;
  final String? bioload;
  final String? portionGrams;
  final String? feedingNotes;
  final String? description;
  final String? overfeedingRisks;

  FishSpecies({
    required this.commonName,
    required this.scientificName,
    required this.maxSize,
    required this.temperament,
    required this.waterType,
    required this.temperatureRange,
    required this.phRange,
    required this.habitatType,
    required this.socialBehavior,
    required this.tankLevel,
    required this.minimumTankSize,
    required this.compatibilityNotes,
    required this.diet,
    required this.lifespan,
    required this.careLevel,
    required this.preferredFood,
    required this.feedingFrequency,
    this.id,
    this.updatedAt,
    this.status,
    this.tankZone,
    this.bioload,
    this.portionGrams,
    this.feedingNotes,
    this.description,
    this.overfeedingRisks,
  });

  static String _cleanTempRange(dynamic raw) {
    if (raw == null) return 'Unknown';
    String s = raw.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'NULL') return 'Unknown';
    
    // Fix encoding artifacts and normalize spacing
    s = s.replaceAll('Â°', '°').replaceAll('\u00A0', ' ').replaceAll('\u00a0', ' ');
    
    // Normalize different types of dashes to regular hyphens
    s = s.replaceAll('\u2013', '-')  // en dash
         .replaceAll('\u2014', '-')  // em dash
         .replaceAll('\u2015', '-')  // horizontal bar
         .replaceAll('\u2212', '-'); // minus sign
    
    // Check if it already has temperature units
    final lower = s.toLowerCase();
    if (lower.contains('°c') || lower.contains('celsius') || 
        lower.contains('°f') || lower.contains('fahrenheit')) {
      return s; // Return as-is if units already present
    }
    
    // Only add °C if it's a pure number or range (now handles normalized dashes)
    if (RegExp(r'^\d+(-\d+)?$').hasMatch(s) || RegExp(r'^\d+\.\d+(-\d+\.\d+)?$').hasMatch(s)) {
      if (s.contains('°')) {
        // If it has °, assume it's Celsius and just append C
        s = s.replaceAll('°', '°C');
      } else {
        // If no degree symbol, append the whole thing
        s = '$s °C';
      }
    }
    
    return s;
  }

  static String _formatTankSize(dynamic raw) {
    if (raw == null) return 'Unknown';
    String s = raw.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'NULL') return 'Unknown';
    
    // Check if it already has units
    final lower = s.toLowerCase();
    if (lower.contains('l') || lower.contains('liter') || lower.contains('litre') || 
        lower.contains('gal') || lower.contains('gallon')) {
      return s; // Return as-is if units already present
    }
    
    // Only add L if it's a pure number
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) {
      s = '$s L';
    }
    
    return s;
  }

  static String _formatMaxSize(dynamic raw) {
    if (raw == null) return 'Unknown';
    String s = raw.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'NULL') return 'Unknown';
    
    // Check if it already has units
    final lower = s.toLowerCase();
    if (lower.contains('cm') || lower.contains('centimeter') || 
        lower.contains('mm') || lower.contains('millimeter') ||
        lower.contains('in') || lower.contains('inch')) {
      return s; // Return as-is if units already present
    }
    
    // Only add cm if it's a pure number
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) {
      s = '$s cm';
    }
    
    return s;
  }

  factory FishSpecies.fromJson(Map<String, dynamic> json) {
    // Prefer new key but support legacy variants and normalize (same as fish_prediction.dart)
    final tempRaw = (json['temperature_range']
        ?? json['temperature']
        ?? json['temperature_c']
        ?? json['temperature_range_c']
        ?? json['temperature_range_(°C)']
        ?? json['temperature_range_(Â°C)']
        ?? json['temperature_range_(°c)']
        ?? json['temperature_range_(Â°c)']
        ?? json['temp_range']
        ?? json['tempRange']
        ?? json['temperatureRange'])?.toString();
    
    // Handle database column names with special characters and ensure string conversion
    final maxSizeRaw = (json['max_size_(cm)']
        ?? json['max_size']
        ?? json['maxSize']
        ?? json['max_size_cm']
        ?? json['max_size_cm_']
        ?? json['maxSizeCm'])?.toString();
    
    final minTankSizeRaw = (json['minimum_tank_size_(l)']
        ?? json['minimum_tank_size']
        ?? json['minimumTankSize']
        ?? json['minimum_tank_size_l']
        ?? json['minimum_tank_size_l_']
        ?? json['minimumTankSizeL'])?.toString();
    
    return FishSpecies(
      commonName: (json['common_name'] ?? '').toString(),
      scientificName: (json['scientific_name'] ?? '').toString(),
      maxSize: _formatMaxSize(maxSizeRaw),
      temperament: (json['temperament'] ?? '').toString(),
      waterType: (json['water_type'] ?? '').toString(),
      temperatureRange: _cleanTempRange(tempRaw),
      phRange: (json['ph_range'] ?? '').toString(),
      habitatType: (json['habitat_type'] ?? '').toString(),
      socialBehavior: (json['social_behavior'] ?? '').toString(),
      tankLevel: (json['tank_level'] ?? '').toString(),
      minimumTankSize: _formatTankSize(minTankSizeRaw),
      compatibilityNotes: (json['compatibility_notes'] ?? '').toString(),
      diet: (json['diet'] ?? '').toString(),
      lifespan: (json['lifespan'] ?? '').toString(),
      careLevel: (json['care_level'] ?? '').toString(),
      preferredFood: (json['preferred_food'] ?? '').toString(),
      feedingFrequency: (json['feeding_frequency'] ?? '').toString(),
      id: json['id']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      status: json['status']?.toString(),
      tankZone: json['tank_zone']?.toString(),
      bioload: json['bioload']?.toString(),
      portionGrams: json['portion_grams']?.toString(),
      feedingNotes: json['feeding_notes']?.toString(),
      description: json['description']?.toString(),
      overfeedingRisks: json['overfeeding_risks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'common_name': commonName,
      'scientific_name': scientificName,
      'max_size': maxSize,
      'temperament': temperament,
      'water_type': waterType,
      'temperature_range': temperatureRange,
      'ph_range': phRange,
      'habitat_type': habitatType,
      'social_behavior': socialBehavior,
      'tank_level': tankLevel,
      'minimum_tank_size': minimumTankSize,
      'compatibility_notes': compatibilityNotes,
      'diet': diet,
      'lifespan': lifespan,
      'care_level': careLevel,
      'preferred_food': preferredFood,
      'feeding_frequency': feedingFrequency,
      'id': id,
      'updated_at': updatedAt,
      'status': status,
      'tank_zone': tankZone,
      'bioload': bioload,
      'portion_grams': portionGrams,
      'feeding_notes': feedingNotes,
      'description': description,
      'overfeeding_risks': overfeedingRisks,
    };
  }
} 
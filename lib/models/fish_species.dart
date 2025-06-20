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
  });

  factory FishSpecies.fromJson(Map<String, dynamic> json) {
    return FishSpecies(
      commonName: json['common_name'] ?? '',
      scientificName: json['scientific_name'] ?? '',
      maxSize: json['max_size']?.toString() ?? '',
      temperament: json['temperament'] ?? '',
      waterType: json['water_type'] ?? '',
      temperatureRange: json['temperature_range'] ?? '',
      phRange: json['ph_range'] ?? '',
      habitatType: json['habitat_type'] ?? '',
      socialBehavior: json['social_behavior'] ?? '',
      tankLevel: json['tank_level'] ?? '',
      minimumTankSize: json['minimum_tank_size']?.toString() ?? '',
      compatibilityNotes: json['compatibility_notes'] ?? '',
      diet: json['diet'] ?? '',
      lifespan: json['lifespan'] ?? '',
      careLevel: json['care_level'] ?? '',
      preferredFood: json['preferred_food'] ?? '',
      feedingFrequency: json['feeding_frequency'] ?? '',
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
    };
  }
} 
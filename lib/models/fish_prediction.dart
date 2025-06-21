class FishPrediction {
  final String? id;
  final String commonName;
  final String scientificName;
  final String waterType;
  final String probability;
  final String imagePath;
  final String maxSize;
  final String temperament;
  final String careLevel;
  final String lifespan;
  final String diet;
  final String preferredFood;
  final String feedingFrequency;
  final String description;
  final String temperatureRange;
  final String phRange;
  final String socialBehavior;
  final String minimumTankSize;
  final DateTime? createdAt;

  FishPrediction({
    this.id,
    required this.commonName,
    required this.scientificName,
    required this.waterType,
    required this.probability,
    required this.imagePath,
    required this.maxSize,
    required this.temperament,
    required this.careLevel,
    required this.lifespan,
    required this.diet,
    required this.preferredFood,
    required this.feedingFrequency,
    required this.description,
    this.temperatureRange = '',
    this.phRange = '',
    this.socialBehavior = '',
    this.minimumTankSize = '',
    this.createdAt,
  });

  FishPrediction copyWith({
    String? id,
    String? commonName,
    String? scientificName,
    String? waterType,
    String? probability,
    String? imagePath,
    String? maxSize,
    String? temperament,
    String? careLevel,
    String? lifespan,
    String? diet,
    String? preferredFood,
    String? feedingFrequency,
    String? description,
    String? temperatureRange,
    String? phRange,
    String? socialBehavior,
    String? minimumTankSize,
    DateTime? createdAt,
  }) {
    return FishPrediction(
      id: id ?? this.id,
      commonName: commonName ?? this.commonName,
      scientificName: scientificName ?? this.scientificName,
      waterType: waterType ?? this.waterType,
      probability: probability ?? this.probability,
      imagePath: imagePath ?? this.imagePath,
      maxSize: maxSize ?? this.maxSize,
      temperament: temperament ?? this.temperament,
      careLevel: careLevel ?? this.careLevel,
      lifespan: lifespan ?? this.lifespan,
      diet: diet ?? this.diet,
      preferredFood: preferredFood ?? this.preferredFood,
      feedingFrequency: feedingFrequency ?? this.feedingFrequency,
      description: description ?? this.description,
      temperatureRange: temperatureRange ?? this.temperatureRange,
      phRange: phRange ?? this.phRange,
      socialBehavior: socialBehavior ?? this.socialBehavior,
      minimumTankSize: minimumTankSize ?? this.minimumTankSize,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commonName': commonName,
      'scientificName': scientificName,
      'waterType': waterType,
      'probability': probability,
      'imagePath': imagePath,
      'maxSize': maxSize,
      'temperament': temperament,
      'careLevel': careLevel,
      'lifespan': lifespan,
      'diet': diet,
      'preferredFood': preferredFood,
      'feedingFrequency': feedingFrequency,
      'description': description,
      'temperatureRange': temperatureRange,
      'phRange': phRange,
      'socialBehavior': socialBehavior,
      'minimumTankSize': minimumTankSize,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory FishPrediction.fromJson(Map<String, dynamic> json) {
    return FishPrediction(
      id: json['id'],
      commonName: json['common_name'] ?? json['commonName'] ?? '',
      scientificName: json['scientific_name'] ?? json['scientificName'] ?? '',
      waterType: json['water_type'] ?? json['waterType'] ?? '',
      probability: json['probability'] ?? '',
      imagePath: json['image_path'] ?? json['imagePath'] ?? '',
      maxSize: json['max_size'] ?? json['maxSize'] ?? '',
      temperament: json['temperament'] ?? '',
      careLevel: json['care_level'] ?? json['careLevel'] ?? '',
      lifespan: json['lifespan'] ?? '',
      diet: json['diet'] ?? '',
      preferredFood: json['preferred_food'] ?? json['preferredFood'] ?? '',
      feedingFrequency: json['feeding_frequency'] ?? json['feedingFrequency'] ?? '',
      description: json['description'] ?? '',
      temperatureRange: json['temperature_range'] ?? json['temperatureRange'] ?? '',
      phRange: json['ph_range'] ?? json['phRange'] ?? '',
      socialBehavior: json['social_behavior'] ?? json['socialBehavior'] ?? '',
      minimumTankSize: json['minimum_tank_size'] ?? json['minimumTankSize'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  @override
  String toString() {
    return 'FishPrediction{id: $id, commonName: $commonName, scientificName: $scientificName, waterType: $waterType, probability: $probability, imagePath: $imagePath, maxSize: $maxSize, temperament: $temperament, careLevel: $careLevel, lifespan: $lifespan, diet: $diet, preferredFood: $preferredFood, feedingFrequency: $feedingFrequency, description: $description, temperatureRange: $temperatureRange, phRange: $phRange, socialBehavior: $socialBehavior, minimumTankSize: $minimumTankSize, createdAt: $createdAt}';
  }
} 
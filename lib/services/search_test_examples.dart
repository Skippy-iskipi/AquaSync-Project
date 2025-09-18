// This file contains examples of how the improved smart search works
// It's for documentation purposes and can be removed if not needed

class SearchTestExamples {
  static const Map<String, List<String>> searchExamples = {
    'Exact Matches (High Priority)': [
      'orange fish', // Should find fish with "orange" in name or description
      'blue tang', // Should find Blue Tang specifically
      'betta', // Should find Betta fish
      'goldfish', // Should find Goldfish
    ],
    
    'Attribute-Based Searches': [
      'peaceful freshwater', // Fish that are peaceful AND freshwater
      'small schooling', // Small fish that school
      'carnivore beginner', // Carnivorous fish suitable for beginners
      'top level saltwater', // Saltwater fish that prefer top level
    ],
    
    'Synonym Searches': [
      'marine fish', // Should find saltwater fish
      'tiny peaceful', // Should find small, calm fish
      'community fish', // Should find schooling fish
      'easy care', // Should find beginner-level fish
    ],
    
    'Fuzzy Matching (Typo Tolerance)': [
      'bloo fish', // Should find "blue fish"
      'betta fish', // Should find "betta" even with typo
      'goldfsh', // Should find "goldfish"
      'angelfsh', // Should find "angelfish"
    ],
    
    'Multi-Word Searches': [
      'small blue freshwater', // Multiple criteria
      'peaceful community fish', // Multiple attributes
      'beginner friendly saltwater', // Multiple requirements
    ],
    
    'Tagalog/Filipino Searches': [
      'maliit na isda', // Small fish in Tagalog
      'asul na isda', // Blue fish in Tagalog
      'mabangis na isda', // Aggressive fish in Tagalog
      'tubig-tabang na isda', // Freshwater fish in Tagalog
      'madaling alagaan', // Easy to care for in Tagalog
      'pangkatan na isda', // Schooling fish in Tagalog
      'kumakain ng karne', // Carnivorous in Tagalog
      'itaas na isda', // Top level fish in Tagalog
      'korales na isda', // Reef fish in Tagalog
      'may halaman na isda', // Planted tank fish in Tagalog
    ],
  };

  static const Map<String, String> searchExplanation = {
    'Why "orange fish" returns many results': 
      'The old search was too broad and included technical columns like "portion_grams", "bioload", etc. The new search focuses on relevant columns like name, description, and habitat.',
    
    'How the new search works': 
      '1. First searches primary columns (name, description, habitat) for exact matches\n'
      '2. Then searches secondary columns (temperament, diet, etc.) for attribute matches\n'
      '3. Uses fuzzy matching with balanced thresholds for better recall\n'
      '4. Applies balanced similarity threshold (0.6) for good precision and recall\n'
      '5. Prioritizes exact matches over fuzzy matches\n'
      '6. Supports Tagalog/Filipino terms through synonym mapping',
    
    'Tagalog/Filipino Support': 
      'The search now supports common Tagalog terms:\n'
      '• "maliit na isda" → finds small fish\n'
      '• "asul na isda" → finds blue fish\n'
      '• "mabangis na isda" → finds aggressive fish\n'
      '• "tubig-tabang na isda" → finds freshwater fish\n'
      '• "madaling alagaan" → finds beginner-friendly fish\n'
      '• "pangkatan na isda" → finds schooling fish\n'
      '• "kumakain ng karne" → finds carnivorous fish\n'
      '• "itaas na isda" → finds top-level fish\n'
      '• "korales na isda" → finds reef fish\n'
      '• "may halaman na isda" → finds planted tank fish',
    
    'Search Precision Improvements': 
      '• Balanced similarity threshold at 0.6 for optimal results\n'
      '• Separated primary and secondary search columns\n'
      '• Improved synonym matching for better recall\n'
      '• Added exact match prioritization\n'
      '• Increased search pool size for better coverage',
    
    'Threshold Impact Analysis': 
      '• 0.3 (30%): Very permissive, many results but many irrelevant\n'
      '• 0.5 (50%): Balanced, good mix of precision and recall\n'
      '• 0.6 (60%): Optimal balance, good precision with good recall (CURRENT)\n'
      '• 0.7 (70%): More precise, fewer irrelevant results\n'
      '• 0.8 (80%): Very precise, only strong matches\n'
      '• 0.9 (90%): Extremely precise, may miss valid results',
  };

  static const Map<String, List<String>> thresholdExamples = {
    'Threshold 0.3 (30%)': [
      'Very permissive',
      'Returns many results',
      'Includes weak matches',
      'Good for broad searches',
      'May include irrelevant results',
    ],
    'Threshold 0.5 (50%)': [
      'Balanced approach',
      'Good precision/recall ratio',
      'Includes moderate matches',
      'Suitable for most searches',
      'Some irrelevant results possible',
    ],
    'Threshold 0.7 (70%)': [
      'High precision',
      'Fewer irrelevant results',
      'Only strong matches',
      'Good for specific searches',
      'May miss some valid results',
    ],
    'Threshold 0.8 (80%)': [
      'Very high precision',
      'Only very strong matches',
      'Minimal irrelevant results',
      'Best for exact searches',
      'May miss legitimate variations',
    ],
    'Threshold 0.6 (60%) - CURRENT': [
      'Optimal balance',
      'Good precision with good recall',
      'Finds relevant matches without too many irrelevant ones',
      'Best for most search scenarios',
      'Balanced approach',
    ],
  };
}

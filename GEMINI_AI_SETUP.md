# Gemini AI Setup Guide

## Overview
This guide will help you migrate from HuggingFace AI to Google's Gemini AI API for better AI capabilities in your AquaSync application.

## Why Gemini AI?
- **Better Quality**: More coherent and contextually accurate responses
- **Higher Reliability**: More stable API with better uptime
- **Free Tier**: 15 requests/minute, 1500 requests/day
- **Better Understanding**: Superior comprehension of complex prompts
- **Faster Response**: Lower latency compared to HuggingFace

## Step 1: Get Gemini AI API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the generated API key
5. Keep it secure - you'll need it for the next step

## Step 2: Update API Key

1. Open `lib/services/gemini_service.dart`
2. Find this line:
   ```dart
   static const String _apiKey = 'YOUR_GEMINI_API_KEY';
   ```
3. Replace `'YOUR_GEMINI_API_KEY'` with your actual API key:
   ```dart
   static const String _apiKey = 'AIzaSyC...'; // Your actual key here
   ```

## Step 3: Update Dependencies

The `http` package is already included in your `pubspec.yaml`, so no additional dependencies are needed.

## Step 4: Test the Integration

1. Run your Flutter app
2. Go to the Diet Calculator screen
3. Add some fish and generate diet recommendations
4. Check the console logs for Gemini AI responses

## Step 5: Update Other Screens (Optional)

If you want to use Gemini AI in other parts of your app, update these files:

### Fish List Screen (`lib/screens/fish_list_screen.dart`)
```dart
// Replace this import:
import '../services/huggingface_service.dart';

// With this:
import '../services/gemini_service.dart';

// Then replace all HuggingFaceService calls with GeminiService:
// HuggingFaceService.generateFishDescription → GeminiService.generateFishDescription
// HuggingFaceService.generateCareRecommendations → GeminiService.generateCareRecommendations
```

### Water Calculator (`lib/screens/water_calculator.dart`)
```dart
// Replace HuggingFaceService calls with GeminiService:
// HuggingFaceService.generateOxygenAndFiltrationNeeds → GeminiService.generateOxygenAndFiltrationNeeds
// HuggingFaceService.explainIncompatibilityReasons → GeminiService.explainIncompatibilityReasons
```

### Capture Screen (`lib/screens/capture.dart`)
```dart
// Replace HuggingFaceService calls with GeminiService:
// HuggingFaceService.generateFishDescription → GeminiService.generateFishDescription
// HuggingFaceService.generateCareRecommendations → GeminiService.generateCareRecommendations
```

### Sync Screen (`lib/screens/sync.dart`)
```dart
// Replace HuggingFaceService calls with GeminiService:
// HuggingFaceService.generateFishDescription → GeminiService.generateFishDescription
// HuggingFaceService.generateCareRecommendations → GeminiService.generateCareRecommendations
// HuggingFaceService.explainIncompatibilityReasons → GeminiService.explainIncompatibilityReasons
```

### Logbook Provider (`lib/screens/logbook_provider.dart`)
```dart
// Replace HuggingFaceService calls with GeminiService:
// HuggingFaceService.generateCareRecommendations → GeminiService.generateCareRecommendations
```

## API Usage Limits

- **Free Tier**: 15 requests/minute, 1500 requests/day
- **Paid Tier**: Higher limits available
- **Rate Limiting**: Automatic retry logic included in the service

## Error Handling

The Gemini service includes comprehensive error handling:
- Network timeouts (30 seconds)
- API errors
- Fallback responses when AI fails
- Fish-specific fallback data

## Benefits You'll See

1. **Better Diet Recommendations**: More specific and accurate fish diet advice
2. **Improved Portion Sizing**: More precise portion recommendations based on fish characteristics
3. **Enhanced Feeding Notes**: More relevant and actionable feeding advice
4. **Faster Responses**: Lower latency for better user experience
5. **More Reliable**: Fewer API failures and better uptime

## Troubleshooting

### API Key Issues
- Ensure your API key is correctly copied
- Check that you have sufficient quota remaining
- Verify the API key is active in Google AI Studio

### Network Issues
- Check your internet connection
- The service includes automatic fallbacks for network issues

### Response Quality
- If responses seem generic, check the fish database in the service
- The service includes fish-specific prompts for better results

## Migration Checklist

- [ ] Get Gemini AI API key
- [ ] Update API key in `gemini_service.dart`
- [ ] Test diet calculator functionality
- [ ] Update other screens (optional)
- [ ] Test all AI features
- [ ] Monitor API usage

## Support

If you encounter issues:
1. Check the console logs for error messages
2. Verify your API key is correct
3. Test with a simple prompt first
4. Check your API quota usage

The Gemini AI service is designed to be a drop-in replacement for HuggingFace, so the migration should be seamless!

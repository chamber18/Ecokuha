# AI Feature

## Overview
Artificial Intelligence services for waste detection, smart replies, and sorting recommendations.

## Architecture
```
ai/
├── data/           # AI API integration, model data
├── domain/         # AI business logic and entities
└── presentation/   # AI-powered UI components
```

## Key Features
- **Waste Detection**: Camera-based waste type identification
- **Smart Replies**: AI-generated message suggestions
- **Sorting Tips**: Intelligent waste sorting recommendations
- **Price Estimation**: AI-powered waste value estimation

## Components
- `AIService`: Core AI integration service
- `WasteDetectionBloc`: Camera-based detection
- `AIChatBloc`: Smart messaging assistance
- `DetectionResultWidget`: Display AI results

## AI Models
- Waste classification model
- Price prediction model
- Natural language processing for chat

## Screens
- `AIScannerScreen`: Camera interface for waste detection
- `AIAssistantScreen`: Chat interface with AI helper

## Integration Points
- **Household**: Waste detection during posting
- **Messaging**: Smart reply suggestions
- **Junkshop**: Price estimation and sorting tips

## Technical Notes
- Models stored in `assets/ai_models/`
- Fallback to cloud API when local inference unavailable
- Caching for offline functionality

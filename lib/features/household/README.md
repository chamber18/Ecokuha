# Household Feature

## Overview
Main feature for household users to post waste, track collections, and manage their account.

## Architecture
```
household/
├── data/           # Waste listings API, local data
├── domain/         # Household business logic
└── presentation/   # Household-specific UI
```

## Key Features
- **Home Dashboard**: Overview of waste postings and collections
- **Post Waste**: Create waste listings with AI detection
- **Track Collections**: Real-time tracking of pickup status
- **History**: View past collections and earnings
- **Profile Management**: Account settings and preferences

## Screens
- `HomeScreen`: Main dashboard with stats and quick actions
- `PostWasteScreen`: Create new waste listings
- `TrackScreen`: Monitor collection status
- `HistoryScreen`: View collection history
- `ProfileScreen`: Manage account settings

## BLoC Components
- `HomeBloc`: Dashboard data and stats
- `PostWasteBloc`: Waste listing creation
- `TrackBloc`: Collection tracking
- `HistoryBloc`: Historical data
- `AIDetectionBloc`: Waste type detection

## Integrations
- AI feature for waste detection
- Maps feature for location services
- Messaging for communication with collectors

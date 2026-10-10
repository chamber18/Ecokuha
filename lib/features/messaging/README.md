# Messaging Feature

## Overview
Real-time communication system between users with AI-powered assistance and smart suggestions.

## Architecture
```
messaging/
├── data/           # Chat API, local message storage
├── domain/         # Messaging business logic
└── presentation/   # Chat interface and components
```

## Key Features
- **Real-time Chat**: Instant messaging between users
- **AI Assistant**: Smart reply suggestions and help
- **Message Templates**: Quick response options
- **Group Chats**: Multi-user conversations
- **File Sharing**: Share photos and documents

## Screens
- `ChatListScreen`: Overview of all conversations
- `ConversationScreen`: Individual chat interface
- `NewChatScreen`: Start new conversations

## BLoC Components
- `ChatListBloc`: Manage conversation list
- `ConversationBloc`: Handle individual chats
- `AIAssistantBloc`: Smart suggestions and help

## Message Types
- Text messages
- Image attachments
- Location sharing
- Voice messages (future)
- System notifications

## AI Integration
- Smart reply suggestions
- Auto-translation (English/Filipino)
- Context-aware responses
- Spam detection

## User Interactions
- **Household ↔ Collector**: Collection coordination
- **Junkshop ↔ Collector**: Task assignment
- **All Users ↔ AI**: Smart assistance

## Technical Features
- WebSocket real-time connection
- Offline message queue
- End-to-end encryption (future)
- Message persistence

# Notifications Feature

## Overview
Push notification system for real-time updates and user engagement across all features.

## Architecture
```
notifications/
├── data/           # Notification API, local storage
├── domain/         # Notification business logic
└── presentation/   # Notification UI and settings
```

## Key Features
- **Push Notifications**: Real-time alerts and updates
- **In-App Notifications**: Local notification display
- **Notification Categories**: Different types for different events
- **User Preferences**: Customizable notification settings
- **Notification History**: View past notifications

## Notification Types
- **Collection Updates**: Pickup status changes
- **New Messages**: Chat notifications
- **Task Assignments**: New collector tasks
- **Payment Notifications**: Transaction confirmations
- **System Alerts**: App updates and maintenance

## Components
- `NotificationService`: Core notification handling
- `NotificationsBloc`: Notification state management
- `NotificationItem`: Individual notification display
- `NotificationSettingsWidget`: User preferences

## Screens
- `NotificationsScreen`: Notification history and management

## User-Specific Notifications

### Household Users
- Collection scheduled/completed
- Payment received
- New messages from collectors
- AI detection results

### Junkshop Users
- New pickup requests
- Collector status updates
- Inventory alerts
- Business analytics reports

### Collector Users
- New task assignments
- Route changes
- Payment notifications
- Performance updates

## Technical Features
- Firebase Cloud Messaging integration
- Local notification scheduling
- Background notification handling
- Deep linking to relevant screens

# Collector Feature

## Overview
Mobile workforce management for waste collectors including task assignment, route optimization, and performance tracking.

## Architecture
```
collector/
├── data/           # Task data, route information
├── domain/         # Collection workflow logic
└── presentation/   # Collector-specific UI
```

## Key Features
- **Task Management**: View and manage assigned collections
- **Route Optimization**: Efficient collection routes
- **Real-time Updates**: Update collection status and photos
- **Availability Management**: Set working hours and availability
- **Performance Tracking**: Earnings and efficiency metrics
- **Photo Verification**: Document collections with photos

## Screens
- `HomeScreen`: Task overview and daily assignments
- `TaskDetailsScreen`: Detailed collection information
- `CollectionsScreen`: Active and completed collections
- `ProfileScreen`: Personal settings and performance

## BLoC Components
- `CollectorHomeBloc`: Dashboard and task overview
- `TaskBloc`: Individual task management
- `CollectionsBloc`: Collection history and status
- `AvailabilityBloc`: Working schedule management

## Workflow States
1. **Assigned**: Task received from junkshop
2. **En Route**: Traveling to collection point
3. **Collecting**: At location, gathering waste
4. **Verification**: Photo documentation
5. **Completed**: Task finished, payment processed

## Integrations
- Maps feature for navigation
- Camera service for photo verification
- Messaging for coordination

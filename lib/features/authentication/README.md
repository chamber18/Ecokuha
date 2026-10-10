# Authentication Feature

## Overview
Handles user authentication and registration for all user types (Household, Junkshop, Collector).

## Architecture
```
authentication/
├── data/           # Data layer - API calls, local storage
├── domain/         # Business logic - entities, repositories, use cases
└── presentation/   # UI layer - screens, widgets, BLoC
```

## User Flows
- **Login**: Email/password authentication
- **Registration**: Multi-step registration for different user types
- **Role Selection**: Choose between Household, Junkshop, or Collector

## Key Components
- `AuthRepository`: Handles authentication API calls
- `LoginBloc`: Manages login state
- `RegisterBloc`: Manages registration flow
- `RoleSelectionScreen`: User type selection

## Registration Flows
1. **Household**: Basic profile + address verification
2. **Junkshop**: Business registration + document verification
3. **Collector**: Worker registration + background check + approval process

## Dependencies
- Core services (storage, network)
- Shared widgets and utilities

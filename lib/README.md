# EcoKuha - Project Architecture

## Overview
This document outlines the architecture and structure of the EcoKuha project, a comprehensive waste management application with multiple user roles.

## Project Structure
```
lib/
├── app/                    # App configuration and routing
├── core/                   # Shared utilities and services
├── features/               # Feature modules (Clean Architecture)
├── shared/                 # Reusable components
└── l10n/                   # Internationalization

test/
├── unit/                   # Unit tests
├── widget/                 # Widget tests
├── integration/            # Integration tests
├── helpers/                # Test utilities
└── mocks/                  # Mock objects
```

## Architecture Principles

### Clean Architecture
Each feature follows the Clean Architecture pattern:
- **Data Layer**: API calls, local storage, external data sources
- **Domain Layer**: Business logic, entities, use cases
- **Presentation Layer**: UI, state management (BLoC), user interactions

### Feature Independence
- Each feature is completely independent
- Features communicate through shared domain entities
- No direct dependencies between features

### State Management
- **BLoC Pattern**: Predictable state management with events and states
- **Repository Pattern**: Abstract data access
- **Dependency Injection**: Loose coupling and testability

## User Roles

### 1. Household Users
- Post waste for collection
- Track pickup status
- View earnings and history
- Communicate with collectors

### 2. Junkshop Owners
- Manage pickup requests
- Coordinate collectors
- Track inventory and analytics
- Process payments

### 3. Collectors
- Receive task assignments
- Navigate to collection points
- Update status and photos
- Track performance and earnings

## Key Features

### AI-Powered
- Waste type detection via camera
- Smart reply suggestions
- Price estimation
- Sorting recommendations

### Real-time
- Live location tracking
- Instant messaging
- Status updates
- Push notifications

### Multi-language
- English and Filipino support
- Localized content and formats

## Development Guidelines

### Code Organization
1. Follow feature-based folder structure
2. Maintain clean architecture layers
3. Write comprehensive tests for all components
4. Use shared components for common UI elements

### Testing Strategy
- **Unit Tests**: Test business logic and use cases
- **Widget Tests**: Test UI components and interactions
- **Integration Tests**: Test complete user workflows
- **Mock Objects**: Isolate components during testing

### Performance Considerations
- Lazy loading of features
- Image optimization and caching
- Efficient state management
- Background task optimization

## Getting Started
1. Review individual feature README files
2. Set up development environment
3. Configure API endpoints and services
4. Run tests to validate setup
5. Begin feature implementation

## Contributing
- Follow established architecture patterns
- Write tests for new features
- Update documentation for changes
- Follow code style guidelines

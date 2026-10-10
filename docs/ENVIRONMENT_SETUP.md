# Environment Setup Guide

## Setting Up Your Environment Variables

This project uses environment variables to manage sensitive configuration data like API keys, database credentials, and third-party service tokens.

### 1. Copy the Example File

First, copy the example environment file to create your local configuration:

```bash
cp .env.example .env
```

### 2. Fill in Your Values

Open the `.env` file and replace the placeholder values with your actual configuration:

```bash
# Example: Replace placeholder with your actual API key
API_KEY=your_actual_api_key_here
```

### 3. Environment Variables Explained

#### API Configuration
- **API_BASE_URL_DEV/STAGING/PROD**: Your backend API endpoints for different environments
- **API_KEY**: Authentication key for your backend API

#### Firebase (when enabled)
- **FIREBASE_API_KEY**: From Firebase project settings
- **FIREBASE_PROJECT_ID**: Your Firebase project ID
- **FIREBASE_AUTH_DOMAIN**: Usually `your-project.firebaseapp.com`

#### Third-party Services
- **GOOGLE_MAPS_API_KEY**: For location and mapping features
- **GOOGLE_CLIENT_ID**: For Google Sign-In authentication
- **STRIPE_PUBLISHABLE_KEY**: For payment processing (if needed)

### 4. Security Best Practices

🚨 **NEVER** commit your `.env` file to version control!

The `.env` file is already listed in `.gitignore` to prevent accidental commits.

### 5. Getting API Keys

#### Option A: Local Development with ngrok
1. Set up your local API server
2. Install ngrok: `npm install -g ngrok`
3. Expose your local server: `ngrok http 3000`
4. Copy the HTTPS URL to `API_BASE_URL_DEV`

#### Option B: Backend-as-a-Service
1. **Supabase**: Create project → Settings → API → Copy URL and anon key
2. **Firebase**: Project Settings → General → Web app config
3. **Appwrite**: Create project → Settings → Copy endpoint and project ID

#### Option C: Mock Services
1. **Mockoon**: Create mock API → Run locally → Use localhost URL
2. **Postman**: Create mock server → Copy mock URL
3. **MockAPI**: Create project → Copy generated API URL

### 6. Environment-Specific Configuration

The app automatically selects the appropriate API URL based on the build environment:

```bash
# Development (default)
flutter run

# Staging
flutter run --dart-define=ENVIRONMENT=staging

# Production
flutter run --dart-define=ENVIRONMENT=prod
```

### 7. Troubleshooting

#### Missing Environment Variables
If you see errors about missing config, ensure:
1. Your `.env` file exists in the project root
2. All required variables are set (see `.env.example`)
3. No typos in variable names

#### API Connection Issues
1. Check if your API URL is accessible
2. Verify API key is correct
3. Ensure CORS is configured on your backend
4. Check network connectivity

### 8. Development vs Production

#### Development
- Use mock data when `MOCK_API_RESPONSES=true`
- Enable debug logging with `DEBUG_MODE=true`
- Use test credentials for faster development

#### Production
- Set `MOCK_API_RESPONSES=false`
- Use actual production API endpoints
- Disable debug logging for performance
- Use real API keys and credentials

For more help, check the project documentation or create an issue.
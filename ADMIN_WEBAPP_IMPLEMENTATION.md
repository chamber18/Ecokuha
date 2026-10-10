# EcoKuha Admin Web Application · Implementation Guide

**Purpose:** Standalone web application for administrators to approve junkshop applications and manage households. Collectors are managed by junkshops and not accessible to admin.

**Deployment Priority:** Web-based for rapid deployment without mobile app build cycles.

---

## ⚠️ CRITICAL: Read This First

### Existing Mobile App Context
This admin webapp connects to an **EXISTING Flutter mobile app** with established Firestore structure. You **MUST** use the exact same:
- Firebase project: `EcoKuha-auth`
- Collection names: `/junkshops/{uid}`, `/households/{uid}`, `/collectors/{uid}`
- Field names (snake_case): `application_status`, `junkshop_profile`, `business_name`, etc.
- Document structure (nested objects): See Data Models section

### DO NOT:
- Create new collections or rename existing ones
- Change field naming conventions (mobile app uses snake_case)
- Modify document structure (nested objects like `junkshop_profile.business`)
- Deploy security rules without testing against mobile app first

### Key Firebase Project Details
- **Project ID:** `EcoKuha-auth`
- **Location:** `asia-southeast1`
- **Sender ID:** `996365911967`
- **App ID (Android):** `1:996365911967:android:d74acec325f944e97a9faa`
- **Auth Domain:** `EcoKuha-auth.firebaseapp.com`
- **Storage Bucket:** `EcoKuha-auth.appspot.com`

---

## Table of Contents
1. [Overview](#overview)
2. [Technology Stack](#technology-stack)
3. [Project Setup](#project-setup)
4. [Firebase Configuration](#firebase-configuration)
5. [Firestore Security Rules](#firestore-security-rules)
6. [Storage Security Rules](#storage-security-rules)
7. [Admin Authentication](#admin-authentication)
8. [Features & Screens](#features--screens)
9. [Project Structure](#project-structure)
10. [Key Components](#key-components)
11. [Data Models](#data-models)
12. [Deployment](#deployment)

---

## Overview

### Admin Capabilities
- **Junkshop Management:**
  - View pending junkshop applications
  - Approve/reject applications with optional reason
  - View all registered junkshops
  - Edit junkshop details
  - Disable/enable junkshop accounts
  - View junkshop documents (business permit, owner ID)

- **Household Management:**
  - View all registered households
  - Edit household details
  - Disable/enable household accounts
  - View household posting history
  - View household statistics

- **Dashboard:**
  - Total users by role (junkshops, households, collectors)
  - Pending junkshop applications count
  - Recent activity feed
  - System statistics

### Out of Scope
- Collector management (handled by junkshops)
- Direct posting/collection management
- Financial transactions

---

## Technology Stack

### Recommended: React + Firebase
```json
{
  "framework": "React 18+",
  "language": "TypeScript",
  "styling": "Tailwind CSS",
  "routing": "React Router v6",
  "state": "React Context + Hooks",
  "firebase": {
    "auth": "^10.x",
    "firestore": "^4.x",
    "storage": "^0.12.x"
  },
  "ui-library": "shadcn/ui or Material-UI",
  "icons": "lucide-react or react-icons",
  "deployment": "Firebase Hosting or Vercel"
}
```

### Alternative: Next.js
For SSR/SSG capabilities and better SEO:
```json
{
  "framework": "Next.js 14+",
  "styling": "Tailwind CSS",
  "deployment": "Vercel"
}
```

---

## Project Setup

### 1. Create React App with TypeScript
```bash
# Using Vite (recommended for speed)
npm create vite@latest ecokuha-admin-webapp -- --template react-ts
cd ecokuha-admin-webapp
npm install

# Install dependencies
npm install firebase react-router-dom
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

### 2. Install UI Library (Optional)
```bash
# Option 1: shadcn/ui
npx shadcn-ui@latest init

# Option 2: Material-UI
npm install @mui/material @emotion/react @emotion/styled
```

### 3. Install Additional Dependencies
```bash
npm install react-hot-toast          # Toast notifications
npm install date-fns                 # Date formatting
npm install lucide-react             # Icons
npm install recharts                 # Charts for dashboard
npm install react-table              # Table component
```

---

## Firebase Configuration

### 1. Register Web App in Firebase Console
1. Go to Firebase Console → Project Settings
2. Add a new web app named "EcoKuha Admin Web"
3. Copy the Firebase config object

### 2. Create Firebase Config File
**`src/config/firebase.ts`**
```typescript
import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator } from 'firebase/firestore';
import { getStorage, connectStorageEmulator } from 'firebase/storage';

// IMPORTANT: These are the ACTUAL credentials for the EcoKuha project
// Project ID: EcoKuha-auth
// Located in: firebase.json and firebase_options.dart of the mobile app
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: "EcoKuha-auth.firebaseapp.com",
  projectId: "EcoKuha-auth",
  storageBucket: "EcoKuha-auth.appspot.com",
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || "996365911967",
  appId: import.meta.env.VITE_FIREBASE_APP_ID || "1:996365911967:android:d74acec325f944e97a9faa",
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize services
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// Connect to emulators in development (DISABLE FOR PRODUCTION)
if (import.meta.env.DEV && import.meta.env.VITE_USE_EMULATORS === 'true') {
  connectAuthEmulator(auth, 'http://localhost:9099');
  connectFirestoreEmulator(db, 'localhost', 8080);
  connectStorageEmulator(storage, 'localhost', 9199);
}

export default app;
```

### 3. Environment Variables
**`.env`**
```env
# Firebase Project Configuration
# Project ID: EcoKuha-auth
# Get these values from Firebase Console > Project Settings > General

VITE_FIREBASE_API_KEY=your_api_key_here
VITE_FIREBASE_AUTH_DOMAIN=EcoKuha-auth.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=EcoKuha-auth
VITE_FIREBASE_STORAGE_BUCKET=EcoKuha-auth.appspot.com
VITE_FIREBASE_MESSAGING_SENDER_ID=996365911967
VITE_FIREBASE_APP_ID=1:996365911967:android:d74acec325f944e97a9faa

# Development Settings
VITE_USE_EMULATORS=false
```

**How to get your API Key:**
1. Go to Firebase Console: https://console.firebase.google.com/
2. Select "EcoKuha-auth" project
3. Go to Project Settings (gear icon) > General tab
4. Scroll to "Your apps" section
5. Click "Add app" > Web (or use existing web app)
6. Copy the `apiKey` value from the config object

**`.env.local.example`** (for team reference)
```env
# Copy this to .env.local and fill in actual values
VITE_FIREBASE_API_KEY=
VITE_FIREBASE_AUTH_DOMAIN=EcoKuha-auth.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=EcoKuha-auth
VITE_FIREBASE_STORAGE_BUCKET=EcoKuha-auth.appspot.com
VITE_FIREBASE_MESSAGING_SENDER_ID=996365911967
VITE_FIREBASE_APP_ID=1:996365911967:android:d74acec325f944e97a9faa
```

---

## Firestore Security Rules

### Updated Rules with Admin Access
**`firestore.rules`**
```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is admin
    function isAdmin() {
      return request.auth != null && 
             exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }
    
    // ======================
    // ADMIN COLLECTION
    // ======================
    match /admins/{adminId} {
      // Only admins can read admin list
      allow read: if isAdmin();
      // Only existing admins can create new admins (or use Firebase Admin SDK)
      allow create: if isAdmin();
      // Admins cannot modify or delete themselves through client
      allow update, delete: if false;
    }
    
    // ======================
    // JUNKSHOPS COLLECTION
    // ======================
    match /junkshops/{junkshopId} {
      // Admins can read all junkshops, owners can read their own
      allow read: if isAdmin() || isOwner(junkshopId);
      
      // Admins can update junkshop status and details
      // Owners can update their own profile
      allow update: if isAdmin() || isOwner(junkshopId);
      
      // Only authenticated users can create (registration)
      allow create: if isAuthenticated();
      
      // Only admins can delete
      allow delete: if isAdmin();
      
      // Subcollections for junkshop data
      match /{subcollection}/{document=**} {
        allow read: if isAdmin() || isOwner(junkshopId);
        allow write: if isOwner(junkshopId);
      }
    }
    
    // ======================
    // HOUSEHOLDS COLLECTION
    // ======================
    match /households/{householdId} {
      // Admins can read all households, owners can read their own
      allow read: if isAdmin() || isOwner(householdId);
      
      // Admins and owners can update
      allow update: if isAdmin() || isOwner(householdId);
      
      // Only authenticated users can create (registration)
      allow create: if isAuthenticated();
      
      // Only admins can delete
      allow delete: if isAdmin();
      
      // Household postings subcollection
      match /postings/{postingId} {
        allow read: if isAdmin() || isOwner(householdId);
        allow write: if isOwner(householdId);
      }
    }
    
    // ======================
    // COLLECTORS COLLECTION
    // ======================
    match /collectors/{collectorId} {
      // Collectors managed by junkshops, not admin
      // Admins can only read for statistics
      allow read: if isAdmin() || isOwner(collectorId);
      allow write: if isOwner(collectorId);
      
      // Junkshops can read collectors in their network
      match /{subcollection}/{document=**} {
        allow read: if isAdmin() || isOwner(collectorId);
        allow write: if isOwner(collectorId);
      }
    }
    
    // ======================
    // CONVERSATIONS COLLECTION
    // ======================
    match /conversations/{conversationId} {
      // Admins can read all for moderation
      allow read: if isAdmin() || 
                     isAuthenticated() && 
                     request.auth.uid in resource.data.participantIds;
      allow write: if isAuthenticated() && 
                      request.auth.uid in resource.data.participantIds;
    }
    
    // ======================
    // SYSTEM COLLECTIONS
    // ======================
    match /system/{document=**} {
      allow read: if isAdmin();
      allow write: if isAdmin();
    }
  }
}
```

### Creating Admin Users - CRITICAL SECURITY

**⚠️ IMPORTANT: Admin accounts can ONLY be created through:**
1. Firebase Admin SDK (server-side script)
2. Firebase Console manually
3. Never through the web app UI

This prevents unauthorized users from creating admin accounts.

---

## Admin Account Creation Guide

### Method 1: Using Firebase Admin SDK (Recommended)

**Step 1: Get Firebase Service Account Key**
1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate New Private Key"
3. Save the JSON file as `firebase-service-account-key.json`
4. **NEVER commit this file to git** (add to .gitignore)

**Step 2: Create Admin Script**

Place this in your project root or in the mobile app's `scripts/` folder:

**`scripts/create_admin.js`**
```javascript
const admin = require('firebase-admin');
const readline = require('readline');
const serviceAccount = require('./firebase-service-account-key.json');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://EcoKuha-auth.firebaseio.com"
});

const db = admin.firestore();
const auth = admin.auth();

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function createAdmin() {
  try {
    console.log('\n=== EcoKuha Admin Account Creator ===\n');
    
    // Get admin details from user
    const email = await question('Enter admin email: ');
    const name = await question('Enter admin name: ');
    const password = await question('Enter temporary password (min 6 chars): ');
    
    if (password.length < 6) {
      console.error('❌ Password must be at least 6 characters');
      rl.close();
      return;
    }
    
    console.log('\n🔄 Creating admin account...\n');
    
    // Check if admin already exists
    try {
      const existingUser = await auth.getUserByEmail(email);
      console.log('⚠️  User already exists in Firebase Auth');
      
      // Check if they're already an admin
      const adminDoc = await db.collection('admins').doc(existingUser.uid).get();
      if (adminDoc.exists) {
        console.log('❌ This user is already an admin');
        rl.close();
        return;
      }
      
      // Add existing user to admins collection
      await db.collection('admins').doc(existingUser.uid).set({
        uid: existingUser.uid,
        email: existingUser.email,
        name: name,
        role: 'admin',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
        createdBy: 'system',
      });
      
      console.log('✅ Existing user added to admins collection');
      console.log(`   UID: ${existingUser.uid}`);
      console.log(`   Email: ${existingUser.email}`);
      
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        // Create new user
        const userRecord = await auth.createUser({
          email: email,
          password: password,
          displayName: name,
          emailVerified: true,
        });
        
        // Add to admins collection
        await db.collection('admins').doc(userRecord.uid).set({
          uid: userRecord.uid,
          email: email,
          name: name,
          role: 'admin',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isActive: true,
          createdBy: 'system',
          mustChangePassword: true,
        });
        
        console.log('✅ Admin account created successfully!\n');
        console.log('📧 Email:', email);
        console.log('🆔 UID:', userRecord.uid);
        console.log('🔑 Temporary Password:', password);
        console.log('\n⚠️  User must change password on first login\n');
      } else {
        throw error;
      }
    }
    
  } catch (error) {
    console.error('❌ Error creating admin:', error.message);
    if (error.code) {
      console.error('   Error Code:', error.code);
    }
  } finally {
    rl.close();
    process.exit(0);
  }
}

// Run the script
createAdmin();
```

**Step 3: Create package.json for the script**

**`scripts/package.json`**
```json
{
  "name": "ecokuha-admin-scripts",
  "version": "1.0.0",
  "description": "Admin management scripts for EcoKuha",
  "scripts": {
    "create-admin": "node create_admin.js",
    "list-admins": "node list_admins.js"
  },
  "dependencies": {
    "firebase-admin": "^12.0.0"
  }
}
```

**Step 4: Run the script**
```bash
cd scripts
npm install
npm run create-admin
```

**Step 5: Login to Admin Web App**
1. Go to your deployed admin web app or `http://localhost:5173/login`
2. Enter the email and temporary password
3. Change password on first login (implement this in Settings page)

---

### Method 2: Using Firebase Console (Quick & Simple)

**Step 1: Create User in Firebase Auth**
1. Go to Firebase Console → Authentication → Users
2. Click "Add User"
3. Enter email and temporary password
4. Click "Add User" and copy the UID

**Step 2: Add to Admins Collection**
1. Go to Firebase Console → Firestore Database
2. Click "Start Collection"
3. Collection ID: `admins`
4. Document ID: [paste the UID from step 1]
5. Add fields:
   - `uid` (string): [paste UID]
   - `email` (string): [admin email]
   - `name` (string): [admin name]
   - `role` (string): `admin`
   - `isActive` (boolean): `true`
   - `createdAt` (timestamp): [current time]
   - `createdBy` (string): `manual`
6. Click "Save"

---

### Method 3: List All Admins Script

**`scripts/list_admins.js`**
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./firebase-service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function listAdmins() {
  try {
    console.log('\n=== EcoKuha Admin Accounts ===\n');
    
    const adminsSnapshot = await db.collection('admins').get();
    
    if (adminsSnapshot.empty) {
      console.log('⚠️  No admin accounts found');
      return;
    }
    
    console.log(`Found ${adminsSnapshot.size} admin(s):\n`);
    
    adminsSnapshot.forEach((doc, index) => {
      const admin = doc.data();
      console.log(`${index + 1}. ${admin.name}`);
      console.log(`   Email: ${admin.email}`);
      console.log(`   UID: ${admin.uid}`);
      console.log(`   Status: ${admin.isActive ? '✅ Active' : '❌ Inactive'}`);
      console.log(`   Created: ${admin.createdAt?.toDate().toLocaleString() || 'Unknown'}`);
      console.log('');
    });
    
  } catch (error) {
    console.error('❌ Error listing admins:', error);
  } finally {
    process.exit(0);
  }
}

listAdmins();
```

Run with: `npm run list-admins`

---

### Method 4: PowerShell Script (Windows Users)

For quick admin creation on Windows without Node.js:

**`scripts/create_admin.ps1`**
```powershell
# EcoKuha - Create Admin Account via Firebase REST API
# Requires Firebase Web API Key

param(
    [Parameter(Mandatory=$true)]
    [string]$Email,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [Parameter(Mandatory=$true)]
    [string]$Name
)

# Firebase project configuration
$FirebaseApiKey = "YOUR_WEB_API_KEY_HERE"  # Get from Firebase Console
$ProjectId = "EcoKuha-auth"

Write-Host "`n=== EcoKuha Admin Account Creator ===" -ForegroundColor Green
Write-Host "Email: $Email"
Write-Host "Name: $Name`n"

# Step 1: Create user via Firebase Auth REST API
Write-Host "Creating Firebase Auth user..." -ForegroundColor Yellow

$signUpUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$FirebaseApiKey"
$signUpBody = @{
    email = $Email
    password = $Password
    returnSecureToken = $true
} | ConvertTo-Json

try {
    $authResponse = Invoke-RestMethod -Uri $signUpUrl -Method Post -Body $signUpBody -ContentType "application/json"
    $uid = $authResponse.localId
    $idToken = $authResponse.idToken
    
    Write-Host "✅ Firebase Auth user created" -ForegroundColor Green
    Write-Host "   UID: $uid`n"
    
    # Step 2: Add to admins collection via Firestore REST API
    Write-Host "Adding to admins collection..." -ForegroundColor Yellow
    
    $firestoreUrl = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/documents/admins?documentId=$uid"
    
    $adminData = @{
        fields = @{
            uid = @{ stringValue = $uid }
            email = @{ stringValue = $Email }
            name = @{ stringValue = $Name }
            role = @{ stringValue = "admin" }
            isActive = @{ booleanValue = $true }
            createdAt = @{ timestampValue = (Get-Date -Format "o") }
            createdBy = @{ stringValue = "powershell-script" }
            mustChangePassword = @{ booleanValue = $true }
        }
    } | ConvertTo-Json -Depth 10
    
    $headers = @{
        "Authorization" = "Bearer $idToken"
        "Content-Type" = "application/json"
    }
    
    $firestoreResponse = Invoke-RestMethod -Uri $firestoreUrl -Method Post -Body $adminData -Headers $headers
    
    Write-Host "✅ Admin account created successfully!`n" -ForegroundColor Green
    Write-Host "📧 Email: $Email"
    Write-Host "🆔 UID: $uid"
    Write-Host "🔑 Password: $Password"
    Write-Host "`n⚠️  User must change password on first login`n" -ForegroundColor Yellow
    
} catch {
    Write-Host "❌ Error creating admin: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Response: $($_.ErrorDetails.Message)" -ForegroundColor Red
    exit 1
}
```

**Usage:**
```powershell
# Get your Web API Key from Firebase Console first
# Then run:
.\create_admin.ps1 -Email "admin@example.com" -Password "SecurePass123!" -Name "Admin User"
```

**To get Firebase Web API Key:**
1. Go to Firebase Console → Project Settings → General
2. Under "Your apps" → Web apps section
3. Copy the `apiKey` value
4. Replace `YOUR_WEB_API_KEY_HERE` in the script

---

### Admin Collection Schema

**Collection:** `/admins/{uid}`

```typescript
interface Admin {
  uid: string;              // Firebase Auth UID
  email: string;            // Admin email
  name: string;             // Admin display name
  role: 'admin';            // Always 'admin'
  isActive: boolean;        // Can be disabled by super admin
  createdAt: Timestamp;     // When account was created
  createdBy: string;        // 'system', 'manual', or admin UID
  mustChangePassword?: boolean; // Force password change on first login
  lastLoginAt?: string;     // ISO timestamp of last login
  permissions?: {           // Optional granular permissions
    canApproveJunkshops: boolean;
    canManageHouseholds: boolean;
    canCreateAdmins: boolean;  // Super admin only
  };
}
```

---

### Security Best Practices

**1. Service Account Key Protection**
```gitignore
# Add to .gitignore
firebase-service-account-key.json
*-service-account-key.json
serviceAccountKey.json
```

**2. Limit Admin Creation**
- Only authorized personnel should have access to the service account key
- Store service account key in secure location (password manager, encrypted storage)
- Never share service account key via email or chat
- Rotate service account keys periodically

**3. Admin Verification in Web App**
The web app MUST check if user is in `/admins` collection before granting access:

```typescript
// In AuthContext
useEffect(() => {
  const unsubscribe = auth.onAuthStateChanged(async (user) => {
    setUser(user);
    
    if (user) {
      // CRITICAL: Check if user is in admins collection
      const adminDoc = await getDoc(doc(db, 'admins', user.uid));
      
      if (!adminDoc.exists()) {
        // User is authenticated but NOT an admin
        await firebaseSignOut(auth);
        setIsAdmin(false);
        throw new Error('Unauthorized: Admin access required');
      }
      
      // Check if admin is active
      const adminData = adminDoc.data();
      if (!adminData.isActive) {
        await firebaseSignOut(auth);
        setIsAdmin(false);
        throw new Error('Admin account is disabled');
      }
      
      setIsAdmin(true);
    } else {
      setIsAdmin(false);
    }
    
    setLoading(false);
  });

  return unsubscribe;
}, []);
```

**4. Firestore Security Rules**
```javascript
// Only admins can read the admins collection
match /admins/{adminId} {
  allow read: if isAdmin();
  // NO write access from client - only via Admin SDK
  allow write: if false;
}
```

**5. Additional Security Measures**
- Implement 2FA for admin accounts (Firebase Auth supports this)
- Log all admin actions in an audit trail
- Set up Firebase App Check for admin web app
- Use strong password requirements
- Implement session timeout
- Monitor failed login attempts

---

### Creating Your First Admin

**Recommended First Steps:**

1. **Install Firebase Admin SDK in scripts folder:**
   ```bash
   cd scripts  # Or create a new admin-setup folder
   npm init -y
   npm install firebase-admin
   ```

2. **Get service account key from Firebase Console**

3. **Create the first admin:**
   ```bash
   node create_admin.js
   # Enter email: admin@yourdomain.com
   # Enter name: System Administrator
   # Enter password: [secure password]
   ```

4. **Test login on admin web app**

5. **Delete or secure the script** after creating admin(s)

6. **Future admins** can be created by:
   - Running the script again (if you keep it)
   - Using Firebase Console manually
   - Adding a "Create Admin" feature in the web app (only accessible to super admins with `canCreateAdmins` permission)

---

## Storage Security Rules

### Updated Rules with Admin Access
**`storage.rules`**
```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function to check if user is admin
    function isAdmin() {
      return request.auth != null && 
             firestore.exists(/databases/(default)/documents/admins/$(request.auth.uid));
    }
    
    // Helper function to check if user owns the resource
    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }
    
    // ======================
    // JUNKSHOP DOCUMENTS
    // ======================
    match /junkshops/{junkshopId}/documents/{document} {
      // Admins and owners can read documents
      allow read: if isAdmin() || isOwner(junkshopId);
      
      // Only owners can upload their documents
      allow write: if isOwner(junkshopId);
      
      // Only admins can delete
      allow delete: if isAdmin();
    }
    
    // ======================
    // COLLECTOR DOCUMENTS
    // ======================
    match /collectors/{collectorId}/documents/{document} {
      // Admins can read, collectors can read their own
      allow read: if isAdmin() || isOwner(collectorId);
      allow write: if isOwner(collectorId);
    }
    
    // ======================
    // HOUSEHOLD PROFILE IMAGES
    // ======================
    match /households/{householdId}/{allPaths=**} {
      // Admins and owners can read
      allow read: if isAdmin() || isOwner(householdId);
      allow write: if isOwner(householdId);
    }
    
    // ======================
    // POSTING IMAGES
    // ======================
    match /postings/{postingId}/{image} {
      // Anyone authenticated can read posting images
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

---

## Admin Authentication

### Auth Context Provider
**`src/contexts/AuthContext.tsx`**
```typescript
import React, { createContext, useContext, useEffect, useState } from 'react';
import { 
  User, 
  signInWithEmailAndPassword, 
  signOut as firebaseSignOut 
} from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../config/firebase';

interface AuthContextType {
  user: User | null;
  isAdmin: boolean;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({} as AuthContextType);

export const useAuth = () => useContext(AuthContext);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = auth.onAuthStateChanged(async (user) => {
      setUser(user);
      
      if (user) {
        // Check if user is admin
        const adminDoc = await getDoc(doc(db, 'admins', user.uid));
        setIsAdmin(adminDoc.exists());
      } else {
        setIsAdmin(false);
      }
      
      setLoading(false);
    });

    return unsubscribe;
  }, []);

  const signIn = async (email: string, password: string) => {
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    
    // Verify admin status
    const adminDoc = await getDoc(doc(db, 'admins', userCredential.user.uid));
    if (!adminDoc.exists()) {
      await firebaseSignOut(auth);
      throw new Error('Unauthorized: Admin access required');
    }
  };

  const signOut = async () => {
    await firebaseSignOut(auth);
  };

  return (
    <AuthContext.Provider value={{ user, isAdmin, loading, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  );
};
```

---

## Features & Screens

### 1. Dashboard (`/dashboard`)
**Components:**
- Statistics cards (total junkshops, households, collectors, pending applications)
- Recent junkshop applications
- System activity feed
- Quick actions

**Key Metrics:**
- Pending junkshop applications
- Total active users by role
- Recent registrations (last 7 days)
- Application approval rate

### 2. Junkshop Management (`/junkshops`)

#### 2.1 Pending Applications (`/junkshops/pending`)
**Features:**
- List of pending junkshop applications
- View application details
- Preview uploaded documents (business permit, owner ID)
- Approve/reject with optional reason
- Bulk actions

**Table Columns:**
- Business name
- Owner name
- Email
- Location
- Applied date
- Actions (View, Approve, Reject)

#### 2.2 Active Junkshops (`/junkshops/active`)
**Features:**
- Searchable/filterable table of approved junkshops
- View junkshop details
- Edit junkshop information
- Disable/enable accounts
- View linked collectors

**Table Columns:**
- Business name
- Owner name
- Contact
- Location
- Status (Active/Disabled)
- Collectors count
- Actions (View, Edit, Disable/Enable)

#### 2.3 Junkshop Detail View (`/junkshops/:id`)
**Sections:**
- Business information
- Contact details
- Location on map
- Documents viewer
- Linked collectors list
- Activity history
- Edit controls

### 3. Household Management (`/households`)

#### 3.1 Active Households (`/households/active`)
**Features:**
- Searchable/filterable table
- View household details
- Edit household information
- Disable/enable accounts
- View posting history

**Table Columns:**
- Name
- Email
- Contact
- Location
- Postings count
- Status (Active/Disabled)
- Actions (View, Edit, Disable/Enable)

#### 3.2 Household Detail View (`/households/:id`)
**Sections:**
- Personal information
- Contact details
- Location on map
- Posting history table
- Statistics (total postings, total weight collected)
- Edit controls

### 4. Settings (`/settings`)
**Features:**
- Admin profile management
- Change password
- System configuration
- Notification preferences

---

## Project Structure

```
ecokuha-admin-webapp/
├── public/
│   └── favicon.ico
├── src/
│   ├── assets/              # Images, icons
│   ├── components/
│   │   ├── common/          # Reusable components
│   │   │   ├── Button.tsx
│   │   │   ├── Card.tsx
│   │   │   ├── DataTable.tsx
│   │   │   ├── Modal.tsx
│   │   │   ├── Spinner.tsx
│   │   │   └── StatusBadge.tsx
│   │   ├── layout/          # Layout components
│   │   │   ├── AppLayout.tsx
│   │   │   ├── Navbar.tsx
│   │   │   └── Sidebar.tsx
│   │   ├── junkshop/        # Junkshop-specific components
│   │   │   ├── ApplicationCard.tsx
│   │   │   ├── ApplicationDetails.tsx
│   │   │   ├── DocumentViewer.tsx
│   │   │   ├── JunkshopForm.tsx
│   │   │   └── JunkshopTable.tsx
│   │   └── household/       # Household-specific components
│   │       ├── HouseholdForm.tsx
│   │       ├── HouseholdTable.tsx
│   │       └── PostingHistory.tsx
│   ├── config/
│   │   └── firebase.ts      # Firebase configuration
│   ├── contexts/
│   │   └── AuthContext.tsx  # Authentication context
│   ├── hooks/               # Custom React hooks
│   │   ├── useJunkshops.ts
│   │   ├── useHouseholds.ts
│   │   └── useStats.ts
│   ├── pages/
│   │   ├── auth/
│   │   │   └── LoginPage.tsx
│   │   ├── dashboard/
│   │   │   └── DashboardPage.tsx
│   │   ├── junkshops/
│   │   │   ├── PendingApplicationsPage.tsx
│   │   │   ├── ActiveJunkshopsPage.tsx
│   │   │   └── JunkshopDetailPage.tsx
│   │   ├── households/
│   │   │   ├── ActiveHouseholdsPage.tsx
│   │   │   └── HouseholdDetailPage.tsx
│   │   └── settings/
│   │       └── SettingsPage.tsx
│   ├── services/            # Firebase service functions
│   │   ├── junkshopService.ts
│   │   ├── householdService.ts
│   │   └── statsService.ts
│   ├── types/               # TypeScript types/interfaces
│   │   ├── junkshop.ts
│   │   ├── household.ts
│   │   └── common.ts
│   ├── utils/               # Utility functions
│   │   ├── formatters.ts
│   │   └── validators.ts
│   ├── App.tsx              # Main app component
│   ├── main.tsx             # Entry point
│   └── index.css            # Global styles
├── .env                     # Environment variables
├── .gitignore
├── package.json
├── tsconfig.json
├── vite.config.ts
└── tailwind.config.js
```

---

## Key Components

### 1. Protected Route Component
**`src/components/common/ProtectedRoute.tsx`**
```typescript
import { Navigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import Spinner from './Spinner';

interface ProtectedRouteProps {
  children: React.ReactNode;
}

const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ children }) => {
  const { user, isAdmin, loading } = useAuth();

  if (loading) {
    return <Spinner />;
  }

  if (!user || !isAdmin) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
};

export default ProtectedRoute;
```

### 2. Data Table Component
**`src/components/common/DataTable.tsx`**
```typescript
import React from 'react';

interface Column<T> {
  header: string;
  accessor: keyof T | ((row: T) => React.ReactNode);
  sortable?: boolean;
}

interface DataTableProps<T> {
  data: T[];
  columns: Column<T>[];
  loading?: boolean;
  onRowClick?: (row: T) => void;
}

function DataTable<T>({ data, columns, loading, onRowClick }: DataTableProps<T>) {
  if (loading) {
    return <div>Loading...</div>;
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            {columns.map((column, idx) => (
              <th key={idx} className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                {column.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {data.map((row, rowIdx) => (
            <tr 
              key={rowIdx}
              onClick={() => onRowClick?.(row)}
              className={onRowClick ? 'cursor-pointer hover:bg-gray-50' : ''}
            >
              {columns.map((column, colIdx) => (
                <td key={colIdx} className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {typeof column.accessor === 'function'
                    ? column.accessor(row)
                    : String(row[column.accessor])}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default DataTable;
```

### 3. Document Viewer Component
**`src/components/junkshop/DocumentViewer.tsx`**
```typescript
import React, { useState } from 'react';
import { getDownloadURL, ref } from 'firebase/storage';
import { storage } from '../../config/firebase';

interface DocumentViewerProps {
  junkshopId: string;
  documents: {
    business_permit?: string;
    owner_valid_id?: string;
  };
}

const DocumentViewer: React.FC<DocumentViewerProps> = ({ junkshopId, documents }) => {
  const [loading, setLoading] = useState(false);
  const [selectedDoc, setSelectedDoc] = useState<string | null>(null);

  const viewDocument = async (docUrl: string) => {
    setLoading(true);
    try {
      // Document URLs are already download URLs from Storage
      setSelectedDoc(docUrl);
    } catch (error) {
      console.error('Error viewing document:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold">Uploaded Documents</h3>
      
      <div className="grid grid-cols-2 gap-4">
        {documents.business_permit && (
          <div className="border rounded-lg p-4">
            <h4 className="font-medium mb-2">Business Permit</h4>
            <button
              onClick={() => viewDocument(documents.business_permit!)}
              className="text-blue-600 hover:underline"
            >
              View Document
            </button>
          </div>
        )}
        
        {documents.owner_valid_id && (
          <div className="border rounded-lg p-4">
            <h4 className="font-medium mb-2">Owner Valid ID</h4>
            <button
              onClick={() => viewDocument(documents.owner_valid_id!)}
              className="text-blue-600 hover:underline"
            >
              View Document
            </button>
          </div>
        )}
      </div>
      
      {selectedDoc && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-4 max-w-4xl max-h-[90vh] overflow-auto">
            <button
              onClick={() => setSelectedDoc(null)}
              className="mb-4 text-gray-600 hover:text-gray-900"
            >
              Close
            </button>
            <img src={selectedDoc} alt="Document" className="w-full" />
          </div>
        </div>
      )}
    </div>
  );
};

export default DocumentViewer;
```

---

## Data Models

### CRITICAL: Existing Firestore Structure
**The mobile app already has established data structures. DO NOT create new incompatible schemas.**

### Junkshop Document Structure (from mobile app)
**Collection Path:** `/junkshops/{uid}`

**TypeScript Interface:**
```typescript
export interface Junkshop {
  // Authentication & Status
  uid: string;
  email: string;
  application_status: 'pending' | 'approved' | 'rejected';
  rejection_reason?: string;
  is_profile_complete: boolean;
  isActive?: boolean;  // Added by admin for account management
  
  // Timestamps
  created_at: string; // ISO 8601 format
  updated_at: string;
  approvedAt?: string;
  approvedBy?: string; // Admin UID who approved
  reviewedAt?: string;
  reviewedBy?: string; // Admin UID who rejected
  
  // Owner Info (optional root-level for quick access)
  full_name?: string;
  
  // Nested Profile Object
  junkshop_profile: {
    business: {
      business_name: string;
      email: string;
      phone: string;
      business_type: string;
      description: string;
      owner_full_name: string;
      from_day: string;  // e.g., "Monday"
      to_day: string;    // e.g., "Sunday"
      open_time: string; // e.g., "08:00"
      close_time: string; // e.g., "18:00"
    };
    location: {
      address: string;
      note: string;
      lat: number;
      lng: number;
      service_radius: number;
      has_pickup_service: boolean;
    };
    documents: {
      business_permit?: string;  // Firebase Storage URL
      owner_valid_id?: string;   // Firebase Storage URL
    };
  };
}
```

**Example Document from Firestore:**
```json
{
  "uid": "4GqXUYTs0eVITdclw29GqF0BpzJ2",
  "email": "junkshop@example.com",
  "full_name": "Juan Dela Cruz",
  "application_status": "pending",
  "is_profile_complete": true,
  "created_at": "2026-01-02T10:30:00.000Z",
  "updated_at": "2026-01-02T10:30:00.000Z",
  "junkshop_profile": {
    "business": {
      "business_name": "Green Recycling Hub",
      "email": "junkshop@example.com",
      "phone": "09171234567",
      "business_type": "Recycling Center",
      "description": "We buy all types of recyclable materials",
      "owner_full_name": "Juan Dela Cruz",
      "from_day": "Monday",
      "to_day": "Sunday",
      "open_time": "08:00",
      "close_time": "18:00"
    },
    "location": {
      "address": "123 Recycling St, Manila",
      "note": "Near the market",
      "lat": 14.5995,
      "lng": 120.9842,
      "service_radius": 5.0,
      "has_pickup_service": true
    },
    "documents": {
      "business_permit": "https://firebasestorage.googleapis.com/.../business_permit.jpg",
      "owner_valid_id": "https://firebasestorage.googleapis.com/.../owner_id.jpg"
    }
  }
}
```

### Household Document Structure
**Collection Path:** `/households/{uid}`

**TypeScript Interface:**
```typescript
export interface Household {
  // Authentication & Status
  uid: string;
  email: string;
  isActive?: boolean;  // Added by admin
  
  // Personal Information
  name: string;
  contactNumber: string;
  address: string;
  latitude?: number;
  longitude?: number;
  
  // Timestamps
  created_at: string; // ISO 8601 format
  updated_at: string;
  last_login_at?: string;
  
  // Statistics (calculated from subcollections)
  totalPostings?: number;
  totalWeightCollected?: number;
}
```

### Household Postings Subcollection
**Collection Path:** `/households/{userId}/postings/{postingId}`

**Used for viewing household activity history**

### Collector Document Structure (READ-ONLY for Admin)
**Collection Path:** `/collectors/{uid}`

**Managed by junkshops, admin can only view for statistics**

```typescript
export interface Collector {
  uid: string;
  email: string;
  full_name: string;
  contact_number: string;
  application_status: 'pending' | 'approved' | 'rejected';
  junkshop_id?: string;  // Which junkshop they work for
  // ... other fields (not editable by admin)
}
```

**`src/types/household.ts`**
```typescript
export interface Household {
  uid: string;
  email: string;
  name: string;
  contactNumber: string;
  address: string;
  latitude?: number;
  longitude?: number;
  isActive: boolean;
  createdAt: any; // Firestore Timestamp
  totalPostings?: number;
  totalWeightCollected?: number;
}

export interface HouseholdFilters {
  isActive?: boolean;
  searchTerm?: string;
}
```

---

## Deployment

### Option 1: Firebase Hosting (Recommended)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize hosting in your project
firebase init hosting

# Build the app
npm run build

# Deploy
firebase deploy --only hosting
```

**`firebase.json`** (add hosting configuration)
```json
{
  "hosting": {
    "public": "dist",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

### Option 2: Vercel
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel

# Production deployment
vercel --prod
```

### Option 3: Netlify
```bash
# Install Netlify CLI
npm install -g netlify-cli

# Build the app
npm run build

# Deploy
netlify deploy --prod --dir=dist
```

---

## Implementation Checklist

### Phase 1: Setup & Authentication
- [ ] Create React app with TypeScript
- [ ] Install and configure dependencies
- [ ] Set up Firebase configuration
- [ ] Create admin authentication system
- [ ] Create admin user via Firebase Admin SDK
- [ ] Update Firestore security rules
- [ ] Update Storage security rules
- [ ] Deploy rules to Firebase

### Phase 2: Core Features
- [ ] Build AuthContext and protected routes
- [ ] Create layout components (Navbar, Sidebar)
- [ ] Build Dashboard page with statistics
- [ ] Create junkshop pending applications page
- [ ] Create junkshop detail view with document viewer
- [ ] Implement approve/reject functionality
- [ ] Create active junkshops management page
- [ ] Build household management pages

### Phase 3: Enhanced Features
- [ ] Add search and filtering
- [ ] Implement pagination for tables
- [ ] Add data export functionality (CSV)
- [ ] Create activity logs
- [ ] Add email notifications (optional)
- [ ] Implement bulk actions

### Phase 4: Testing & Deployment
- [ ] Test all CRUD operations
- [ ] Test security rules
- [ ] Verify admin permissions
- [ ] Test on different browsers
- [ ] Configure deployment platform
- [ ] Deploy to production
- [ ] Set up custom domain (optional)

---

## Security Considerations

1. **Admin Creation:** Only create admins through Firebase Admin SDK or Console, never through the web app
2. **Environment Variables:** Never commit `.env` file with API keys
3. **Security Rules:** Test rules thoroughly before deploying
4. **HTTPS Only:** Always use HTTPS in production
5. **Session Management:** Implement proper logout and session timeout
6. **Audit Logging:** Log all admin actions for accountability
7. **Input Validation:** Validate all inputs before Firestore writes
8. **Rate Limiting:** Consider implementing rate limiting for sensitive operations

---

## API Reference

### IMPORTANT: Field Naming Conventions
**Mobile app uses snake_case for all Firestore fields. Admin webapp MUST match this.**

Examples:
- ✅ `application_status` (correct)
- ❌ `applicationStatus` (wrong - will create duplicate field)
- ✅ `junkshop_profile` (correct)
- ❌ `junkshopProfile` (wrong)

### Junkshop Service (Complete Implementation)
**`src/services/junkshopService.ts`**
```typescript
import { 
  collection, 
  query, 
  where, 
  getDocs, 
  doc, 
  updateDoc,
  getDoc,
  Timestamp,
  orderBy,
  limit
} from 'firebase/firestore';
import { db } from '../config/firebase';
import { Junkshop } from '../types/junkshop';

export const junkshopService = {
  // Get pending applications
  async getPendingApplications(): Promise<Junkshop[]> {
    const q = query(
      collection(db, 'junkshops'),
      where('application_status', '==', 'pending'),
      orderBy('created_at', 'desc')
    );
    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => ({ 
      uid: doc.id,
      ...doc.data() 
    } as Junkshop));
  },

  // Get active junkshops
  async getActiveJunkshops(): Promise<Junkshop[]> {
    const q = query(
      collection(db, 'junkshops'),
      where('application_status', '==', 'approved')
    );
    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => ({ 
      uid: doc.id,
      ...doc.data() 
    } as Junkshop));
  },

  // Get all junkshops (for admin overview)
  async getAllJunkshops(): Promise<Junkshop[]> {
    const snapshot = await getDocs(collection(db, 'junkshops'));
    return snapshot.docs.map(doc => ({ 
      uid: doc.id,
      ...doc.data() 
    } as Junkshop));
  },

  // Get single junkshop by ID
  async getJunkshopById(junkshopId: string): Promise<Junkshop | null> {
    const docRef = doc(db, 'junkshops', junkshopId);
    const docSnap = await getDoc(docRef);
    
    if (docSnap.exists()) {
      return { uid: docSnap.id, ...docSnap.data() } as Junkshop;
    }
    return null;
  },

  // Approve application
  async approveApplication(junkshopId: string, adminId: string): Promise<void> {
    const junkshopRef = doc(db, 'junkshops', junkshopId);
    await updateDoc(junkshopRef, {
      application_status: 'approved',
      approvedAt: new Date().toISOString(),
      approvedBy: adminId,
      isActive: true,
      updated_at: new Date().toISOString(),
    });
  },

  // Reject application
  async rejectApplication(
    junkshopId: string, 
    adminId: string, 
    reason: string
  ): Promise<void> {
    const junkshopRef = doc(db, 'junkshops', junkshopId);
    await updateDoc(junkshopRef, {
      application_status: 'rejected',
      rejection_reason: reason,
      reviewedAt: new Date().toISOString(),
      reviewedBy: adminId,
      updated_at: new Date().toISOString(),
    });
  },

  // Toggle active status
  async toggleActiveStatus(junkshopId: string, isActive: boolean): Promise<void> {
    const junkshopRef = doc(db, 'junkshops', junkshopId);
    await updateDoc(junkshopRef, { 
      isActive,
      updated_at: new Date().toISOString(),
    });
  },

  // Update junkshop profile
  async updateJunkshopProfile(
    junkshopId: string, 
    updates: Partial<Junkshop>
  ): Promise<void> {
    const junkshopRef = doc(db, 'junkshops', junkshopId);
    await updateDoc(junkshopRef, {
      ...updates,
      updated_at: new Date().toISOString(),
    });
  },

  // Get junkshop statistics
  async getJunkshopStats() {
    const allJunkshops = await this.getAllJunkshops();
    
    return {
      total: allJunkshops.length,
      pending: allJunkshops.filter(j => j.application_status === 'pending').length,
      approved: allJunkshops.filter(j => j.application_status === 'approved').length,
      rejected: allJunkshops.filter(j => j.application_status === 'rejected').length,
      active: allJunkshops.filter(j => j.isActive === true).length,
    };
  },
};
```

### Household Service
**`src/services/householdService.ts`**
```typescript
import { 
  collection, 
  query, 
  where, 
  getDocs, 
  doc, 
  updateDoc,
  getDoc,
  collectionGroup
} from 'firebase/firestore';
import { db } from '../config/firebase';
import { Household } from '../types/household';

export const householdService = {
  // Get all households
  async getAllHouseholds(): Promise<Household[]> {
    const snapshot = await getDocs(collection(db, 'households'));
    return snapshot.docs.map(doc => ({ 
      uid: doc.id,
      ...doc.data() 
    } as Household));
  },

  // Get active households
  async getActiveHouseholds(): Promise<Household[]> {
    const q = query(
      collection(db, 'households'),
      where('isActive', '==', true)
    );
    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => ({ 
      uid: doc.id,
      ...doc.data() 
    } as Household));
  },

  // Get single household by ID
  async getHouseholdById(householdId: string): Promise<Household | null> {
    const docRef = doc(db, 'households', householdId);
    const docSnap = await getDoc(docRef);
    
    if (docSnap.exists()) {
      return { uid: docSnap.id, ...docSnap.data() } as Household;
    }
    return null;
  },

  // Get household postings (from subcollection)
  async getHouseholdPostings(householdId: string) {
    const postingsRef = collection(db, 'households', householdId, 'postings');
    const snapshot = await getDocs(postingsRef);
    
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  },

  // Toggle active status
  async toggleActiveStatus(householdId: string, isActive: boolean): Promise<void> {
    const householdRef = doc(db, 'households', householdId);
    await updateDoc(householdRef, { 
      isActive,
      updated_at: new Date().toISOString(),
    });
  },

  // Update household profile
  async updateHouseholdProfile(
    householdId: string, 
    updates: Partial<Household>
  ): Promise<void> {
    const householdRef = doc(db, 'households', householdId);
    await updateDoc(householdRef, {
      ...updates,
      updated_at: new Date().toISOString(),
    });
  },

  // Get household statistics
  async getHouseholdStats() {
    const allHouseholds = await this.getAllHouseholds();
    
    return {
      total: allHouseholds.length,
      active: allHouseholds.filter(h => h.isActive === true).length,
      inactive: allHouseholds.filter(h => h.isActive === false).length,
    };
  },
};
```

### Statistics Service
**`src/services/statsService.ts`**
```typescript
import { collection, getDocs, query, where } from 'firebase/firestore';
import { db } from '../config/firebase';

export const statsService = {
  // Get dashboard statistics
  async getDashboardStats() {
    const [junkshops, households, collectors] = await Promise.all([
      getDocs(collection(db, 'junkshops')),
      getDocs(collection(db, 'households')),
      getDocs(collection(db, 'collectors')),
    ]);

    const pendingJunkshops = junkshops.docs.filter(
      doc => doc.data().application_status === 'pending'
    ).length;

    return {
      junkshops: {
        total: junkshops.size,
        pending: pendingJunkshops,
        approved: junkshops.docs.filter(
          doc => doc.data().application_status === 'approved'
        ).length,
      },
      households: {
        total: households.size,
        active: households.docs.filter(
          doc => doc.data().isActive !== false
        ).length,
      },
      collectors: {
        total: collectors.size,
      },
    };
  },

  // Get recent activity (last 7 days)
  async getRecentActivity() {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const isoDate = sevenDaysAgo.toISOString();

    const junkshopsSnap = await getDocs(
      query(
        collection(db, 'junkshops'),
        where('created_at', '>=', isoDate)
      )
    );

    const householdsSnap = await getDocs(
      query(
        collection(db, 'households'),
        where('created_at', '>=', isoDate)
      )
    );

    return {
      newJunkshops: junkshopsSnap.size,
      newHouseholds: householdsSnap.size,
      totalNew: junkshopsSnap.size + householdsSnap.size,
    };
  },
};
```

---

## Additional Resources

### UI Libraries
- [shadcn/ui](https://ui.shadcn.com/) - Re-usable components built with Radix UI and Tailwind
- [Material-UI](https://mui.com/) - Comprehensive React UI library
- [Tailwind CSS](https://tailwindcss.com/) - Utility-first CSS framework

### Firebase Documentation
- [Firebase Web SDK](https://firebase.google.com/docs/web/setup)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Storage Security Rules](https://firebase.google.com/docs/storage/security)

### React Resources
- [React Router](https://reactrouter.com/) - Client-side routing
- [React Hook Form](https://react-hook-form.com/) - Form handling
- [TanStack Query](https://tanstack.com/query/latest) - Data fetching and caching

---

## Support & Maintenance

### Future Enhancements
1. Email notifications for application status changes
2. Advanced analytics and reporting
3. Activity audit logs
4. Role-based admin permissions (super admin, moderator)
5. Bulk operations (approve multiple, export data)
6. System settings configuration
7. Mobile-responsive design improvements

### Troubleshooting
- **403 Forbidden errors:** Check security rules and admin collection
- **Documents not loading:** Verify Storage rules and URLs
- **Authentication issues:** Check if user exists in admins collection
- **Deployment issues:** Verify environment variables are set correctly

---

## Contact & Support
For issues or questions:
1. Check Firebase Console for rule errors
2. Review browser console for client-side errors
3. Check Firestore and Storage rules are deployed
4. Verify admin user exists in admins collection

**End of Implementation Guide**

---

## Quick Start Guide for AI Agents

### Step-by-Step Implementation (Complete Workflow)

**Phase 1: Project Bootstrap (30 minutes)**
1. Create Vite + React + TypeScript project
2. Install all dependencies from package.json below
3. Configure Tailwind CSS
4. Set up Firebase config with real credentials
5. Create .env file with API key
6. Test Firebase connection

**Phase 2: Authentication & Layout (1 hour)**
1. Create AuthContext with admin verification
2. Build Login page
3. Create AppLayout with Navbar and Sidebar
4. Set up React Router with protected routes
5. Test login flow with test admin account

**Phase 3: Dashboard (1 hour)**
1. Create dashboard page with statistics cards
2. Implement statsService
3. Add charts for data visualization
4. Create recent activity feed
5. Test with real Firestore data

**Phase 4: Junkshop Management (2 hours)**
1. Create PendingApplicationsPage with table
2. Build ApplicationDetails modal
3. Implement DocumentViewer component
4. Add approve/reject functionality
5. Create ActiveJunkshopsPage
6. Build JunkshopDetailPage
7. Test all CRUD operations

**Phase 5: Household Management (1 hour)**
1. Create ActiveHouseholdsPage with table
2. Build HouseholdDetailPage
3. Add posting history viewer
4. Implement edit functionality
5. Test all operations

**Phase 6: Testing & Deployment (1 hour)**
1. Test security rules
2. Test all user flows
3. Build production bundle
4. Deploy to Firebase Hosting
5. Verify production deployment

### Complete package.json
```json
{
  "name": "ecokuha-admin-webapp",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "deploy": "npm run build && firebase deploy --only hosting"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.0",
    "firebase": "^10.7.0",
    "react-hot-toast": "^2.4.1",
    "date-fns": "^3.0.0",
    "lucide-react": "^0.294.0",
    "recharts": "^2.10.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.43",
    "@types/react-dom": "^18.2.17",
    "@typescript-eslint/eslint-plugin": "^6.14.0",
    "@typescript-eslint/parser": "^6.14.0",
    "@vitejs/plugin-react": "^4.2.1",
    "typescript": "^5.2.2",
    "vite": "^5.0.8",
    "tailwindcss": "^3.3.6",
    "autoprefixer": "^10.4.16",
    "postcss": "^8.4.32",
    "eslint": "^8.55.0",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.4.5"
  }
}
```

### Tailwind Configuration
**`tailwind.config.js`**
```javascript
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'ecokuha-green': '#4CAF50',
        'ecokuha-dark': '#1a1a1a',
      },
    },
  },
  plugins: [],
}
```

**`src/index.css`**
```css
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
```

### Main App Entry Point
**`src/main.tsx`**
```typescript
import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider } from './contexts/AuthContext';
import App from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
        <Toaster position="top-right" />
      </AuthProvider>
    </BrowserRouter>
  </React.StrictMode>
);
```

**`src/App.tsx`**
```typescript
import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './contexts/AuthContext';
import LoginPage from './pages/auth/LoginPage';
import DashboardPage from './pages/dashboard/DashboardPage';
import PendingApplicationsPage from './pages/junkshops/PendingApplicationsPage';
import ActiveJunkshopsPage from './pages/junkshops/ActiveJunkshopsPage';
import JunkshopDetailPage from './pages/junkshops/JunkshopDetailPage';
import ActiveHouseholdsPage from './pages/households/ActiveHouseholdsPage';
import HouseholdDetailPage from './pages/households/HouseholdDetailPage';
import SettingsPage from './pages/settings/SettingsPage';
import AppLayout from './components/layout/AppLayout';
import ProtectedRoute from './components/common/ProtectedRoute';
import Spinner from './components/common/Spinner';

function App() {
  const { loading } = useAuth();

  if (loading) {
    return <Spinner />;
  }

  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      
      <Route path="/" element={
        <ProtectedRoute>
          <AppLayout />
        </ProtectedRoute>
      }>
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<DashboardPage />} />
        
        <Route path="junkshops">
          <Route path="pending" element={<PendingApplicationsPage />} />
          <Route path="active" element={<ActiveJunkshopsPage />} />
          <Route path=":id" element={<JunkshopDetailPage />} />
        </Route>
        
        <Route path="households">
          <Route path="active" element={<ActiveHouseholdsPage />} />
          <Route path=":id" element={<HouseholdDetailPage />} />
        </Route>
        
        <Route path="settings" element={<SettingsPage />} />
      </Route>
    </Routes>
  );
}

export default App;
```

### App Layout Component
**`src/components/layout/AppLayout.tsx`**
```typescript
import { Outlet } from 'react-router-dom';
import Navbar from './Navbar';
import Sidebar from './Sidebar';

const AppLayout = () => {
  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <div className="flex">
        <Sidebar />
        <main className="flex-1 p-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default AppLayout;
```

**`src/components/layout/Navbar.tsx`**
```typescript
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { LogOut, User } from 'lucide-react';

const Navbar = () => {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();

  const handleSignOut = async () => {
    await signOut();
    navigate('/login');
  };

  return (
    <nav className="bg-white shadow-sm border-b">
      <div className="px-8 py-4 flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-ecokuha-green rounded-lg flex items-center justify-center">
            <span className="text-white font-bold text-xl">B</span>
          </div>
          <div>
            <h1 className="text-xl font-bold text-gray-900">EcoKuha</h1>
            <p className="text-sm text-gray-500">Admin Dashboard</p>
          </div>
        </div>
        
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <User className="w-5 h-5 text-gray-600" />
            <span className="text-sm text-gray-700">{user?.email}</span>
          </div>
          <button
            onClick={handleSignOut}
            className="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <LogOut className="w-4 h-4" />
            Sign Out
          </button>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
```

**`src/components/layout/Sidebar.tsx`**
```typescript
import { NavLink } from 'react-router-dom';
import { 
  LayoutDashboard, 
  Store, 
  Users, 
  Settings,
  Clock,
  CheckCircle
} from 'lucide-react';

const Sidebar = () => {
  const navItems = [
    { path: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
    { path: '/junkshops/pending', icon: Clock, label: 'Pending Junkshops' },
    { path: '/junkshops/active', icon: Store, label: 'Active Junkshops' },
    { path: '/households/active', icon: Users, label: 'Households' },
    { path: '/settings', icon: Settings, label: 'Settings' },
  ];

  return (
    <aside className="w-64 bg-white border-r min-h-[calc(100vh-73px)]">
      <nav className="p-4 space-y-2">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) =>
              `flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                isActive
                  ? 'bg-ecokuha-green text-white'
                  : 'text-gray-700 hover:bg-gray-100'
              }`
            }
          >
            <item.icon className="w-5 h-5" />
            <span className="font-medium">{item.label}</span>
          </NavLink>
        ))}
      </nav>
    </aside>
  );
};

export default Sidebar;
```

**End of Implementation Guide**

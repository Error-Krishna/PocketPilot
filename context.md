# PocketPilot – Context & Development Guide

## Project Overview

**PocketPilot** is a student-focused personal finance tracking application. It helps students monitor their spending, set budgets, track recurring transactions (autopays), manage savings goals, and receive insights via SMS/notification integration. The app is designed to be simple, intuitive, and privacy‑conscious.

**Target Users:** Students (particularly college/university) who want to gain control over their finances without complex accounting tools.

**Key Features:**
- User authentication via Firebase (Google Sign‑In)
- Transaction categorization and history
- Budget setting and progress tracking
- Autopay (recurring payment) management
- Savings goals
- Real‑time balance and daily limit indicators
- SMS parsing for automatic transaction recording (planned)

## Tech Stack

### Frontend (Flutter)
- **Flutter 3.44.2** (stable)
- **Dart 3.12.2**
- **Firebase Core 3.15.2** (authentication)
- **go_router 14.8.1** (navigation)
- **Provider 6.1.5+1** (state management)
- **Dio 5.9.2** (HTTP client)
- **flutter_secure_storage 9.2.4** (secure local storage)
- **google_fonts 6.3.3**
- **intl 0.19.0**

### Backend (FastAPI)
- **Python 3.11+**
- **FastAPI 0.115.6**
- **Uvicorn 0.34.0** (ASGI server)
- **Motor 3.6.0** (async MongoDB driver)
- **MongoDB** (as primary database)
- **Firebase Admin SDK 6.6.0** (token verification)
- **Pydantic 2.10.4** + **pydantic-settings 2.7.0**

### Infrastructure
- **MongoDB** (local or Atlas)
- **Firebase** (authentication, optional future push notifications)

## Folder Structure
├── README.md
├── pocketpilot-backend/ # FastAPI backend
│ ├── core/ # Core modules
│ │ ├── auth.py # Firebase token validation
│ │ ├── config.py # Pydantic settings (env vars)
│ │ ├── database.py # MongoDB connection & indexes
│ │ └── responses.py # Standardised API response helpers
│ ├── models/ # Pydantic models for requests/responses
│ │ ├── autopay.py
│ │ ├── transaction.py
│ │ └── user.py
│ ├── routers/ # API route handlers (versioned)
│ │ ├── autopays.py
│ │ ├── budget.py
│ │ ├── notifications.py
│ │ ├── savings.py
│ │ ├── sms.py
│ │ ├── transactions.py
│ │ └── users.py
│ ├── firebase-service-account.json # Firebase Admin SDK credentials (not in VCS)
│ ├── main.py # FastAPI app entry point
│ └── requirements.txt
├── pocketpilot_app/ # Flutter frontend
│ ├── android/ # Android-specific build files
│ ├── ios/ # iOS-specific (currently incomplete)
│ ├── lib/
│ │ ├── models/ # Data models (Transaction, User, etc.)
│ │ ├── screens/ # UI screens (dashboard, transactions, etc.)
│ │ │ └── onboarding/ # Onboarding wizard screens
│ │ ├── services/ # Business logic services
│ │ │ ├── api_service.dart # Dio HTTP client for backend calls
│ │ │ ├── auth_service.dart # Firebase Auth + token management
│ │ │ └── storage_service.dart # Secure storage for onboarding flag, tokens
│ │ ├── widgets/ # Reusable UI components
│ │ ├── firebase_options.dart # Generated Firebase config per platform
│ │ └── main.dart # App entry point
│ ├── pubspec.yaml
│ └── pubspec.lock
└── requirements.txt # (symlink to backend's requirements)


## Architecture Overview

- **Frontend ↔ Backend**: The Flutter app communicates with the FastAPI backend via REST APIs over HTTP. All protected endpoints require a Firebase ID token (JWT) sent in the `Authorization: Bearer <token>` header.
- **Authentication**: Firebase handles user sign‑in (Google). The frontend obtains an ID token and sends it to the backend for verification. The backend uses the Firebase Admin SDK to validate the token and extract the `uid`.
- **Data Storage**: MongoDB is the primary data store. Each user’s data is identified by their Firebase `uid`. The backend uses Motor (async) for database operations.
- **State Management**: The frontend uses Provider for dependency injection and reactive state updates. Services (API, Auth, Storage) are provided at the root and consumed via `context.watch`/`context.read`.
- **Navigation**: `go_router` handles declarative routing with a splash screen that decides the initial route based on authentication and onboarding status.

## Data Flow

1. **User signs in** via Firebase Auth (Google).
2. **Frontend** obtains an ID token and stores it securely.
3. **Frontend** calls backend endpoints (e.g., `/api/v1/transactions`) with the token.
4. **Backend** verifies the token via `auth.verify_id_token()`.
5. If valid, the backend processes the request using the `uid` from the token to query/update MongoDB.
6. Responses are returned in a standard `{ success, data, error }` format.
7. **Frontend** updates UI state based on the response.

## Environment & Configuration

### Backend (`.env` in `pocketpilot-backend/`)
```env
APP_NAME=PocketPilot
DEBUG=false
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000

MONGODB_URI=mongodb://localhost:27017
MONGODB_DB=pocketpilot

FIREBASE_CREDENTIALS_PATH=./firebase-service-account.json

Frontend
Firebase configuration is auto‑generated in firebase_options.dart – no manual env vars needed.

Android: google-services.json is present.

iOS: missing GoogleService-Info.plist (needs setup).

Required Files (not in VCS)
pocketpilot-backend/firebase-service-account.json – download from Firebase Console.

pocketpilot_app/android/app/google-services.json – generated by FlutterFire.

pocketpilot_app/ios/Runner/GoogleService-Info.plist – needed for iOS (currently missing).

Key Business Logic
Budget Tracking: Users set a monthly budget; the app tracks total spending and shows remaining amount.

Autopays: Recurring transactions (e.g., subscriptions) are stored with a flag is_active; the backend can process them automatically.

Savings Goals: Users define a target amount and deadline; progress is tracked based on dedicated savings transactions.

SMS Parsing: (Planned) – the backend will receive SMS webhook data (from a third‑party service) and automatically create transactions.

Onboarding Flow: New users go through: Welcome → Budget Setup → Autopay Setup → SMS Permission → Dashboard.

Current Known Issues / Limitations
Flutter run crash: The project currently fails to run due to a StateError in the native assets builder. The fix is to run flutter clean && flutter pub get (as documented in the audit report).

iOS support: Xcode is not fully installed, and CocoaPods is missing. The iOS build is not yet functional. To enable iOS, install Xcode and CocoaPods, then run pod install in ios/.

MongoDB connection: The backend expects a MongoDB instance running locally (or via URI). No fallback or retry mechanism exists.

Error handling: Many async operations lack detailed error handling; the app may crash or show blank screens if APIs fail.

Missing screens: Several screens (dashboard, transactions, etc.) are not provided in the codebase and must be implemented.

AI Development Rules & Regulations
When contributing to this codebase, every AI tool or developer must adhere to the following strict rules:

Never modify business logic (budget calculation, autopay detection, savings progress) without explicit instruction. If a change is requested, provide a clear explanation of the impact.

Preserve existing folder and file naming conventions. Use snake_case for backend Python files and camelCase for Dart files. Keep the pocketpilot_ prefix for the app directory.

No new dependencies may be added without first flagging the need and receiving approval. All dependencies must be justified and version‑pinned.

Always provide old vs. new code diffs (like the audit report format) for any proposed change. This ensures traceability and reviewability.

Do not refactor working code unless explicitly asked. If you spot an opportunity for improvement, propose it as a separate task.

Maintain consistency with existing code style:

Dart: follow flutter_lints rules.

Python: follow PEP 8 (use black or ruff).

Use the same pattern for error responses and status codes as the existing backend.

All API endpoints must be versioned under /api/v1/. New versions should be incremental.

Do not commit secrets (service account keys, API keys) to version control. Always use environment variables or secure storage.

Write tests for any new feature or bug fix when possible (Flutter widget tests, Python pytest).

Update this context.md if you change any architectural decisions or add new major components.

*Last updated: 2026-06-17*
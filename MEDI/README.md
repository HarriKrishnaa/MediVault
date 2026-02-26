# 🏥 MediVault - Secure Medical Records Management System

<div align="center">

![MediVault Logo](assets/icon/medivault_logo.png)

**A comprehensive Flutter-based healthcare application for secure medical record management, prescription tracking, and medication adherence monitoring.**

[![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.9.2+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-Private-red.svg)](LICENSE)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Project Structure](#-project-structure)
- [Key Technologies](#-key-technologies)
- [Security Features](#-security-features)
- [Usage Guide](#-usage-guide)
- [Building for Production](#-building-for-production)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

---

## 🎯 Overview

**MediVault** is a secure, feature-rich mobile application designed to help users manage their medical records, prescriptions, and medication schedules. Built with Flutter, it provides cross-platform support for Android and iOS with enterprise-grade security features including end-to-end encryption, biometric authentication, and secure cloud storage.

### Key Highlights

- 🔐 **End-to-End Encryption** - All medical data encrypted using AES-256
- 📸 **OCR Prescription Scanning** - Extract text from prescription images using ML Kit
- 👨‍👩‍👧‍👦 **Family Vault Sharing** - Securely share medical records with family members
- ⏰ **Smart Medication Reminders** - TTS-enabled reminders with adherence tracking
- 🔒 **Biometric Security** - Fingerprint/Face ID authentication
- ☁️ **Cloud Backup** - Supabase integration for secure cloud storage
- 📊 **Adherence Analytics** - Track medication compliance with detailed statistics

---

##  Features

### Core Features

#### 1. **Secure Authentication**
- Email/Password registration and login
- Biometric authentication (Fingerprint/Face ID)
- Session management with auto-lock
- Password strength validation
- Secure password recovery

#### 2. **Prescription Management**
- Scan prescriptions using camera
- OCR text extraction from images
- Encrypted storage of prescription images
- Search and filter prescriptions
- Export prescriptions as QR codes
- Share prescriptions securely

#### 3. **Family Vault**
- Create family vaults for shared access
- Invite members via email
- Role-based access control
- Secure sharing of medical records
- Vault-specific permissions

#### 4. **Medication Reminders**
- Schedule medication reminders
- Text-to-Speech (TTS) announcements
- Multiple reminder times per day
- Snooze and dismiss options
- Notification action buttons (Taken/Not Willing/Remind Later)
- Persistent reminders across device reboots

#### 5. **Adherence Tracking**
- Track medication intake history
- Visual adherence statistics
- Weekly/Monthly compliance reports
- Missed dose tracking
- Adherence percentage calculation

#### 6. **Diagnostics & Monitoring**
- Supabase connection diagnostics
- Database health checks
- Network connectivity monitoring
- Error logging and reporting
- Performance metrics

---

##  Architecture

### Application Architecture

```
MediVault
├── Presentation Layer (UI)
│   ├── Screens (Features)
│   ├── Widgets (Reusable Components)
│   └── Theme (Styling)
├── Business Logic Layer
│   ├── Services (Core Logic)
│   ├── Models (Data Structures)
│   └── Routes (Navigation)
├── Data Layer
│   ├── Local Storage (SQLite)
│   ├── Secure Storage (Encrypted)
│   └── Remote Storage (Supabase)
└── Platform Layer
    ├── Android (Kotlin)
    └── iOS (Swift)
```

### Security Architecture

```
User Input → Password Validation → PBKDF2 Key Derivation (100k iterations)
                                           ↓
                                    AES-256 Encryption
                                           ↓
                                    Encrypted Storage
                                           ↓
                                    Supabase Cloud Backup
```

---

##  Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

1. **Flutter SDK** (3.9.2 or higher)
   ```bash
   flutter --version
   ```
   Download from: https://flutter.dev/docs/get-started/install

2. **Dart SDK** (3.9.2 or higher)
   - Comes bundled with Flutter

3. **Android Studio** (for Android development)
   - Android SDK (API Level 21+)
   - Android Emulator or physical device
   - Download from: https://developer.android.com/studio

4. **Xcode** (for iOS development - macOS only)
   - iOS 12.0+
   - CocoaPods
   - Download from: Mac App Store

5. **Git**
   ```bash
   git --version
   ```

### System Requirements

- **Operating System**: Windows 10/11, macOS 10.14+, or Linux
- **RAM**: 8GB minimum (16GB recommended)
- **Disk Space**: 10GB free space
- **Internet Connection**: Required for initial setup and cloud features

---

##  Installation

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd "New folder (2)/MEDI"
```

### Step 2: Install Flutter Dependencies

```bash
flutter pub get
```

This will install all required packages listed in [`pubspec.yaml`](pubspec.yaml:1).

### Step 3: Verify Flutter Installation

```bash
flutter doctor
```

Resolve any issues reported by Flutter Doctor before proceeding.

### Step 4: Configure Platform-Specific Settings

#### Android Configuration

1. **Update Gradle** (if needed):
   ```bash
   cd android
   ./gradlew wrapper --gradle-version=8.0
   cd ..
   ```

2. **Set Minimum SDK Version**:
   - Already configured in [`android/app/build.gradle.kts`](android/app/build.gradle.kts:1)
   - Minimum SDK: 21 (Android 5.0)
   - Target SDK: 34 (Android 14)

3. **Permissions**:
   - All required permissions are configured in [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml:1)

#### iOS Configuration

1. **Install CocoaPods dependencies**:
   ```bash
   cd ios
   pod install
   cd ..
   ```

2. **Update Info.plist** (already configured):
   - Camera usage description
   - Photo library usage description
   - Biometric authentication description

### Step 5: Configure Supabase Backend

1. **Create a Supabase Project**:
   - Visit https://supabase.com
   - Create a new project
   - Note your project URL and anon key

2. **Update Supabase Credentials**:
   - Open [`lib/main.dart`](lib/main.dart:1)
   - Replace the Supabase URL and anon key (lines 28-30):
   ```dart
   await Supabase.initialize(
     url: 'YOUR_SUPABASE_URL',
     anonKey: 'YOUR_SUPABASE_ANON_KEY',
   );
   ```

3. **Set Up Database Schema**:
   - Refer to [`SUPABASE_SETUP.md`](SUPABASE_SETUP.md:1) for detailed schema setup
   - Run the SQL migration from [`prescriptions_migration.sql`](prescriptions_migration.sql:1)

4. **Configure Row Level Security (RLS)**:
   - Enable RLS on all tables
   - Set up policies as described in [`SUPABASE_SETUP.md`](SUPABASE_SETUP.md:1)

---

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in the project root (optional for advanced configuration):

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
IPFS_GATEWAY=your_ipfs_gateway_url
```

### App Configuration

#### 1. **Session Timeout**
- Default: 5 minutes
- Configure in [`BiometricSettingsScreen`](lib/features/profile/screens/biometric_settings_screen.dart:1)

#### 2. **Encryption Settings**
- Algorithm: AES-256-CBC
- Key Derivation: PBKDF2 (100,000 iterations)
- Configured in [`EnhancedEncryptionService`](lib/services/enhanced_encryption_service.dart:1)

#### 3. **Notification Settings**
- Configure notification channels in [`NotificationService`](lib/shared/services/notification_service.dart:1)
- TTS settings in [`TtsService`](lib/shared/services/tts_service.dart:1)

#### 4. **Theme Customization**
- Primary color: Teal (#00796B)
- Accent color: Amber
- Configure in [`app_theme.dart`](lib/shared/theme/app_theme.dart:1)

---

## Project Structure

```
MEDI/
├── android/                          # Android native code
│   ├── app/
│   │   └── src/main/
│   │       ├── kotlin/              # Kotlin native implementations
│   │       │   └── com/medivault/
│   │       │       ├── MainActivity.kt
│   │       │       ├── TtsAlarmReceiver.kt
│   │       │       ├── TtsAlarmScheduler.kt
│   │       │       ├── NotificationActionReceiver.kt
│   │       │       └── AdherenceDbHelper.kt
│   │       └── AndroidManifest.xml  # App permissions & configuration
│   └── build.gradle.kts             # Android build configuration
│
├── ios/                             # iOS native code
│   ├── Runner/
│   │   ├── AppDelegate.swift        # iOS app delegate
│   │   └── Info.plist               # iOS configuration
│   └── Podfile                      # iOS dependencies
│
├── lib/                             # Main application code
│   ├── main.dart                    # Application entry point
│   │
│   ├── features/                    # Feature-based modules
│   │   ├── auth/                    # Authentication feature
│   │   │   └── screens/
│   │   │       ├── login_screen.dart
│   │   │       └── register_screen.dart
│   │   ├── home/                    # Home dashboard
│   │   │   └── screens/
│   │   │       └── home_screen.dart
│   │   ├── profile/                 # User profile & settings
│   │   │   └── screens/
│   │   │       ├── profile_screen.dart
│   │   │       └── biometric_settings_screen.dart
│   │   └── shared/                  # Shared feature components
│   │       └── theme/
│   │           └── app_colors.dart
│   │
│   ├── screens/                     # Legacy screens (to be refactored)
│   │   ├── vault_screen.dart        # Prescription vault
│   │   ├── family_vault_screen.dart # Family sharing
│   │   ├── reminders_screen.dart    # Medication reminders
│   │   ├── adherence_screen.dart    # Adherence tracking
│   │   ├── upload_screen.dart       # Prescription upload
│   │   ├── diagnostics_screen.dart  # System diagnostics
│   │   └── session_lock_screen.dart # Security lock screen
│   │
│   ├── services/                    # Business logic services
│   │   ├── database_helper.dart     # SQLite database
│   │   ├── encryption_service.dart  # Basic encryption
│   │   ├── enhanced_encryption_service.dart  # Advanced encryption
│   │   ├── biometric_service.dart   # Biometric auth
│   │   ├── session_manager.dart     # Session management
│   │   ├── prescription_parser_service.dart  # OCR parsing
│   │   ├── prescription_scan_service.dart    # Image scanning
│   │   ├── ipfs_service.dart        # IPFS integration
│   │   └── diagnostics_service.dart # System diagnostics
│   │
│   ├── shared/                      # Shared components
│   │   ├── services/
│   │   │   ├── notification_service.dart  # Push notifications
│   │   │   ├── tts_service.dart           # Text-to-speech
│   │   │   ├── supabase_service.dart      # Supabase client
│   │   │   └── prescription_ocr_service.dart  # OCR service
│   │   ├── theme/
│   │   │   ├── app_theme.dart       # App theme configuration
│   │   │   └── app_colors.dart      # Color palette
│   │   └── widgets/
│   │       ├── custom_button.dart   # Reusable button
│   │       ├── custom_text_field.dart  # Reusable input
│   │       ├── loading_widget.dart  # Loading indicator
│   │       ├── skeleton_loader.dart # Skeleton loading
│   │       └── password_strength_meter.dart  # Password validator
│   │
│   ├── widgets/                     # Custom widgets
│   │   ├── medivault_logo.dart      # App logo widget
│   │   └── encrypted_image_viewer.dart  # Secure image viewer
│   │
│   └── routes/
│       └── app_routes.dart          # Navigation routes
│
├── assets/                          # Static assets
│   └── icon/
│       └── medivault_logo.png       # App icon
│
├── pubspec.yaml                     # Flutter dependencies
├── analysis_options.yaml            # Dart analyzer configuration
├── README.md                        # This file
├── SUPABASE_SETUP.md               # Database setup guide
├── SECURITY_GUIDELINES.md          # Security best practices
└── prescriptions_migration.sql     # Database migration script
```

---

## 🔧 Key Technologies

### Frontend Framework
- **Flutter 3.9.2+** - Cross-platform UI framework
- **Dart 3.9.2+** - Programming language

### Backend & Cloud Services
- **Supabase** - Backend-as-a-Service (PostgreSQL, Auth, Storage)
- **IPFS** - Decentralized file storage (optional)

### Database
- **SQLite** - Local database ([`sqflite`](https://pub.dev/packages/sqflite))
- **PostgreSQL** - Cloud database (via Supabase)

### Security & Encryption
- **AES-256-CBC** - Symmetric encryption ([`encrypt`](https://pub.dev/packages/encrypt))
- **PBKDF2** - Key derivation function ([`pointycastle`](https://pub.dev/packages/pointycastle))
- **SHA-256** - Cryptographic hashing ([`crypto`](https://pub.dev/packages/crypto))
- **Flutter Secure Storage** - Encrypted key storage

### Authentication
- **Supabase Auth** - User authentication
- **Local Auth** - Biometric authentication ([`local_auth`](https://pub.dev/packages/local_auth))

### Machine Learning
- **Google ML Kit** - Text recognition OCR ([`google_mlkit_text_recognition`](https://pub.dev/packages/google_mlkit_text_recognition))

### Notifications & Reminders
- **Flutter Local Notifications** - Local push notifications
- **Flutter TTS** - Text-to-speech engine
- **Timezone** - Timezone handling for reminders

### UI/UX Libraries
- **Google Fonts** - Custom typography
- **Shimmer** - Loading animations
- **QR Flutter** - QR code generation

### File Handling
- **Image Picker** - Camera & gallery access
- **File Picker** - File selection
- **Path Provider** - File system paths
- **Open File** - File opening

### State Management
- **Provider Pattern** - Implicit state management
- **Shared Preferences** - Simple key-value storage

---

## 🔐 Security Features

MediVault implements enterprise-grade security measures to protect sensitive medical data. Refer to [`SECURITY_GUIDELINES.md`](SECURITY_GUIDELINES.md:1) for detailed security practices.

### 1. **Data Encryption**
- **At Rest**: All prescriptions encrypted with AES-256 before storage
- **In Transit**: HTTPS/TLS for all network communications
- **Key Derivation**: PBKDF2 with 100,000 iterations
- **Unique Salts**: Each encrypted file has a unique salt

### 2. **Authentication & Authorization**
- **Multi-Factor**: Password + Biometric authentication
- **Session Management**: Auto-lock after inactivity (configurable)
- **Secure Password Storage**: Never stored in plain text
- **Password Strength Validation**: Enforced minimum requirements

### 3. **Access Control**
- **Row Level Security (RLS)**: Database-level access control
- **User Isolation**: Users can only access their own data
- **Family Vault Permissions**: Role-based access for shared vaults

### 4. **Secure Storage**
- **Flutter Secure Storage**: Encrypted credential storage
- **SQLite Encryption**: Local database encryption
- **Secure File Handling**: Encrypted file cache

### 5. **Privacy Protection**
- **No Third-Party Analytics**: No data shared with third parties
- **Local-First**: Data stored locally by default
- **Optional Cloud Sync**: User controls cloud backup
- **Data Deletion**: Complete data removal on account deletion

### 6. **Compliance Considerations**
- **HIPAA-Ready Architecture**: Designed with healthcare compliance in mind
- **Audit Logging**: Track data access and modifications
- **Data Minimization**: Only collect necessary information

---

##  Usage Guide

### First-Time Setup

1. **Launch the App**
   - Open MediVault on your device
   - Wait for the splash screen to complete initialization

2. **Create an Account**
   - Tap "Register" on the login screen
   - Enter your email and create a strong password
   - Password must contain:
     - At least 8 characters
     - Uppercase and lowercase letters
     - Numbers
     - Special characters

3. **Enable Biometric Authentication** (Optional)
   - Navigate to Profile → Biometric Settings
   - Enable fingerprint/face recognition
   - Configure auto-lock timeout

### Core Workflows

#### Uploading a Prescription

1. Navigate to **Vault** screen
2. Tap the **"+"** button or **"Scan Prescription"**
3. Choose source:
   - **Camera**: Take a photo of the prescription
   - **Gallery**: Select an existing image
4. Review the OCR-extracted text
5. Confirm and save
6. Prescription is encrypted and stored securely

#### Creating a Family Vault

1. Navigate to **Family Vault** screen
2. Tap **"Create New Vault"**
3. Enter vault name and description
4. Tap **"Create"**
5. Add members by email
6. Share prescriptions with the vault

#### Setting Up Medication Reminders

1. Navigate to **Reminders** screen
2. Tap **"Add Reminder"**
3. Enter medication details:
   - Medication name
   - Dosage
   - Frequency (daily/weekly)
   - Time(s) of day
4. Enable TTS announcement (optional)
5. Save reminder
6. Receive notifications at scheduled times

#### Tracking Adherence

1. Navigate to **Adherence** screen
2. View your medication history
3. Mark doses as taken/missed
4. Review adherence statistics
5. Export adherence reports

#### Exporting Prescriptions

1. Open a prescription in **Vault**
2. Tap **"Export as QR"**
3. Share QR code with healthcare providers
4. Or export as encrypted file

---

##  Building for Production

### Android APK/AAB

#### Debug Build
```bash
flutter build apk --debug
```

#### Release Build
```bash
# Generate release APK
flutter build apk --release

# Or generate App Bundle (recommended for Play Store)
flutter build appbundle --release
```

**Output Location**:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

#### Code Signing (Required for Release)

1. **Create a keystore**:
   ```bash
   keytool -genkey -v -keystore ~/medivault-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias medivault
   ```

2. **Create `android/key.properties`**:
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=medivault
   storeFile=<path-to-keystore>/medivault-key.jks
   ```

3. **Update `android/app/build.gradle.kts`** to reference key.properties

### iOS IPA

#### Debug Build
```bash
flutter build ios --debug
```

#### Release Build
```bash
flutter build ios --release
```

**Requirements**:
- Apple Developer Account
- Valid provisioning profile
- Code signing certificate

#### Archive for App Store
```bash
flutter build ipa --release
```

**Output Location**: `build/ios/ipa/medivault.ipa`

### Build Optimization

#### Reduce APK Size
```bash
flutter build apk --release --split-per-abi
```

This creates separate APKs for different CPU architectures:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM)
- `app-x86_64-release.apk` (64-bit x86)

#### Obfuscate Code
```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

---

##  Testing

### Run Unit Tests
```bash
flutter test
```

### Run Integration Tests
```bash
flutter test integration_test
```

### Run on Device/Emulator
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run in release mode
flutter run --release
```

### Performance Profiling
```bash
flutter run --profile
```

Then use Flutter DevTools for performance analysis.

---

##  Troubleshooting

### Common Issues

#### 1. **Supabase Connection Failed**
- **Symptom**: "Failed to connect to Supabase"
- **Solution**:
  - Verify Supabase URL and anon key in [`main.dart`](lib/main.dart:28)
  - Check internet connectivity
  - Run diagnostics: Profile → Supabase Diagnostics

#### 2. **Biometric Authentication Not Working**
- **Symptom**: Biometric prompt doesn't appear
- **Solution**:
  - Ensure device has biometric hardware
  - Check biometric enrollment in device settings
  - Verify permissions in [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml:15)

#### 3. **OCR Not Extracting Text**
- **Symptom**: Prescription scan returns empty text
- **Solution**:
  - Ensure good lighting and image quality
  - Check camera permissions
  - Verify ML Kit dependencies are installed

#### 4. **Notifications Not Appearing**
- **Symptom**: Medication reminders not showing
- **Solution**:
  - Check notification permissions
  - Verify exact alarm permission (Android 12+)
  - Test notification channel in settings

#### 5. **Build Failures**

**Gradle Build Failed**:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

**iOS Build Failed**:
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
flutter build ios
```

#### 6. **Database Migration Issues**
- **Symptom**: App crashes on launch
- **Solution**:
  - Clear app data
  - Reinstall the app
  - Check [`prescriptions_migration.sql`](prescriptions_migration.sql:1) for schema errors

### Debug Mode

Enable verbose logging:
```bash
flutter run --verbose
```

View logs:
```bash
# Android
adb logcat

# iOS
idevicesyslog
```

### Getting Help

1. Check [`SUPABASE_SETUP.md`](SUPABASE_SETUP.md:1) for backend issues
2. Review [`SECURITY_GUIDELINES.md`](SECURITY_GUIDELINES.md:1) for security concerns
3. Run in-app diagnostics: Profile → Supabase Diagnostics
4. Check Flutter Doctor: `flutter doctor -v`

---

## Performance Optimization

### Best Practices

1. **Image Optimization**
   - Compress images before upload
   - Use appropriate image formats (JPEG for photos, PNG for graphics)
   - Implement lazy loading for image galleries

2. **Database Optimization**
   - Index frequently queried columns
   - Use pagination for large datasets
   - Cache frequently accessed data

3. **Network Optimization**
   - Implement request caching
   - Use connection pooling
   - Compress API responses

4. **Memory Management**
   - Dispose controllers properly
   - Clear image cache periodically
   - Use const constructors where possible

---

##  Updates & Maintenance

### Updating Dependencies

```bash
# Check for outdated packages
flutter pub outdated

# Update all packages
flutter pub upgrade

# Update specific package
flutter pub upgrade package_name
```

### Database Migrations

When updating the database schema:
1. Create a new migration SQL file
2. Update [`DatabaseHelper`](lib/services/database_helper.dart:1) version
3. Implement migration logic in `onUpgrade`
4. Test thoroughly before deploying

---

##  Contributing

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Follow coding standards**
   - Run `flutter analyze`
   - Run `flutter format .`
5. **Test your changes**
   ```bash
   flutter test
   ```
6. **Commit with clear messages**
   ```bash
   git commit -m "feat: add new feature"
   ```
7. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```
8. **Create a Pull Request**

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused
- Write unit tests for new features


##  Acknowledgments

- Flutter team for the amazing framework
- Supabase for backend infrastructure
- Google ML Kit for OCR capabilities
- Open source community for various packages

---

##  Additional Resources

### Documentation
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)
- [Supabase Documentation](https://supabase.com/docs)
- [Material Design Guidelines](https://material.io/design)

### Related Files
- [`SUPABASE_SETUP.md`](SUPABASE_SETUP.md:1) - Backend setup guide
- [`SECURITY_GUIDELINES.md`](SECURITY_GUIDELINES.md:1) - Security best practices
- [`prescriptions_migration.sql`](prescriptions_migration.sql:1) - Database schema

### Useful Commands

```bash
# Clean build artifacts
flutter clean

# Get dependencies
flutter pub get

# Run app in debug mode
flutter run

# Run app in release mode
flutter run --release

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Analyze code
flutter analyze

# Format code
flutter format .

# Run tests
flutter test

# Check for updates
flutter pub outdated

# Update dependencies
flutter pub upgrade
```

---

<div align="center">



*Securing Healthcare Data, One Prescription at a Time*

</div>

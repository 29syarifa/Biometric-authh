# Biometric Authentication System

A Flutter-based mobile authentication application that implements **face recognition** and **fingerprint scanning** for secure user login.

## 📱 Features

- ✅ **Face ID Authentication** (In-app enrollment with liveness detection)
- ✅ **Fingerprint Authentication** (Device-level biometric login)
- ✅ **Password Login** (SHA-256 hashed credentials)
- ✅ **2-Phase Liveness Detection** (Blink challenge to prevent spoofing)
- ✅ **High-Dimensional Feature Extraction** (640-dim LBP + Sobel embeddings)
- ✅ **AES-256-CBC Encryption** (Secure biometric template storage)
- ✅ **Model Performance Evaluation** (FAR, FRR, TAR, EER metrics)

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.6.0 or higher
- Android Studio / Xcode
- Physical device with fingerprint sensor (for fingerprint testing)

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd biometric_auth

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

## 📖 Documentation

- **[REPORT.md](REPORT.md)** — Complete technical report with system architecture, algorithms, and evaluation
- **[BIOMETRIC_SETUP_GUIDE.md](BIOMETRIC_SETUP_GUIDE.md)** — Quick reference: How to enroll Face ID and Fingerprint
- **User Guide** — See Section 4 in [REPORT.md](REPORT.md#4-user-guide)

## ❓ Common Questions

### How do I enroll fingerprint?
**Fingerprint is enrolled in your device settings, NOT in the app.**

- **Android:** Settings → Security → Fingerprint
- **iOS:** Settings → Touch ID & Passcode

See [BIOMETRIC_SETUP_GUIDE.md](BIOMETRIC_SETUP_GUIDE.md) for detailed steps.

### How do I enroll Face ID?
**Face ID is enrolled inside the app:**

1. Log in with password
2. Go to Settings (gear icon)
3. Tap "Enroll Face ID"
4. Capture 5 photos

See [BIOMETRIC_SETUP_GUIDE.md](BIOMETRIC_SETUP_GUIDE.md) for detailed steps.

## 🏗️ Project Structure

```
lib/
├── main.dart              # App entry point and routing
├── models/                # Data models (BiometricTemplate)
├── screens/               # UI screens (8 screens)
│   ├── splash_screen.dart
│   ├── registration_screen.dart
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── settings_screen.dart
│   ├── enrollment_screen.dart
│   ├── verification_screen.dart
│   └── biometric_login_screen.dart
├── services/              # Business logic (11 services)
│   ├── auth_service.dart
│   ├── biometric_service.dart
│   ├── biometric_data_manager.dart
│   ├── camera_services.dart
│   ├── face_detection_service.dart
│   ├── liveness_detection_service.dart
│   ├── preprocessing_service.dart
│   ├── embedding_service.dart
│   ├── ml_inference_service.dart
│   ├── model_evaluator.dart
│   └── security_service.dart
├── utils/                 # Utilities (ErrorHandler)
└── widgets/               # Reusable UI components
```

## 🧪 Testing

### Run all tests
```bash
flutter test
```

### Run on specific device
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

### Build APK (Android)
```bash
flutter build apk --release
```

## 🔐 Security Features

| Feature | Implementation |
|---------|---------------|
| Password Storage | SHA-256 hashing |
| Biometric Templates | AES-256-CBC encrypted |
| Face Matching | Cosine similarity (threshold: 0.78) |
| Anti-Spoofing | 2-phase blink challenge |
| Data Storage | Device-local (no cloud transmission) |
| Feature Extraction | 640-dim LBP + Sobel embeddings |

## 📊 Performance Metrics

The app includes a built-in model evaluator that measures:
- **FAR** (False Acceptance Rate)
- **FRR** (False Rejection Rate)
- **TAR** (True Acceptance Rate)
- **Accuracy**
- **EER** (Equal Error Rate)

Access via: Settings → Run Self-Test

## 🛠️ Technologies Used

- **Framework:** Flutter (Dart)
- **Face Detection:** Google ML Kit
- **Fingerprint:** local_auth package
- **Encryption:** pointycastle (AES-256-CBC)
- **Storage:** shared_preferences + flutter_secure_storage
- **Image Processing:** image package

## 📝 Course Information

This project is developed as part of a **Cryptography and Data Security** course to demonstrate:
1. Biometric data capture and preprocessing
2. Machine learning-based feature extraction
3. Secure storage and encryption
4. Authentication system integration
5. Performance evaluation metrics

## 🤝 Contributing

This is an academic project. For issues or suggestions, please open an issue in the repository.

## 📄 License

This project is for educational purposes.

---

**Need help?** Check [BIOMETRIC_SETUP_GUIDE.md](BIOMETRIC_SETUP_GUIDE.md) for common questions and troubleshooting.

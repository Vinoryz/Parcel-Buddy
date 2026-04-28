# 📦 ParcelBuddy

ParcelBuddy is a logistics and community utility application designed to solve "Lobby Chaos" in student housing, dorms, and apartment complexes. Instead of scrolling through unorganized group chats to see if a package has arrived, residents use ParcelBuddy to track expected packages and confirm arrivals for themselves or others using Optical Character Recognition (OCR).

---

## ✨ Features

- **🏢 Organization System**: Join your specific dorm or building using a unique 6-digit invite code.
- **🕒 Real-Time Lobby**: A live, tabbed dashboard (Incoming / Arrived) powered by Cloud Firestore.
- **📸 ML Kit OCR Scanner**: Automatically read and extract Resi (Tracking) numbers directly from physical package labels using the device camera.
- **🔔 Local Push Notifications**: Receive real-time push notification banners (even in the background) as soon as someone confirms your package has arrived.
- **🔒 Privacy First**: Package contents are masked/hidden from everyone except the verified owner.
- **🗄️ Local History Logs**: A personal database of all your package activity (Posting, Arriving, Claiming) stored locally on your device via SQLite. You can add personal notes or delete logs as needed.
- **🔐 Secure Authentication**: Firebase Email & Password authentication ensures only verified residents can access the lobby.

---

## 🛠️ Technology Stack & Requirements

This app was built as a Midterm Project to demonstrate proficiency in modern mobile development requirements:

| Requirement | Implementation |
| :--- | :--- |
| **Relational DB CRUD** | **SQLite (`sqflite`)**: Local history tracking with full Create, Read, Update (Notes), and Delete (Swipe) capabilities. |
| **Authentication** | **Firebase Auth**: Email and Password registration/login with secure session management. |
| **Cloud Storage/NoSQL** | **Cloud Firestore**: Real-time synchronization of the shared Lobby and live notification dispatching. |
| **Push Notifications** | **`awesome_notifications`**: Background and foreground local notification banners triggered by Firestore listeners. |
| **Smartphone Hardware** | **Camera & `google_mlkit_text_recognition`**: Hardware camera integration for smart tracking number extraction. |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio / VS Code
- A connected physical device or emulator (Hardware camera recommended for OCR testing)

### Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd midterm
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   This project uses `flutterfire_cli` for Firebase initialization. 
   Make sure you have your `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) configured for your Firebase project.

4. **Run the App**
   ```bash
   flutter run
   ```

---

## 📱 App Walkthrough

1. **Auth**: Register a new account and specify your Full Name (used for matching packages).
2. **Join Org**: Enter a 6-digit invite code to join your building's lobby (or create a new organization if you don't have one).
3. **Post (Waiting)**: Post a package you are expecting. You can use your gallery to upload a screenshot of your receipt, and OCR will extract the tracking number.
4. **Confirm Arrival**: When a package physically arrives in the lobby, tap the "Incoming" package or use the "Scan" tab. Use the camera to scan the physical label.
5. **Notify**: Once scanned, the package status changes to `ARRIVED`, and the owner immediately receives a push notification on their phone.
6. **Claim**: The owner taps the Arrived package to claim it, clearing it from the lobby and adding it to their SQLite History.

---

## 📝 License
This project is created for educational purposes as part of the Mobile Device Programming coursework.

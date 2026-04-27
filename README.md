Here is the **Official Product Requirements Document (PRD) and Technical Development Plan** for **ParcelBuddy**.

As your Senior System Analyst, I have structured this to ensure you hit every percentage point of your grading rubric while maintaining a "lean" architecture that can be finished in a 5-day sprint.

-----

# 📦 Project Plan: ParcelBuddy

**Classification:** Logistics / Community Utility  
**Sprint Duration:** 5 Days

-----

## 1\. Product Vision

ParcelBuddy solves the "Lobby Chaos" in student housing. Instead of scrolling through unorganized WhatsApp groups to see if a package has arrived, residents use ParcelBuddy to scan packages they see in the lobby. This creates a searchable, real-time "Digital Lobby" for the entire building.

-----

## 2\. Technical Requirement Mapping (Grading Rubric)

| Requirement             | Weight | System Implementation                                                                                                                         |
| :---------------------- | :----- | :-------------------------------------------------------------------------------------------------------------------------------------------- |
| **Relational DB CRUD**  | 10%    | **Room/SQLite:** Local "Personal Log" of all packages you have personally scanned or claimed. Users can *Update* notes and *Delete* old logs. |
| **Firebase Auth**       | 5%     | **Email/Password Provider:** Restricts app access to verified dorm residents only.                                                            |
| **Storing in Firebase** | 5%     | **Firestore:** Active "Lobby" list (Real-time). <br> **Firebase Storage:** Stores photos of package labels.                                   |
| **Notifications**       | 5%     | **FCM (Firebase Cloud Messaging):** Triggers a "Package Alert" to all users when a new parcel is scanned into the lobby.                      |
| **Smartphone Resource** | 5%     | **Hardware Camera:** Used to capture the package label for visual identification.                                                             |
| **Demo & GitHub**       | 10%    | **Documentation:** Professional README, clean architecture, and a 3-minute walkthrough video.                                                 |

-----

## 3\. System Architecture & Data Schema

### A. Cloud Schema (Firestore)

**Collection: `lobby_parcels`**

  * `id` (String): Document ID
  * `resi_number` (String): Receipt/Tracking number
  * `photo_url` (String): Link to Firebase Storage
  * `uploader_name` (String): Name of the student who scanned it
  * `status` (String): "WAITING" or "CLAIMED"
  * `timestamp` (ServerTimestamp)

### B. Local Relational Schema (Room DB)

**Table: `user_history`**

  * `id` (Int, Primary Key)
  * `resi_number` (String)
  * `action_type` (String): e.g., "FOUND" or "RECEIVED"
  * `user_notes` (String): **Editable field (Update)**
  * `recorded_at` (String)

-----

## 4\. The 5-Day Agile Sprint Plan

### **Day 1: Foundation & Authentication**

  * **Goal:** Create project and secure it.
  * **Tasks:**
    1.  Initialize Android/Flutter project.
    2.  Connect Firebase via the Firebase Console.
    3.  Implement **Firebase Auth** (Signup/Login screens).
    4.  Build the Bottom Navigation (Lobby, Scan, History).

### **Day 2: Hardware Integration & Cloud Storage**

  * **Goal:** Get the camera talking to the cloud.
  * **Tasks:**
    1.  Implement **Camera Intent**: User takes a photo of a package.
    2.  Setup **Firebase Storage**: Upload the image and get the `downloadURL`.
    3.  Create the "Scan Form": Input Resi number + the photo preview.

### **Day 3: Real-time Lobby (The "Single Source of Truth")**

  * **Goal:** Sync data across all users.
  * **Tasks:**
    1.  Implement **Firestore CRUD**: "Upload" pushes package data to the cloud.
    2.  Build the **Home Screen**: A `RecyclerView` that listens to Firestore.
    3.  Implement the **Claim Button**: Changes status from "WAITING" to "CLAIMED" in the cloud.

### **Day 4: Local Persistence & Notifications**

  * **Goal:** Satisfy the Relational DB and Alerts requirements.
  * **Tasks:**
    1.  Setup **Room Database**: When a user scans/claims a package, save a record to the local SQLite DB.
    2.  Implement **CRUD on Local DB**: Build the "History" tab where users can edit their personal notes or delete records.
    3.  Setup **Firebase Cloud Messaging**: Send a simple push notification when a new document is added to the Firestore collection.

### **Day 5: QA, UI Polish, & Submission**

  * **Goal:** Ensure "A" grade quality.
  * **Tasks:**
    1.  **Edge Case Testing:** Check for "No Internet" states or empty Resi fields.
    2.  **UI Design:** Add consistent colors, rounded corners, and a professional app icon.
    3.  **Demo Video:** Record a screen-capture walkthrough.
    4.  **GitHub:** Push final code with a clean README.

-----

## 5\. Analyst’s "Success Tips" for Undergraduates

1.  **MVP First:** Don't spend 5 hours on a logo. Get the Camera-to-Firebase upload working first.
2.  **ML Kit (Optional Bonus):** If you finish Day 2 early, use **Google ML Kit** to automatically read the text from the package photo so the user doesn't have to type the Resi number. This will impress your lecturer.
3.  **The "Wait" State:** Since the project is 40% of your grade, make sure your Demo Video explicitly points out every requirement (e.g., "Now I am editing a local record, which demonstrates CRUD on a relational database").

**You are now cleared for development. Good luck, Dev.**

# 5-Day ParcelBuddy Development Plan

This plan is focused on delivering a fully functional app within 5 days, prioritizing working features over clean architecture.

---

## Day 1: Project Setup & Authentication
- Initialize the Flutter project.
- Connect the app to Firebase (add config files, set up in Firebase Console).
- Implement Firebase Auth (email/password sign up & login).
- Create basic navigation (BottomNavigationBar: Lobby, Scan, History).

## Day 2: Camera & Cloud Storage
- Implement camera/photo capture for package labels.
- Integrate Firebase Storage to upload and retrieve image URLs.
- Build a simple scan form (input resi number, photo preview, upload button).

## Day 3: Firestore Integration
- Implement Firestore CRUD for the lobby parcels (add, update status, listen for changes).
- Build the Lobby screen (list of parcels, real-time updates).
- Add a claim button to update parcel status.

## Day 4: Local Database & Notifications
- Set up local SQLite/Room DB for user history (save scanned/claimed packages).
- Implement CRUD for local history (edit notes, delete records).
- Integrate Firebase Cloud Messaging for push notifications on new parcels.

## Day 5: Testing, Polish, and Submission
- Test all flows (auth, scan, lobby, history, notifications).
- Handle edge cases (no internet, empty fields).
- Polish UI (basic colors, icons, rounded corners).
- Prepare demo video and documentation.

---

**Tips:**
- Prioritize features required for grading.
- Use simple state management (e.g., setState or Provider).
- Focus on working features, not architecture.
- Communicate blockers early.

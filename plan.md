# ParcelBuddy: Revised Product Requirements & Implementation Plan

## Product Vision
ParcelBuddy eliminates "Lobby Chaos" in shared living spaces by providing a digital, real-time lobby for package arrivals. Residents can confirm, view, and claim packages for their organization (boarding house, workplace, etc.)—no more endless group chats.

---

## Key Features & Requirements
- **Multi-Organization Support:** Users can join or create multiple organizations. Each package is linked to an organization.
- **User Authentication:** Email/password login via Firebase Auth.
- **Organization Management:** Users can create, join, and switch organizations. Roles (admin/member) are for managing members only.
- **Package Confirmation:** Users can enter or scan a resi number. The app checks for matching packages in the selected organization.
- **Lobby Feed:** Real-time list of packages for the selected organization. Only the uploader can edit/delete their own packages.
- **History:** Users see a log of packages they’ve confirmed or claimed.
- **No Image Upload:** Due to Firebase Storage limitations, only resi numbers and package info are stored.

---

## Firestore Data Model
- **organizations**: orgId, name, address
- **users**: userId, name, email, organizations[]
- **memberships**: membershipId, userId, orgId, role, joinedAt
- **lobby_parcels**: id, resi_number, orgId, uploader_name, uploader_id, status, timestamp

---

## Implementation Steps (Condensed for Tight Deadline)
1. **User Registration & Login**
   - Register/login with Firebase Auth
   - Create user document in Firestore
2. **Organization Management**
   - After login, user can create or join organizations
   - Store memberships in Firestore
   - Dropdown in Lobby for org selection/management
3. **Scan/Confirm Package**
   - User enters or scans resi number
   - App checks for package in selected org
   - If found, show info and allow claim/confirmation
4. **Lobby Feed**
   - Show real-time list of packages for selected org
   - Only uploader can edit/delete their own packages
5. **History**
   - Show user’s personal log (from Firestore or local DB)
6. **Polish & Submission**
   - Basic validation, error handling, minimal UI polish
   - Demo video & documentation

---

## Success Tips
- Focus on core flows: auth, org management, scan/confirm, lobby feed
- Use mock data for organizations if needed
- Skip advanced features if time is tight
- Demo every requirement in your video

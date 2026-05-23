Shaca — Hyperlocal Tool Rental App
An Android app that lets neighbours rent and lend tools within a trusted local community.

The Problem
Borrowing tools from neighbours is common but awkward — no trust system, no accountability, no way to verify availability.

The Solution
Shaca creates a hyperlocal gated community (1km radius) where only verified neighbours can rent or lend tools — with built-in trust scoring, live verification, and secure payments.

Key Features
📍 Location-based gated community: 1km radius — no entry without being in your locality.

🤝 Referral-based trust scoring: Neighbours vouch for each other.

📸 Live photo verification: Required before every handover — no old/fake photos.

💳 Secure payments: Razorpay integration with a security deposit system.

🔵 Bluetooth handshake: Confirms physical tool handover.

🔔 Return reminders: Automated alerts the day before and day of return.

👤 Guest mode: Browse inventory without community access.

🛡️ Admin panel: Built-in dispute resolution.

🌙 Dark mode: Full UI support.

How It Works
User enters their home location on a map.

App checks if a gated community exists within 1km.

If yes — entry requires a neighbour referral.

If no — user can create a new community.

Lenders post tools with details and availability.

Renters request a tool → lender captures a live photo → first to pay secures the tool.

A Bluetooth handshake confirms the physical handover.

The security deposit is returned once the tool is returned and verified.

Tech Stack
Framework: Flutter

Language: Dart

Backend: Firebase (Auth, Firestore, OTP)

Payments: Razorpay API

Maps: Google Maps API

Hardware: Bluetooth API (via Flutter plugins)

GitHub Topics
flutter dart firebase peer-to-peer hyperlocal rental-app community razorpay android

Status
✅ Fully functional — app runs on Android devices.

# Shaca — Hyperlocal Tool Rental App

A Flutter app that lets neighbours rent and lend tools within a trusted local community.

---

## The Problem

Borrowing tools from neighbours is common but awkward — no trust system, no accountability, no way to verify availability.

## The Solution

Shaca creates a hyperlocal gated community (1km radius) where only verified neighbours can rent or lend tools — with built-in trust scoring, live verification, and secure payments.


---

## Demo

> [https://drive.google.com/file/d/10L714J5DQu3aWw2qOXShRNyFKjmChdx5/view?usp=sharing](#)

---

## Key Features

- 📍 **Location-based gated community** — 1km radius, no entry without being in your locality
- 🤝 **Referral-based trust scoring** — neighbours vouch for each other
- 📸 **Live photo verification** — required before every handover, no old or fake photos
- 💳 **Secure payments** — Razorpay integration with security deposit system
- 🔵 **Bluetooth handshake** — confirms physical tool handover
- 🔔 **Return reminders** — automated alerts the day before and day of return
- 👤 **Guest mode** — browse inventory without community access
- 🛡️ **Admin panel** — built-in dispute resolution
- 🌙 **Dark mode** — full UI support

---

## How It Works

1. User enters their home location on a map
2. App checks if a gated community exists within 1km
3. If yes — entry requires a neighbour referral
4. If no — user can create a new community
5. Lenders post tools with details and availability
6. Renters request a tool → lender captures a live photo → first to pay secures the tool
7. Bluetooth handshake confirms physical handover
8. Security deposit is returned once the tool is returned and verified

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart |
| Backend | Firebase (Auth, Firestore, OTP) |
| Payments | Razorpay API |
| Maps | Google Maps API |
| Hardware | Bluetooth API (via Flutter plugins) |

---

## Status

✅ Fully functional — runs on Android devices

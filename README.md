# Kaquiz — Real-time Social Tracker 🗺️🚀

Kaquiz is a high-performance, full-stack mobile application designed for real-time location sharing and social networking. Keep track of your friends on a beautiful interactive map with a secure and scalable infrastructure.

## ✨ Core Features
- **📍 Real-time Interactive Map**: Visualize your current position and track your friends on a sleek, responsive map interface.
- **🤝 Mutual Friendship System**: Send and receive friend requests. Connection is bidirectional to ensure privacy.
- **📡 Background GPS Polling**: Automatic location updates every 10 seconds to keep the markers live and accurate.
- **👤 Modern Profiles**: Profile customization with synchronized Google avatars and editable display names.
- **🔐 Secure Infrastructure**: Industry-standard **Google Sign-In** authentication paired with **JWT-protected** backend endpoints.

## 🛠 Tech Stack
### Frontend
- **Framework**: Flutter (Dart)
- **Maps**: Google Maps Flutter SDK
- **State Management**: Stateful Widgets & Specialized Services
- **Communication**: REST API with real-time polling

### Backend
- **Language**: Go (Golang) 1.22
- **Router**: Gorilla Mux
- **Database Driver**: pgx (with connection pooling)
- **Security**: JWT & Google OAuth Verification

### Infrastructure
- **Database**: PostgreSQL on **Supabase**
- **Hosting**: **Render** (Auto-deployment)

## 🚀 Installation & Setup

### 1. Backend Setup
```bash
cd backend
# Ensure your .env contains DATABASE_URL and JWT_SECRET
go run cmd/main.go
```

### 2. Frontend Setup
```bash
cd frontend
# Ensure your .env contains API_URL (pointing to your Render URL)
flutter run
```

---
*Developed with ❤️ as part of a collaborative coding challenge.*

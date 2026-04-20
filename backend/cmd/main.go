package main

import (
	"fmt"
	"log"
	"net/http"

	"kaquiz-backend/db"
	"kaquiz-backend/handlers"

	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
)

func main() {
	// Load .env
	err := godotenv.Load()
	if err != nil {
		log.Fatal("❌ Error loading .env file")
	}

	// Connect to Supabase
	db.Connect()

	// Set up router
	router := mux.NewRouter()

	// Routes
	router.HandleFunc("/api/auth", handlers.Auth).Methods("POST")

	// Start server
	fmt.Println("🚀 Server running on port 8080")
	log.Fatal(http.ListenAndServe(":8080", router))
}

// // Flutter sends:        { "id_token": "google_token_here" }
//                               ↓
// Your Go backend:
//   1. Receives the Google token
//   2. Verifies it with Google
//   3. Gets user's email + name + avatar from Google
//   4. Checks if user exists in database
//      - If YES → just return JWT
//      - If NO  → create new user, then return JWT
//   5. Returns:          { "access_token": "your_jwt_here" }
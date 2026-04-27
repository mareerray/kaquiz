package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"kaquiz-backend/db"
	"kaquiz-backend/handlers"
	"kaquiz-backend/middleware"

	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
)

func main() {
	// Load .env
	err := godotenv.Load()
	if err != nil {
		log.Println("⚠️ No .env file found, using system environment variables")
	}

	// Connect to Supabase
	db.Connect()

	// Set up router
	router := mux.NewRouter()

	// Routes
	router.HandleFunc("/api/auth", handlers.Auth).Methods("POST")
	// Protected routes (require JWT)
	protected := router.PathPrefix("/api").Subrouter()
	protected.Use(middleware.AuthMiddleware)
	protected.HandleFunc("/users", handlers.UpdateUser).Methods("PUT")
	protected.HandleFunc("/users/me", handlers.GetMyProfile).Methods("GET")
	protected.HandleFunc("/users/search", handlers.SearchUsers).Methods("GET")
	protected.HandleFunc("/locations", handlers.UpdateLocation).Methods("POST")
	protected.HandleFunc("/invites/{user_id}", handlers.SendInvite).Methods("POST") // invites + receipeint ID in URL
	protected.HandleFunc("/invites", handlers.GetInvites).Methods("GET")
	protected.HandleFunc("/invites/{id}/accept", (handlers.AcceptInvite)).Methods("POST")
	protected.HandleFunc("/invites/{id}/decline", (handlers.DeclineInvite)).Methods("POST")
	protected.HandleFunc("/friends", handlers.GetFriends).Methods("GET")
	protected.HandleFunc("/friends/{id}", handlers.DeleteFriend).Methods("DELETE")


	// Start server
	// ✅ After
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080" // fallback for local development
	}
	fmt.Println("🚀 Server running on port", port)
	log.Fatal(http.ListenAndServe(":"+port, router))
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
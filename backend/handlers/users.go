package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"fmt"

	"kaquiz-backend/db"
	"kaquiz-backend/middleware"
)

type UpdateUserRequest struct {
	Name   string `json:"name"`
	Avatar string `json:"avatar"`
}

func UpdateUser(w http.ResponseWriter, r *http.Request) {
	// Get userID from JWT middleware
	userID := r.Context().Value(middleware.UserIDKey).(string)

	// Decode request body
	var req UpdateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	// Update AND return the updated user in one query
    var id int
    var name, avatar, email string

    // Only update avatar if it was provided
    var err error
	err = db.DB.QueryRow(context.Background(),
		`UPDATE users 
		SET 
		name   = CASE WHEN $1 = '' THEN name ELSE $1 END,
		avatar = CASE WHEN $2 = '' THEN avatar ELSE $2 END
		WHERE id = $3
		RETURNING id, name, avatar, email`,
		req.Name, req.Avatar, userID,
	).Scan(&id, &name, &avatar, &email)
	
	if err != nil {
        fmt.Println("❌ Failed to update user:", err)
        http.Error(w, "Failed to update user", http.StatusInternalServerError)
        return
    }

    fmt.Println("✅ User updated:", name)

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "id":     id,
        "name":   name,
        "avatar": avatar,
        "email":  email,
    })
}

func SearchUsers(w http.ResponseWriter, r *http.Request) {
	// Get email from query: /users/search?email=maire@gmail.com
	email := r.URL.Query().Get("email")
	fmt.Println("🔍 Search request for email:", email) 
	if email == "" {
		http.Error(w, "Email is required", http.StatusBadRequest)
		return
	}

	// Search user by email
	var id int
	var name, avatar, userEmail string

	err := db.DB.QueryRow(context.Background(),
		`SELECT id, name, avatar, email FROM users WHERE email = $1`,
		email,
	).Scan(&id, &name, &avatar, &userEmail)

	if err != nil {
		fmt.Println("❌ User not found for email:", email)
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	fmt.Println("✅ Found user:", name, id)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"id":     id,
		"name":   name,
		"avatar": avatar,
		"email":  userEmail,
	})
}
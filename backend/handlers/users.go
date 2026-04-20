package handlers

import (
	"context"
	"encoding/json"
	"net/http"

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

	// Update user in database
	_, err := db.DB.Exec(context.Background(),
		`UPDATE users SET name = $1, avatar = $2 WHERE id = $3`,
		req.Name, req.Avatar, userID,
	)
	if err != nil {
		http.Error(w, "Failed to update user", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "User updated successfully",
	})
}

func SearchUsers(w http.ResponseWriter, r *http.Request) {
	// Get email from query: /users/search?email=maire@gmail.com
	email := r.URL.Query().Get("email")
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
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"id":     id,
		"name":   name,
		"avatar": avatar,
		"email":  userEmail,
	})
}
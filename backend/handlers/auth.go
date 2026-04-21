package handlers

import (
    "context"
    "encoding/json"
    "net/http"
    "os"
    "time"
    "fmt"

    "kaquiz-backend/db"

    "github.com/golang-jwt/jwt/v5"
    "google.golang.org/api/idtoken"
)

// What Flutter sends
type AuthRequest struct {
    IDToken string `json:"id_token"`
}

// What we return
type AuthResponse struct {
    AccessToken string `json:"access_token"`
}

func Auth(w http.ResponseWriter, r *http.Request) {
    // 1. Read the request body
    var req AuthRequest
    err := json.NewDecoder(r.Body).Decode(&req)
    if err != nil || req.IDToken == "" {
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }

	// 2. Verify Google token
// 2. Verify Google token - try both Web and iOS client IDs
	clientIDs := []string{
		os.Getenv("GOOGLE_CLIENT_ID"),
		os.Getenv("GOOGLE_IOS_CLIENT_ID"),
	}

	var payload *idtoken.Payload
	for _, clientID := range clientIDs {
		if clientID == "" {
			continue
		}
		payload, err = idtoken.Validate(context.Background(), req.IDToken, clientID)
		if err == nil {
			break // ✅ found a match!
		}
	}

	if payload == nil {
		http.Error(w, "Invalid Google token", http.StatusBadRequest)
		return
	}

	// 3. Get user info from Google token
	email := payload.Claims["email"].(string)
	name, _ := payload.Claims["name"].(string)
	avatar, _ := payload.Claims["picture"].(string)

	// 4. Check if user exists, if not create them
	var userID int
	err = db.DB.QueryRow(context.Background(),
		`INSERT INTO users (email, name, avatar)
		VALUES ($1, $2, $3)
		ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
		RETURNING id`,
		email, name, avatar,
	).Scan(&userID)
	if err != nil {
		fmt.Println("❌ DB Error:", err)  // ← add this
		http.Error(w, "Database error", http.StatusInternalServerError)
		return	
	}

	// 5. Create JWT token
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": userID,
		"email":   email,
		"exp":     time.Now().Add(24 * time.Hour).Unix(),
	})

	tokenString, err := token.SignedString([]byte(os.Getenv("JWT_SECRET")))
	if err != nil {
		http.Error(w, "Failed to create token", http.StatusInternalServerError)
		return
	}

	// 6. Return token to Flutter
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(AuthResponse{AccessToken: tokenString})
}
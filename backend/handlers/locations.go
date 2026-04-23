package handlers

import (
    "context"
    "encoding/json"
    "net/http"
    "time"

    "kaquiz-backend/db"
    "kaquiz-backend/middleware"
)

type UpdateLocationRequest struct {
    Latitude  float64 `json:"latitude"`
    Longitude float64 `json:"longitude"`
}

func UpdateLocation(w http.ResponseWriter, r *http.Request) {
    // Step 1: Who is calling? Get their ID from the JWT token
    userID := r.Context().Value(middleware.UserIDKey).(string)

    // Step 2: Read the lat/lng from the request body
    var req UpdateLocationRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }

    // Step 3: Save lat, lng, and current time into the database
    _, err := db.DB.Exec(context.Background(),
        `UPDATE users SET lat = $1, lng = $2, last_seen = $3 WHERE id = $4`,
        req.Latitude, req.Longitude, time.Now(), userID,
    )
    if err != nil {
        http.Error(w, "Failed to update location", http.StatusInternalServerError)
        return
    }

    // Step 4: Reply with success
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "message": "Location updated successfully",
    })
}

package handlers

import (
    "context"
    "encoding/json"
    "net/http"
    "strconv"
    "fmt"

    "kaquiz-backend/db"
    "kaquiz-backend/middleware"

    "github.com/gorilla/mux"
)

func SendInvite(w http.ResponseWriter, r *http.Request) {
    // Step 1: Who is sending? Get their ID from JWT
    senderID := r.Context().Value(middleware.UserIDKey).(string)

    // Step 2: Who are they inviting? Get from URL /invites/{user_id}
    vars := mux.Vars(r)
    receiverID, err := strconv.Atoi(vars["user_id"])
    if err != nil {
        http.Error(w, "Invalid user ID", http.StatusBadRequest)
        return
    }

    fmt.Println("📨 Invite from:", senderID, "→ to:", receiverID)

    // Step 3: Don't allow inviting yourself
    if strconv.Itoa(receiverID) == senderID {
        http.Error(w, "You cannot invite yourself", http.StatusBadRequest)
        return
    }

    // Step 4: Check if invite already exists
    var existing int
    err = db.DB.QueryRow(context.Background(),
        `SELECT COUNT(*) FROM invites WHERE sender_id = $1 AND recipient_id = $2`,
        senderID, receiverID,
    ).Scan(&existing)

    if err == nil && existing > 0 {
        http.Error(w, "Invite already sent", http.StatusConflict)
        return
    }

    // Step 5: Insert the new invite (no status needed!)
    _, err = db.DB.Exec(context.Background(),
        `INSERT INTO invites (sender_id, recipient_id) VALUES ($1, $2)`,
        senderID, receiverID,
    )
    if err != nil {
        fmt.Println("❌ Failed to insert invite:", err)
        http.Error(w, "Failed to send invite", http.StatusInternalServerError)
        return
    }

    fmt.Println("✅ Invite sent successfully")

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "message": "Invite sent successfully",
    })
}
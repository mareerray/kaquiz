package handlers

import (
    "context"
    "encoding/json"
    "net/http"
    "strconv"
    "fmt"
    "time"

    "kaquiz-backend/db"
    "kaquiz-backend/middleware"

    "github.com/gorilla/mux"
)

// -------------- SEND  INVITES ------------------
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
        `SELECT COUNT(*) 
            FROM invites 
            WHERE sender_id = $1 AND recipient_id = $2`,
        senderID, receiverID,
    ).Scan(&existing)

    if err == nil && existing > 0 {
        http.Error(w, "Invite already sent", http.StatusConflict)
        return
    }

    // Step 5: Insert the new invite (no status needed!)
    _, err = db.DB.Exec(context.Background(),
        `INSERT INTO invites (sender_id, recipient_id) VALUES ($1, $2)`, // prevent duplicates
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

// -------------- GET INVITES ------------------
func GetInvites(w http.ResponseWriter, r *http.Request) {
    // Step 1: Who is asking? Get their ID from JWT
    userIDStr := r.Context().Value(middleware.UserIDKey).(string)
    userID, err := strconv.Atoi(userIDStr)
    if err != nil {
        http.Error(w, "Invalid user ID", http.StatusBadRequest)
        return
    }

    fmt.Println("📬 Getting invites for user:", userID)

    // Step 2: Find all invites where this user is the recipient
    rows, err := db.DB.Query(context.Background(),
        `SELECT i.id, i.sender_id, u.name, u.avatar, i.created_at 
            FROM invites i
            JOIN users u ON u.id = i.sender_id
            WHERE i.recipient_id = $1`,
        userID,
    )
    if err != nil {
        fmt.Println("❌ Failed to get invites:", err)
        http.Error(w, "Failed to get invites", http.StatusInternalServerError)
        return
    }
    defer rows.Close()

    // Step 3: Build the list
    var invites []map[string]interface{}
    for rows.Next() {
        var id, senderID int
        var name, avatar string
        var createdAt time.Time

        err := rows.Scan(&id, &senderID, &name, &avatar, &createdAt)
        if err != nil {
            fmt.Println("❌ Scan error:", err) 
            continue
        }

        invites = append(invites, map[string]interface{}{
            "id":         id,
            "sender_id":  senderID,
            "name":       name,
            "avatar":     avatar,
            "created_at": createdAt.Format("2006-01-02 15:04:05"),
        })
    }

    // Return empty array instead of null if no invites
    if invites == nil {
        invites = []map[string]interface{}{}
    }

    fmt.Println("✅ Found", len(invites), "invites")

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(invites)
}

// -------------- ACCEPT INVITES ------------------
func AcceptInvite(w http.ResponseWriter, r *http.Request) {
    // Step 1: Who is accepting? (the recipient)
    userIDStr := r.Context().Value(middleware.UserIDKey).(string)
    userID, _ := strconv.Atoi(userIDStr)

    // Step 2: Which invite?
    vars := mux.Vars(r)
    inviteID, err := strconv.Atoi(vars["id"])
    if err != nil {
        http.Error(w, "Invalid invite ID", http.StatusBadRequest)
        return
    }

    fmt.Println("✅ Accepting invite:", inviteID, "by user:", userID)

    // Step 3: Find the invite and verify it belongs to this user
    var senderID int
    err = db.DB.QueryRow(context.Background(),
        `SELECT sender_id FROM invites WHERE id = $1 AND recipient_id = $2`,
        inviteID, userID,
    ).Scan(&senderID)

    if err != nil {
        fmt.Println("❌ Invite not found or not yours:", err)
        http.Error(w, "Invite not found", http.StatusNotFound)
        return
    }

    // Step 4: Add to friends table
    _, err = db.DB.Exec(context.Background(),
        `INSERT INTO friends (user_id, friend_id) VALUES ($1, $2),
         ON CONFLICT (user_id, friend_id) DO NOTHING`, // prevent duplicates
        userID, senderID,
    )

    if err != nil {
        fmt.Println("❌ Failed to add friend:", err)
        http.Error(w, "Failed to accept invite", http.StatusInternalServerError)
        return
    }

    // Step 5: Delete the invite
    _, err = db.DB.Exec(context.Background(),
        `DELETE FROM invites WHERE id = $1`,
        inviteID,
    )
    if err != nil {
        fmt.Println("❌ Failed to delete invite:", err)
    }

    fmt.Println("🎉 Friendship created:", userID, "↔", senderID)

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "message": "Friend added successfully",
    })
}

// -------------- DECLINE INVITES ------------------
func DeclineInvite(w http.ResponseWriter, r *http.Request) {
    // Step 1: Who is declining?
    userIDStr := r.Context().Value(middleware.UserIDKey).(string)
    userID, _ := strconv.Atoi(userIDStr)

    // Step 2: Which invite?
    vars := mux.Vars(r)
    inviteID, err := strconv.Atoi(vars["id"])
    if err != nil {
        http.Error(w, "Invalid invite ID", http.StatusBadRequest)
        return
    }

    fmt.Println("❌ Declining invite:", inviteID, "by user:", userID)

    // Step 3: Delete the invite (only if it belongs to this user)
    result, err := db.DB.Exec(context.Background(),
        `DELETE FROM invites WHERE id = $1 AND recipient_id = $2`,
        inviteID, userID,
    )
    if err != nil || result.RowsAffected() == 0 {
        http.Error(w, "Invite not found", http.StatusNotFound)
        return
    }

    fmt.Println("🗑️ Invite declined and deleted")

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "message": "Invite declined",
    })
}
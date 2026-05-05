package handlers

import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "strconv"
	"time"

    "kaquiz-backend/db"
    "kaquiz-backend/middleware"

    "github.com/gorilla/mux"
)

func GetFriends(w http.ResponseWriter, r *http.Request) {
    userIDStr := r.Context().Value(middleware.UserIDKey).(string)
    userID, _ := strconv.Atoi(userIDStr)

    fmt.Println("👥 Getting friends for user:", userID)

    rows, err := db.DB.Query(context.Background(),
        `SELECT u.id, u.name, u.avatar, u.lat, u.lng, u.last_seen
            FROM friends f
            JOIN users u ON u.id = CASE 
                WHEN f.user_id = $1 THEN f.friend_id 
                ELSE f.user_id 
            END
            WHERE f.user_id = $1 OR f.friend_id = $1
            ORDER BY u.name ASC`,
        userID,
    )
    if err != nil {
        fmt.Println("❌ Failed to get friends:", err)
        http.Error(w, "Failed to get friends", http.StatusInternalServerError)
        return
    }
    defer rows.Close()

    var friends []map[string]interface{}
    for rows.Next() {
        var id int
        var name, avatar string
        var lat, lng *float64
        var lastSeen *time.Time

        err := rows.Scan(&id, &name, &avatar, &lat, &lng, &lastSeen)
        if err != nil {
            fmt.Println("❌ Scan error:", err)
            continue
        }

		var lastSeenStr *string
		if lastSeen != nil {
			s := lastSeen.Format(time.RFC3339)
			lastSeenStr = &s
		}
        friends = append(friends, map[string]interface{}{
            "id":        id,
            "name":      name,
            "avatar":    avatar,
            "lat":       lat,
            "lng":       lng,
            "last_seen": lastSeenStr,
        })
    }

    if friends == nil {
        friends = []map[string]interface{}{}
    }

    fmt.Println("✅ Found", len(friends), "friends")

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(friends)
}

func DeleteFriend(w http.ResponseWriter, r *http.Request) {
    userIDStr := r.Context().Value(middleware.UserIDKey).(string)
    userID, _ := strconv.Atoi(userIDStr)

    vars := mux.Vars(r)
    friendID, err := strconv.Atoi(vars["id"])
    if err != nil {
        http.Error(w, "Invalid friend ID", http.StatusBadRequest)
        return
    }

    fmt.Println("🗑️ Removing friend:", friendID, "for user:", userID)

    result, err := db.DB.Exec(context.Background(),
        `DELETE FROM friends 
            WHERE (user_id = $1 AND friend_id = $2)
            OR (user_id = $2 AND friend_id = $1)`,
        userID, friendID,
    )
    if err != nil || result.RowsAffected() == 0 {
        http.Error(w, "Friend not found", http.StatusNotFound)
        return
    }

    fmt.Println("✅ Friend removed")

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "message": "Friend removed successfully",
    })
}
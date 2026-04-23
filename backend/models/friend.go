package models

// Friend represents an accepted friendship between two users.
type Friend struct {
    ID       int     `json:"id"`
    UserID   int     `json:"user_id"`
    FriendID int     `json:"friend_id"`
}
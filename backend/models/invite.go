package models

// Invite represents a pending friend request between two users.
type Invite struct {
    ID          int    `json:"id"`
    SenderID    int    `json:"sender_id"`
    RecipientID int    `json:"recipient_id"`
    CreatedAt   string `json:"created_at"`
}
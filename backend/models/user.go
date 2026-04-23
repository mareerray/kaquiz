package models

// User represents a registered user in the database.
type User struct {
    ID       int     `json:"id"`
    Email    string  `json:"email"`
    Name     string  `json:"name"`
    Avatar   string  `json:"avatar"`
    Lat      float64 `json:"lat"`
    Lng      float64 `json:"lng"`
    LastSeen string  `json:"last_seen"`
}

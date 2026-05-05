package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
)

type Bot struct {
	Name   string
	Email  string
	Avatar string
	Lat    float64
	Lng    float64
}

func main() {
	// Load .env if exists
	godotenv.Load(".env")

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL is not set")
	}

	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		log.Fatal("Unable to create connection pool:", err)
	}
	defer pool.Close()

	bots := []Bot{
		{"Mavka Bot", "mavka.bot@kaquiz.com", "https://api.dicebear.com/7.x/avataaars/png?seed=Mavka", 60.10, 19.94},
		{"Grit Bot", "grit.bot@kaquiz.com", "https://api.dicebear.com/7.x/avataaars/png?seed=Grit", 60.11, 19.93},
		{"Quiz Master", "master@kaquiz.com", "https://api.dicebear.com/7.x/avataaars/png?seed=Master", 60.09, 19.95},
		{"Explorer Bot", "explorer@kaquiz.com", "https://api.dicebear.com/7.x/avataaars/png?seed=Explorer", 60.12, 19.91},
		{"Traveler Bot", "traveler@kaquiz.com", "https://api.dicebear.com/7.x/avataaars/png?seed=Travel", 60.08, 19.97},
	}

	for _, bot := range bots {
		var botID int
		// 1. Create or Update Bot User
		err = pool.QueryRow(context.Background(),
			`INSERT INTO users (name, email, avatar, lat, lng, last_seen)
			 VALUES ($1, $2, $3, $4, $5, $6)
			 ON CONFLICT (email) DO UPDATE 
			 SET lat = $4, lng = $5, last_seen = $6
			 RETURNING id`,
			bot.Name, bot.Email, bot.Avatar, bot.Lat, bot.Lng, time.Now().Add(-time.Duration(rand.Intn(120)) * time.Minute),
		).Scan(&botID)

		if err != nil {
			fmt.Printf("❌ Failed to create bot %s: %v\n", bot.Name, err)
			continue
		}

		fmt.Printf("✅ Bot created: %s (ID: %d)\n", bot.Name, botID)

		// 2. Make this bot friends with EVERYONE
		_, err = pool.Exec(context.Background(),
			`INSERT INTO friends (user_id, friend_id)
			 SELECT u.id, $1 FROM users u
			 WHERE u.id != $1 AND u.email NOT LIKE '%@kaquiz.com'
			 ON CONFLICT DO NOTHING`,
			botID,
		)
		if err != nil {
			fmt.Printf("❌ Failed to link bot %s to users: %v\n", bot.Name, err)
		} else {
			fmt.Printf("🔗 Bot %s linked to all users\n", bot.Name)
		}
	}

	fmt.Println("\n🎉 Seeding completed successfully!")
}

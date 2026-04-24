package db

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

var DB *pgxpool.Pool

func Connect() {
	connStr := os.Getenv("DATABASE_URL")
	if connStr == "" {
		log.Fatal("❌ DATABASE_URL is not set in .env")
	}

	var err error
	DB, err = pgxpool.New(context.Background(), connStr)
	if err != nil {
		log.Fatal("❌ Failed to connect to DB:", err)
	}

	fmt.Println("✅ Connected to Supabase!")
}
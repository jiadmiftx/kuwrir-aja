package config

import (
	"os"
	"strconv"
)

// Config holds all application configuration
type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	R2       R2Config
	Valhalla ValhallaConfig
}

type ServerConfig struct {
	Port string
	Mode string // "debug" or "release"
}

type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
}

type JWTConfig struct {
	Secret          string
	ExpiryHours     int
	RefreshExpiryHours int
}

type R2Config struct {
	AccountID       string
	AccessKeyID     string
	AccessKeySecret string
	BucketName      string
	PublicURL       string // e.g., https://images.kuwrirapp.com
}

type ValhallaConfig struct {
	BaseURL string // e.g., http://localhost:8002
}

// Load reads configuration from environment variables with sensible defaults
func Load() *Config {
	return &Config{
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "8080"),
			Mode: getEnv("SERVER_MODE", "debug"),
		},
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "kuwrir"),
			Password: getEnv("DB_PASSWORD", "kuwrir_secret"),
			DBName:   getEnv("DB_NAME", "kuwrir_db"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     getEnv("REDIS_PORT", "6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       getEnvInt("REDIS_DB", 0),
		},
		JWT: JWTConfig{
			Secret:             getEnv("JWT_SECRET", "kuwrir-super-secret-key-change-me"),
			ExpiryHours:        getEnvInt("JWT_EXPIRY_HOURS", 24),
			RefreshExpiryHours: getEnvInt("JWT_REFRESH_EXPIRY_HOURS", 168), // 7 days
		},
		R2: R2Config{
			AccountID:       getEnv("R2_ACCOUNT_ID", ""),
			AccessKeyID:     getEnv("R2_ACCESS_KEY_ID", ""),
			AccessKeySecret: getEnv("R2_ACCESS_KEY_SECRET", ""),
			BucketName:      getEnv("R2_BUCKET_NAME", "kuwrir-images"),
			PublicURL:       getEnv("R2_PUBLIC_URL", ""),
		},
		Valhalla: ValhallaConfig{
			BaseURL: getEnv("VALHALLA_URL", "http://localhost:8002"),
		},
	}
}

// DSN returns the PostgreSQL connection string
func (d *DatabaseConfig) DSN() string {
	return "host=" + d.Host +
		" port=" + d.Port +
		" user=" + d.User +
		" password=" + d.Password +
		" dbname=" + d.DBName +
		" sslmode=" + d.SSLMode +
		" TimeZone=Asia/Makassar"
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if val := os.Getenv(key); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			return i
		}
	}
	return fallback
}

#!/usr/bin/bash

# set these variables before running the script
PJT_NAME=PROJECT
MODULE_NAME=github.com/username/$PJT_NAME
TGT_FOLDER=~/go-development/$PJT_NAME

API_FOLDER=$TGT_FOLDER/cmd/api
DOCS_FOLDER=$TGT_FOLDER/docs
INTERNAL_FOLDER=$TGT_FOLDER/internal
DATABASES_FOLDER=$TGT_FOLDER/internal/databases
V1_HANDLERS_FOLDER=$TGT_FOLDER/internal/handlers/v1
MIDDLEWARE_FOLDER=$TGT_FOLDER/internal/middleware
REPOSITORIES_FOLDER=$TGT_FOLDER/internal/repositories
SERVICES_FOLDER=$TGT_FOLDER/internal/services
TYPES_FOLDER=$TGT_FOLDER/internal/types
UTILS_FOLDER=$TGT_FOLDER/internal/utils
TESTS_FOLDER=$TGT_FOLDER/internal/tests

RED='\e[31m'
NC='\e[0m'

function print_error {
    echo -e "${RED}$1${NC}"
}

# create main directory
if [[ ! -d "$TGT_FOLDER" ]]; then 
    echo "Folder '$TGT_FOLDER' do not exists, creating..."
    mkdir -p "$TGT_FOLDER"
else
    print_error "Folder already exist,aborting..."
    exit 1
fi

# region: create folder structure
echo "Creating folder structure in main directory"
mkdir -p -v \
    "$API_FOLDER" \
    "$DOCS_FOLDER" \
    "$INTERNAL_FOLDER" \
    "$DATABASES_FOLDER" \
    "$V1_HANDLERS_FOLDER" \
    "$MIDDLEWARE_FOLDER" \
    "$REPOSITORIES_FOLDER" \
    "$SERVICES_FOLDER" \
    "$TYPES_FOLDER" \
    "$UTILS_FOLDER" \
    "$TESTS_FOLDER"

# region: env files
touch "$TGT_FOLDER/.env"
cat <<EOF > "$TGT_FOLDER/.env"
ENVIRONMENT=Development
DB_CONNECTION=postgres://username:password@localhost:5432/database
DB_MAX_CONN=25
DB_MIN_CONN=5
DB_MAX_CONN_TIME=14
DB_MIN_CONN_TIME=7
EOF

# region: init golang
cd "$TGT_FOLDER"
go mod init "$MODULE_NAME"

# region: types
touch "$TYPES_FOLDER/handlerResults.go"
cat <<EOF > "$TYPES_FOLDER/handlerResults.go"
package types

type HandlerResults[T any] struct {
	StatusCode int
	ErrorMsg   *string
	Data       *T
}

func NewHandlerResult[T any](status int, errorMsg *string, data *T) *HandlerResults[T] {
	return &HandlerResults[T]{
		StatusCode: status,
		ErrorMsg:   errorMsg,
		Data:       data,
	}
}

func (op *HandlerResults[T]) IsHTTPSuccessCode() bool {
	irs := []Range[int]{
		{Min: 100, Max: 103},
		{Min: 200, Max: 299},
	}

	for _, ir := range irs {
		if ir.IsIncluded(op.StatusCode) {
			return true
		}
	}

	return false
}
EOF

touch "$TYPES_FOLDER/utils.go"
cat <<EOF > "$TYPES_FOLDER/utils.go"
package types

type Range[T int | float32 | float64] struct {
	Min T
	Max T
}

func (r *Range[T]) IsIncluded(value T) bool {
	return value >= r.Min && value <= r.Max
}

// used for pointers on simple types like string, int
// used to avoid declaring a variable each time when simple type can be nil
func Ptr[T any](value T) *T {
	return &value
}
EOF

# region: utils
touch "$UTILS_FOLDER/encoders.go"
cat <<EOF > "$UTILS_FOLDER/encoders.go"
package utils

import (
	"${MODULE_NAME}/internal/types"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
)

type JsonCustomEncoder[T any] struct {
	json.Encoder
	RequestId   string
	ContentType string
	http.ResponseWriter
}

func NewJsonCustomEncoder[T any](w http.ResponseWriter, requestId string, contentType string) *JsonCustomEncoder[T] {
	return &JsonCustomEncoder[T]{
		ResponseWriter: w,
		RequestId:      requestId,
		ContentType:    contentType,
		Encoder:        *json.NewEncoder(w),
	}
}

func (j *JsonCustomEncoder[T]) Encode(results types.HandlerResults[T]) {
	j.ResponseWriter.Header().Set("Content-Type", j.ContentType)
	if results.IsHTTPSuccessCode() {
		if err := j.Encoder.Encode(results); err != nil {
			log.Printf("%s,%s,%s", Now(), j.RequestId, err)
			http.Error(j.ResponseWriter, "Error encoding response - 500", http.StatusInternalServerError)
		}
		return
	}
	log.Printf("%s,%s,%s", Now(), j.RequestId, *results.ErrorMsg)
	http.Error(j.ResponseWriter, "Error processing request - "+strconv.Itoa(results.StatusCode), results.StatusCode)
}
EOF

touch "$UTILS_FOLDER/env.go"
cat <<EOF > "$UTILS_FOLDER/env.go"
package utils

import (
	"bufio"
	"os"
	"strings"
)

// strict, failing to load env variables results in panic
func LoadEnvVariables() {
	// TODO: implement tiering for test and production
	filename := ".env"

	file, err := os.OpenFile(filename, os.O_RDONLY, 0440)
	if err != nil {
		panic(err)
	}

	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())       // get trimmed line
		if line == "" || strings.HasPrefix(line, "#") { // avoid parsing empty lines or comments
			continue
		}

		parts := strings.SplitN(line, "=", 2) // split string on = and gather kv pair
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])

		os.Setenv(key, value)
	}

	if err := scanner.Err(); err != nil {
		panic(err)
	}
}
EOF

touch "$UTILS_FOLDER/numbers.go"
cat <<EOF > "$UTILS_FOLDER/numbers.go"
package utils

import "strconv"

func MustParseInt32(value string) int32 {
	casted, err := strconv.ParseInt(value, 10, 32)
	if err != nil {
		panic(err)
	}
	return int32(casted)
}
EOF

touch "$UTILS_FOLDER/time.go"
cat <<EOF > "$UTILS_FOLDER/time.go"
package utils

import (
	"strconv"
	"time"
)

func Now() string {
	return time.Now().UTC().Format(time.RFC3339)
}

func MustParseDurationMinutes(value string) time.Duration {
	casted, err := strconv.Atoi(value)
	if err != nil {
		panic(err)
	}
	return time.Duration(casted) * time.Minute
}
EOF

# region: middleware
touch "$MIDDLEWARE_FOLDER/logger.go"
cat <<EOF > "$MIDDLEWARE_FOLDER/logger.go"
package middleware

import (
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type WrappedResponseWriter struct {
	http.ResponseWriter
	statusCode int
}

func NewWrappedResponseWriter(w http.ResponseWriter) *WrappedResponseWriter {
	return &WrappedResponseWriter{
		ResponseWriter: w,
		statusCode:     http.StatusOK,
	}
}

func (crw *WrappedResponseWriter) WriteHeader(code int) {
	crw.statusCode = code
	crw.ResponseWriter.WriteHeader(code)
}

func Logger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		file, err := createLogFile()
		if err != nil {
			log.Printf("Error creating or opening log file: %v", err)
			next.ServeHTTP(w, r)
			return
		}

		// remove default timestamp to respect csv format
		log.SetFlags(0)
		log.SetOutput(file)

		// get request id from context
		requestId := r.Context().Value(RequestIdKey).(string)

		defer closeLogFile(file)

		// wrapped writer to get response status code on exit
		writer := NewWrappedResponseWriter(w)

		// defer function used to log response status after request is served
		defer logResponseStatus(requestId, writer)

		log.Printf("%s,%s,%s,%s,%s", now(), requestId, r.RemoteAddr, r.Method, r.URL)
		next.ServeHTTP(writer, r)
	})
}

func createLogFile() (*os.File, error) {
	// Create a filename for today's logging
	filename := strings.Join([]string{today() + "_api_requests", "csv"}, ".")

	// Define the relative path to where to store the logs
	logDir := filepath.Join("logs")

	// Ensure the logs directory exists; if not, create it
	err := os.MkdirAll(logDir, os.ModePerm)
	if err != nil {
		return nil, err
	}

	// Create file
	logPath := filepath.Join(logDir, filename)
	file, err := os.OpenFile(logPath, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
	if err != nil {
		return nil, err
	}

	return file, nil
}

func closeLogFile(file *os.File) {
	err := file.Close()
	if err != nil {
		log.Printf("Error closing log file %s: %v", file.Name(), err)
	}
}

func logResponseStatus(id string, w *WrappedResponseWriter) {
	log.Printf("%s,%s,%d", now(), id, w.statusCode)
}

func today() string {
	return time.Now().UTC().Format("2006-01-02")
}

func now() string {
	return time.Now().UTC().Format(time.RFC3339)
}
EOF

touch "$MIDDLEWARE_FOLDER/requestIdentifier.go"
cat <<EOF > "$MIDDLEWARE_FOLDER/requestIdentifier.go"
package middleware

import (
	"context"
	"net/http"

	"github.com/google/uuid"
)

func RequestIdentifier(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// start to identify the request with an id and update the header so to keep track of sessions
		requestId := uuid.New().String()
		w.Header().Add("X-Request-ID", requestId) // consumed by client for session tracker

		// enrich the context with the request id
		ctx := context.WithValue(r.Context(), RequestIdKey, requestId)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func GetRequestId(r *http.Request) string {
	return r.Context().Value(RequestIdKey).(string)
}
EOF

touch "$MIDDLEWARE_FOLDER/timeout.go"
cat <<EOF > "$MIDDLEWARE_FOLDER/timeout.go"
package middleware

import (
	"${MODULE_NAME}/internal/utils"
	"context"
	"log"
	"net/http"
	"time"
)

func DefineTimeout(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// defining context timeout
		var timeout time.Duration

		switch r.Method {
		case http.MethodGet:
			timeout = 5 * time.Second
		case http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete:
			timeout = 10 * time.Second
		default:
			timeout = 5 * time.Second
		}

		timedCtx, cancel := context.WithTimeout(r.Context(), timeout)
		defer cancel()

		// override existing request context with timed context
		r = r.WithContext(timedCtx)

		// reacting to context timeout by sending 503 back to client
		done := make(chan bool)

		go func() {
			next.ServeHTTP(w, r)
			done <- true
		}()

		for {
			select {
			case <-time.After(timeout):
				log.Printf("%s,%s,server timeout", utils.Now(), GetRequestId(r))
				http.Error(w, "The server has timed out", http.StatusServiceUnavailable)
				return
			case <-done:
				return
			}
		}
	})
}
EOF

touch "$MIDDLEWARE_FOLDER/types.go"
cat <<EOF > "$MIDDLEWARE_FOLDER/types.go"
package middleware

// used to get the request identifier from the context
type ContextKey string

const RequestIdKey = ContextKey("requestId")

EOF

# region: databases
touch "$DATABASES_FOLDER/$PJT_NAME.go"
cat <<EOF > "$DATABASES_FOLDER/$PJT_NAME.go"
package databases

import (
	"context"
	"log"
	"os"
	"sync"

	"${MODULE_NAME}/internal/utils"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ${PJT_NAME}Database struct {
	Pool *pgxpool.Pool
}

var (
	db                       *${PJT_NAME}Database
	once                     sync.Once
	Now                      = utils.Now
	MustParseInt32           = utils.MustParseInt32
	MustParseDurationMinutes = utils.MustParseDurationMinutes
)

func Init${PJT_NAME}Database() *${PJT_NAME}Database {
	once.Do(func() {
		poolConfig, err := pgxpool.ParseConfig(os.Getenv("DB_CONNECTION"))
		if err != nil {
			log.Fatalf("%s,Unable to parse connection config: %v", Now(), err)
		}

		poolConfig.MaxConns = MustParseInt32(os.Getenv("DB_MAX_CONN"))                       // Maximum number of connections in the pool
		poolConfig.MinConns = MustParseInt32(os.Getenv("DB_MIN_CONN"))                       // Minimum number of connections to maintain
		poolConfig.MaxConnLifetime = MustParseDurationMinutes(os.Getenv("DB_MAX_CONN_TIME")) // Maximum lifetime of a connection
		poolConfig.MaxConnIdleTime = MustParseDurationMinutes(os.Getenv("DB_MIN_CONN_TIME")) // Maximum idle time for connections

		pool, err := pgxpool.NewWithConfig(context.Background(), poolConfig)
		if err != nil {
			log.Fatalf("%s,Unable to create connection pool: %v", Now(), err)
		}
		db = &${PJT_NAME}Database{
			Pool: pool,
		}
	})

	return db
}
EOF

# region: services
touch "$SERVICES_FOLDER/utils.go"
cat <<EOF > "$SERVICES_FOLDER/utils.go"
package services

import (
	"${MODULE_NAME}/internal/types"
)

type (
	HandlerResults[T any]   = types.HandlerResults[T]
)

var (
	StrPtr = types.Ptr[string]
)

func ErrorResult[T any](status int, err error) HandlerResults[T] {
	return HandlerResults[T]{
		StatusCode: status,
		ErrorMsg:   StrPtr(err.Error()),
		Data:       nil,
	}
}

func SuccessResult[T any](status int, data T) HandlerResults[T] {
	return HandlerResults[T]{
		StatusCode: status,
		ErrorMsg:   nil,
		Data:       &data,
	}
}
EOF

# region: handlers
touch "$V1_HANDLERS_FOLDER/utils.go"
cat <<EOF > "$V1_HANDLERS_FOLDER/utils.go"
package v1

import (
	"${MODULE_NAME}/internal/middleware"
)

var (
	GetRequestId = middleware.GetRequestId
)
EOF

touch "$V1_HANDLERS_FOLDER/health.go"
cat <<EOF > "$V1_HANDLERS_FOLDER/health.go"
package v1

import (
	"${MODULE_NAME}/internal/types"
    "${MODULE_NAME}/internal/utils"
	"net/http"
	"github.com/gorilla/mux"
)

var (
	Ptr     = types.Ptr[string]
	Results = types.NewHandlerResult[string]
)

type HealthHandler struct{}

func NewHealthHandler() *HealthHandler {
	return &HealthHandler{}
}

func (h *HealthHandler) InjectDependencies() {}

func (h *HealthHandler) RegisterRoutes(router *mux.Router) {
	router.HandleFunc("/health", h.assesApiHealth).Methods(http.MethodGet)
}

func (h *HealthHandler) assesApiHealth(w http.ResponseWriter, r *http.Request) {
	results := Results(http.StatusOK, nil, Ptr("API is healty."))
	encoder := utils.NewJsonCustomEncoder[string](w, GetRequestId(r), "application/json")
	encoder.Encode(*results)
}
EOF

# region: api
touch "$API_FOLDER/main.go"
cat <<EOF > "$API_FOLDER/main.go"
package main

import (
	"${MODULE_NAME}/internal/databases"
	v1 "${MODULE_NAME}/internal/handlers/v1"
	"${MODULE_NAME}/internal/middleware"
	"${MODULE_NAME}/internal/utils"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
)

var (
	requestIdentifier = middleware.RequestIdentifier
	logger            = middleware.Logger
	timedContext      = middleware.DefineTimeout
	Init${PJT_NAME}Database = databases.Init${PJT_NAME}Database
)

// Define handler interface
type RouteHandler interface {
	InjectDependencies()
	RegisterRoutes(router *mux.Router)
}

func main() {
	// Load .env variable
	utils.LoadEnvVariables()

	// Initialize the router
	router := mux.NewRouter()

	// Add middleware
	router.Use(requestIdentifier)
	router.Use(logger)

	if os.Getenv("ENVIRONMENT") != "Development" {
		router.Use(timedContext) // timed context only for above development tiers
	}

	// Initialise database
	db := Init${PJT_NAME}Database()

	// Register v1Handlers
	v1Handlers := registerV1Handlers()

	// Register routes
	registerV1Routes(router, v1Handlers)

	// Configure CORS
	// create wrapper if needed, check monitor-it for reference

	// configuring server
	srv := &http.Server{
		Addr:         ":8080",
		Handler:      router,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	// Launch api
	log.Println("Starting API...")
	log.Fatal(srv.ListenAndServe())

	// Closing pool connection
	defer db.Pool.Close()
}

func registerV1Handlers() []RouteHandler {
	return []RouteHandler{
		v1.NewHealthHandler(),
	}
}

func registerV1Routes(router *mux.Router, handlers []RouteHandler) {
	// Create a sub-router with a version prefix
	// At the moment containing only v1 implementation, update the method when versioning
	v1Router := router.PathPrefix("/api/v1").Subrouter()

	// Register handlers' routes
	for _, handler := range handlers {
		handler.InjectDependencies()
		handler.RegisterRoutes(v1Router)
	}
}
EOF

# region: formatting
cd "$TGT_FOLDER"
go fmt ./...

# region: tidy modules
go mod tidy
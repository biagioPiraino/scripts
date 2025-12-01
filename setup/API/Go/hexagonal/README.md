### Folder Structure Target

```
app/
├── cmd/
│   └── api/
│       ├── main.go           # Entry point: Loads config, calls app.Run()
│       └── app.go            # Wiring: Initialises Router, DB, creates instances
│
├── internal/
│   ├── core/                 # THE HEXAGON (Pure Business Logic)
│   │   ├── domain/           # Enterprise Entities (Structs)
│   │   │   ├── domain.go
│   │   ├── ports/                  # Interfaces (Input/Output definitions)
│   │   │   ├── domain_ports.go     # Defines DomainService and DomainRepository interfaces
│   │   │   ├── cache_ports.go      # Defines cache ports
│   │   │   └── logger.go           # Defines Logger interface
│   │   |── services/               # Use Cases / Application Logic / Actual implementaion
│   │   |    └── domain_service.go
│   │   └── utils/                  # Utils for core logic
│   │       └── utils.go
│   │
│   └── adapters/               # THE ADAPTERS (Implementations)
│      ├── handlers/            # Driving Adapters (Trigger the logic)
│      │   └── http/            # REST API Handlers
│      │       ├── middleware/  # HTTP specific middlewares (Auth, CORS)
│      │       ├── router.go    # Route definitions
│      │       └── domain_handler.go
│      │
│      |── repository/          # Driven Adapters (Triggered by logic)
│      |    └── postgres/       # Concrete Implementation (grouped by Tech)
│      |        ├── db.go       # DB Connection logic
│      |        └── domain.go   # Domain specific implementation
│      │
│      |── cache/                     # Driven Adapters (Triggered by logic)
│      |    └── redis/                # Concrete Implementation (grouped by Tech)
│      |        ├── cache.go          # Cache Connection logic
│      |        └── domain_cache.go   # Domain specific implementation
│      |        
│      └── platform/            # Infrastructure / Cross-cutting
│           └── logger/         # Centralized Logger implementation (Zap/Slog)
│
├── go.mod
└── go.sum

```
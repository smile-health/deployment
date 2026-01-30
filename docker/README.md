# Docker Compose Setup

This directory contains the Docker Compose configuration for Smile Health.

## Structure

```
docker/
├── compose/              # Docker Compose files
│   ├── docker-compose.yml
│   ├── compose-services.yml
│   ├── compose-tools.yml
│   ├── compose-data.yml
│   └── compose-frontend.yml
├── env/                  # Environment files
│   ├── .env.example
│   ├── auth-service.env.example
│   ├── core.env.example
│   ├── main.env.example
│   ├── sync-service.env.example
│   ├── warehouse-service.env.example
│   ├── notification.env.example
│   └── frontend-web.env.example
├── volumes/              # Data volumes (gitignored)
└── backups/              # Database backups (gitignored)
```

## Usage

From the `deployment/` directory, use the Makefile:

```bash
# Start all services
make start

# Stop all services
make stop

# View logs
make logs

# Show all commands
make help
```

See `../DOCKER_SETUP.md` for complete documentation.

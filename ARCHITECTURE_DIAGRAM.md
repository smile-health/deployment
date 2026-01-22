# Smile Health Architecture Diagram

This document provides a comprehensive architectural overview of the Smile Health application deployed via Helm charts on Kubernetes.

## Overview

The Smile Health platform is a microservices-based healthcare management system consisting of multiple backend services, frontend applications, and supporting infrastructure components.

## High-Level Architecture

```mermaid
graph TB
    subgraph "External Users"
        U1[Healthcare Providers]
        U2[Patients]
        U3[Administrators]
        U4[Warehouse Staff]
    end

    subgraph "Kubernetes Cluster"
        subgraph "Ingress Layer"
            IN[Ingress Controller<br/>nginx/cert-manager]
        end

        subgraph "Frontend Services"
            WEB[Web Application<br/>React/Next.js]
            WMS[WMS Application<br/>React]
            SB[Storybook<br/>Documentation]
        end

        subgraph "Backend Services"
            CORE[Core Service<br/>Node.js]
            IMM[Immunization Service<br/>Node.js]
            MED[Medicine Service<br/>Node.js]
            AUTH[Auth Service<br/>Node.js]
            MAIN[Main Service<br/>Node.js]
            SYNC[Sync Service<br/>Node.js]
            WHS[Warehouse Service<br/>Node.js]
            API1[Main API Gateway<br/>Node.js]
            API2[Warehouse API Gateway<br/>Node.js]
            NOTIF[Notification Service<br/>Node.js]
        end

        subgraph "Authentication & Authorization"
            KC[Keycloak<br/>Identity & Access Management]
        end

        subgraph "Message Queue"
            MQ[RabbitMQ<br/>Message Broker]
        end

        subgraph "Data Layer"
            DB1[(MySQL<br/>Primary Database)]
            DB2[(MySQL<br/>Keycloak Database)]
            RD[(Redis<br/>Cache & Session)]
        end

        subgraph "Storage"
            PV1[Persistent Volumes<br/>Application Data]
            PV2[Persistent Volumes<br/>Database Files]
        end
    end

    U1 --> IN
    U2 --> IN
    U3 --> IN
    U4 --> IN

    IN --> WEB
    IN --> WMS
    IN --> SB
    IN --> KC

    WEB --> API1
    WMS --> API2
    SB --> API1

    API1 --> CORE
    API1 --> IMM
    API1 --> MED
    API1 --> AUTH
    API1 --> MAIN
    API1 --> SYNC
    API1 --> NOTIF

    API2 --> WHS
    API2 --> AUTH

    CORE --> DB1
    IMM --> DB1
    MED --> DB1
    AUTH --> DB1
    MAIN --> DB1
    SYNC --> DB1
    WHS --> DB1
    API1 --> RD
    API2 --> RD

    KC --> DB2

    CORE --> MQ
    IMM --> MQ
    MED --> MQ
    AUTH --> MQ
    MAIN --> MQ
    SYNC --> MQ
    WHS --> MQ
    NOTIF --> MQ

    DB1 --> PV2
    DB2 --> PV2
    RD --> PV1
```

## Service Communication Flow

```mermaid
sequenceDiagram
    participant User as End User
    participant Ingress as Ingress Controller
    participant Frontend as Frontend App
    participant API as API Gateway
    participant Auth as Auth Service
    participant Service as Business Service
    participant DB as MySQL
    participant Cache as Redis
    participant MQ as RabbitMQ
    participant Keycloak as Keycloak

    User->>Ingress: HTTPS Request
    Ingress->>Frontend: Route to Frontend
    Frontend->>API: API Request
    
    alt Authentication Required
        API->>Keycloak: Validate Token
        Keycloak->>API: Token Valid
    end

    API->>Auth: Check Permissions
    Auth->>API: Permission Granted
    
    API->>Service: Business Logic Request
    Service->>Cache: Check Cache
    alt Cache Hit
        Cache->>Service: Cached Data
    else Cache Miss
        Service->>DB: Query Database
        DB->>Service: Query Results
        Service->>Cache: Update Cache
    end
    
    Service->>MQ: Publish Event (if needed)
    Service->>API: Response
    API->>Frontend: JSON Response
    Frontend->>User: Render UI
```

## Infrastructure Components

### 1. Ingress Layer
- **NGINX Ingress Controller**: Routes external traffic to internal services
- **Cert-Manager**: Manages TLS certificates automatically
- **Rate Limiting**: Protects against DDoS attacks
- **Path-based Routing**: Routes to different services based on URL path

### 2. Frontend Services
- **Web Application**: Main patient and provider portal
- **WMS Application**: Warehouse management system
- **Storybook**: Component documentation and testing

### 3. Backend Services
- **Core Service**: Central business logic and user management
- **Immunization Service**: Vaccine tracking and scheduling
- **Medicine Service**: Pharmaceutical inventory management
- **Auth Service**: Authentication and authorization
- **Main Service**: Primary application logic
- **Sync Service**: Data synchronization between systems
- **Warehouse Service**: Inventory and logistics management
- **API Gateways**: Request routing and aggregation
- **Notification Service**: Email, SMS, and push notifications

### 4. Authentication Layer
- **Keycloak**: 
  - Single Sign-On (SSO)
  - OAuth 2.0 / OpenID Connect
  - User federation
  - Role-based access control (RBAC)

### 5. Message Queue
- **RabbitMQ**:
  - Asynchronous communication
  - Event-driven architecture
  - Message durability
  - Load balancing

### 6. Data Layer
- **MySQL**: Primary relational database
- **Redis**: Caching, session storage, and pub/sub
- **Persistent Volumes**: Durable storage for databases

## Deployment Architecture

### Service Discovery

All services communicate using Kubernetes internal DNS:
- Format: `{service-name}.{namespace}.svc.cluster.local`
- Example: `smile-health-core.smile-health.svc.cluster.local`

### Load Balancing

- **Internal Load Balancing**: Kubernetes Services distribute traffic within the cluster
- **External Load Balancing**: Ingress controller manages external traffic distribution
- **Database Load Balancing**: MySQL master-slave configuration for read scaling

## Security Architecture

```mermaid
graph TB
    subgraph "Security Layers"
        subgraph "Network Security"
            FW[Firewall Rules]
            NP[Network Policies]
            VPC[VPC/Private Network]
        end
        
        subgraph "Application Security"
            RBAC[Role-Based Access Control]
            JWT[JWT Tokens]
            OAuth[OAuth 2.0]
        end
        
        subgraph "Data Security"
            ENC[Encryption at Rest]
            TLS[TLS in Transit]
            HASH[Hashed Passwords]
        end
        
        subgraph "Container Security"
            SC[Security Contexts]
            NS[Non-root User]
            CAP[Dropped Capabilities]
        end
    end

    VPC --> NP
    NP --> FW
    OAuth --> JWT
    JWT --> RBAC
    TLS --> ENC
    ENC --> HASH
    SC --> NS
    NS --> CAP
```

## Monitoring and Observability

### Health Checks
- **Liveness Probes**: Check if service is running
- **Readiness Probes**: Check if service is ready for traffic
- **Startup Probes**: Check if service has started

### Metrics Collection
- **Application Metrics**: Custom business metrics
- **Infrastructure Metrics**: CPU, memory, network, disk
- **Kubernetes Metrics**: Pod, service, and cluster metrics

### Logging Architecture
- **Application Logs**: Structured JSON logs
- **Access Logs**: HTTP request/response logs
- **System Logs**: Kubernetes events and audit logs

## Scalability Patterns

### Horizontal Scaling
- **Stateless Services**: Can be scaled horizontally
- **API Gateways**: Load balance across multiple instances
- **Frontend Applications**: Multiple replicas for availability

### Vertical Scaling
- **Database**: Increase resources for MySQL and Redis
- **Message Queue**: Scale RabbitMQ based on message throughput

### Auto-scaling
- **HPA (Horizontal Pod Autoscaler)**: Scale based on CPU/memory
- **VPA (Vertical Pod Autoscaler)**: Adjust resource requests
- **Cluster Autoscaler**: Add/remove nodes based on demand

## Disaster Recovery

### Backup Strategy
- **Database Backups**: Regular MySQL dumps
- **Volume Snapshots**: Persistent volume backups
- **Configuration Backup**: Git-based configuration storage

### High Availability
- **Multi-replica Deployment**: Services run across multiple nodes
- **Database Replication**: Master-slave MySQL configuration
- **Failover Mechanisms**: Automatic pod restart and rescheduling

### Recovery Procedures
- **Rollback Capability**: Helm rollback to previous versions
- **Blue-Green Deployment**: Zero-downtime updates
- **Canary Releases**: Gradual rollout of new versions

## Development vs Production

### Development Environment
- Single replica for most services
- Minimal resource allocation
- Local database instances
- Debug tools enabled

### Production Environment
- Multiple replicas for high availability
- Resource limits and requests configured
- External managed databases
- Monitoring and alerting enabled
- Network policies enforced
- TLS certificates mandatory

# Microservices E-Commerce Platform - Architecture Plan

## Project Overview

A polyglot microservices-based online shopping platform built with Java (Spring Boot) and .NET (ASP.NET Core), demonstrating modern cloud-native architecture patterns using AWS services.

**Primary Goal:** Learning microservices architecture, event-driven patterns, and polyglot persistence.

**Budget:** AWS Free Tier

---

## Technology Stack

### Languages & Frameworks
- **Java 25** with Spring Boot 3.4.0
- **.NET 8.0** with ASP.NET Core
- **Build Tools:** Gradle (Kotlin DSL) for Java, .NET CLI for C#

### Databases (Polyglot Persistence)
- **PostgreSQL** (Aurora DSQL) - Transactional data
- **MongoDB** (Atlas Free Tier) - Document storage
- **Redis** (Redis Labs Cloud Free Tier) - Caching

### Communication
- **Synchronous:** REST APIs (inter-service queries)
- **Asynchronous:** AWS SQS + SNS (event-driven)
- **Protocol Buffers (Optional):** Type-safe cross-language communication

### AWS Services (Free Tier)
- **Aurora DSQL** - 100K DPUs/month, 1GB storage
- **SQS** - 1M requests/month (forever free)
- **SNS** - 1K emails/month
- **Cognito** - 50K MAUs (recommended for IAM)
- **API Gateway** - 1M requests/month
- **ECS Fargate** - Limited free compute hours

---

## Microservices Architecture

### Service Breakdown

```
┌─────────────────────────────────────────────────────────┐
│                  API Gateway (AWS)                      │
│           Single Entry Point for All Clients            │
└────────────────────────┬────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┬────────────────┐
         │               │               │                │
    ┌────▼────┐     ┌───▼────┐     ┌───▼────┐      ┌────▼────┐
    │ Product │     │  Cart  │     │ Order  │      │   IAM   │
    │Catalog  │     │Service │     │Service │      │(Cognito)│
    │(Java)   │     │(Java)  │     │(.NET)  │      │   or    │
    │ MongoDB │     │ Redis  │     │Postgres│      │ Custom  │
    └─────────┘     └────────┘     └────┬───┘      └─────────┘
                                         │
                                         │ Publishes Events
                                         ▼
                                 ┌───────────────┐
                                 │   SNS Topic   │
                                 │ "OrderEvents" │
                                 └───────┬───────┘
                                         │
                         ┌───────────────┼────────────────┬────────────┐
                         │               │                │            │
                    ┌────▼────┐    ┌────▼─────┐    ┌────▼────┐  ┌───▼────┐
                    │Inventory│    │ Payment  │    │Notification │Cart    │
                    │Service  │    │ Service  │    │  Service │  │Cleanup │
                    │(Java)   │    │ (.NET)   │    │  (.NET)  │  │        │
                    │Postgres │    │ Postgres │    │ MongoDB  │  │        │
                    └─────────┘    └──────────┘    └──────────┘  └────────┘
```

---

## Service Details

### 1. Product Catalog Service (Java/Spring Boot)

**Purpose:** Source of truth for product information

**Technology:**
- Java 25
- Spring Boot 3.4.0
- Spring Data MongoDB

**Database:** MongoDB Atlas (Free Tier: 512MB)

**Responsibilities:**
- Manage product information (name, description, SKU, price, category)
- Product search and filtering
- Product images and attributes
- Static product data (not real-time stock)

**API Endpoints:**
```
GET    /api/products              - List all products
GET    /api/products/{id}         - Get product by ID
GET    /api/products/search       - Search products
POST   /api/products              - Create product (admin)
PUT    /api/products/{id}         - Update product (admin)
DELETE /api/products/{id}         - Delete product (admin)
GET    /api/products/category/{cat} - Products by category
```

**Communication:**
- **Exposes:** REST API (synchronous)
- **Consumes:** None
- **Events:** None

**Why MongoDB?**
- Flexible schema for varying product attributes
- Fast reads for catalog browsing
- Easy to add new product fields without migrations

**Port:** 8081 (HTTP), 9091 (gRPC - optional)

---

### 2. Inventory Management Service (Java/Spring Boot)

**Purpose:** Real-time stock tracking and management

**Technology:**
- Java 25
- Spring Boot 3.4.0
- Spring Data JPA

**Database:** Aurora DSQL PostgreSQL

**Responsibilities:**
- Track real-time stock levels
- Reserve inventory during checkout
- Update stock after order completion
- Handle stock replenishment
- Prevent overselling

**API Endpoints:**
```
GET    /api/inventory/{productId}       - Get stock level
POST   /api/inventory/check             - Check stock availability
PUT    /api/inventory/{productId}       - Update stock (internal)
POST   /api/inventory/reserve           - Reserve stock (internal)
POST   /api/inventory/release           - Release reserved stock (internal)
```

**Communication:**
- **Exposes:** REST API (synchronous for stock checks)
- **Consumes:** Listens to OrderConfirmed events (SQS)
- **Events:** Publishes InventoryUpdated, StockLow events

**Why PostgreSQL?**
- ACID compliance critical for stock management
- Prevents race conditions with transactions
- Reliable for inventory counts

**Event Subscriptions:**
- `OrderConfirmed` → Reduce stock
- `OrderCancelled` → Restore stock
- `PaymentFailed` → Release reserved stock

**Port:** 8082

---

### 3. Shopping Cart Service (Java/Spring Boot)

**Purpose:** Manage user shopping carts (session-based)

**Technology:**
- Java 25
- Spring Boot 3.4.0
- Spring Data Redis

**Database:** Redis Labs Cloud (Free Tier: 30MB)

**Responsibilities:**
- Add/remove items from cart
- Update quantities
- Cart expiration (auto-clear after X hours)
- Merge guest cart with user cart on login

**API Endpoints:**
```
GET    /api/cart                  - Get current user's cart
POST   /api/cart/items            - Add item to cart
PUT    /api/cart/items/{itemId}   - Update quantity
DELETE /api/cart/items/{itemId}   - Remove item
DELETE /api/cart                  - Clear cart
```

**Communication:**
- **Exposes:** REST API (synchronous)
- **Consumes:** Calls Product Service to verify products exist
- **Events:** Listens to OrderConfirmed to clear cart

**Why Redis?**
- In-memory = extremely fast
- Perfect for temporary, session-based data
- TTL support for auto-expiration
- High-traffic operations (cart updates are frequent)

**Data Model:**
```json
{
  "userId": "user-123",
  "items": [
    {
      "productId": "prod-456",
      "quantity": 2,
      "addedAt": "2024-01-15T10:30:00Z"
    }
  ],
  "createdAt": "2024-01-15T10:00:00Z",
  "expiresAt": "2024-01-15T22:00:00Z"
}
```

**Port:** 8083

**Recommendation:** Consider merging this into Order Service if cart logic remains simple. Separate service makes sense if you plan to add:
- Wishlist functionality
- Shared carts
- Save for later
- Cart analytics

---

### 4. Order Processing Service (.NET/ASP.NET Core)

**Purpose:** Orchestrate the checkout and order lifecycle

**Technology:**
- .NET 8.0
- ASP.NET Core
- Entity Framework Core

**Database:** Aurora DSQL PostgreSQL

**Responsibilities:**
- Handle checkout process
- Coordinate with other services (cart, inventory, payment)
- Manage order lifecycle (pending → confirmed → shipped → delivered)
- Track order history
- Handle order cancellations

**API Endpoints:**
```
POST   /api/orders/checkout       - Create order from cart
GET    /api/orders                - List user's orders
GET    /api/orders/{id}           - Get order details
PUT    /api/orders/{id}/cancel    - Cancel order
PUT    /api/orders/{id}/status    - Update order status (internal)
GET    /api/orders/{id}/tracking  - Get tracking info
```

**Communication:**
- **Exposes:** REST API (synchronous)
- **Consumes:** 
  - Cart Service (get cart items)
  - Product Service (get product details, pricing)
  - Inventory Service (check/reserve stock)
  - Payment Service (process payment)
- **Events:** Publishes OrderCreated, OrderConfirmed, OrderCancelled, OrderShipped

**Order States:**
```
PENDING_PAYMENT → CONFIRMED → PROCESSING → SHIPPED → DELIVERED
                     ↓
                 CANCELLED
                     ↓
                 REFUNDED
```

**Why .NET?**
- Excellent for transactional business logic
- Entity Framework handles complex order relationships
- Great for orchestration patterns

**Why PostgreSQL?**
- Critical transactional data
- Complex relationships (orders → order items → products)
- ACID compliance required

**Port:** 5000

---

### 5. Payment Service (.NET/ASP.NET Core)

**Purpose:** Handle payment processing and transaction records

**Technology:**
- .NET 8.0
- ASP.NET Core
- Entity Framework Core

**Database:** Aurora DSQL PostgreSQL

**Responsibilities:**
- Process payments (mock Stripe/PayPal for now)
- Store payment transactions
- Handle payment status (pending, completed, failed)
- Process refunds
- Payment method validation
- Idempotency (prevent duplicate charges)

**API Endpoints:**
```
POST   /api/payments/process      - Process payment
GET    /api/payments/{id}         - Get payment details
GET    /api/payments/order/{orderId} - Get payment by order
POST   /api/payments/{id}/refund  - Refund payment
POST   /api/payments/validate     - Validate payment method
```

**Communication:**
- **Exposes:** REST API or gRPC (synchronous)
- **Consumes:** Order Service calls this during checkout
- **Events:** Publishes PaymentCompleted, PaymentFailed, PaymentRefunded

**Payment Flow:**
```
1. Receive payment request from Order Service
2. Validate payment details
3. Call mock payment gateway (Stripe/PayPal simulation)
4. Store transaction record
5. Return success/failure
6. Publish event for async processing
```

**Why .NET?**
- Excellent for financial transaction handling
- Strong typing for monetary calculations
- Easy integration with payment SDKs

**Why PostgreSQL?**
- Financial data requires ACID compliance
- Audit trail critical
- Transaction history queries

**Data Model:**
```csharp
public class Payment {
    public string Id { get; set; }
    public string OrderId { get; set; }
    public string UserId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; }
    public PaymentMethod Method { get; set; } // CreditCard, PayPal, etc.
    public PaymentStatus Status { get; set; } // Pending, Completed, Failed
    public string TransactionId { get; set; } // External provider ID
    public string Provider { get; set; } // Stripe, PayPal
    public string FailureReason { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
}
```

**Port:** 5001

**Recommendation:** Start with mock implementation, later integrate real payment providers (Stripe API).

---

### 6. Notification Service (.NET/ASP.NET Core)

**Purpose:** Handle all notifications and audit logging

**Technology:**
- .NET 8.0
- ASP.NET Core
- MongoDB Driver for .NET

**Database:** MongoDB Atlas (Free Tier: 512MB)

**Responsibilities:**
- Send email notifications (order confirmation, shipping updates)
- SMS notifications (optional)
- Push notifications (optional)
- Audit logging (immutable event log)
- Notification templates
- Retry failed notifications

**API Endpoints:**
```
POST   /api/notifications/send    - Send notification (internal)
GET    /api/notifications         - List notifications
GET    /api/notifications/audit   - Audit log (admin)
```

**Communication:**
- **Exposes:** REST API (mostly internal)
- **Consumes:** None
- **Events:** Listens to OrderConfirmed, OrderShipped, PaymentCompleted, PaymentFailed

**Why .NET?**
- Great for background processing
- Easy integration with email/SMS services
- Async/await patterns perfect for notifications

**Why MongoDB?**
- Immutable audit logs (append-only)
- No schema changes needed
- Fast writes for high-volume logging

**Event Subscriptions:**
- `OrderConfirmed` → Send order confirmation email
- `OrderShipped` → Send shipping notification
- `PaymentFailed` → Send payment failure alert
- `PaymentCompleted` → Send payment receipt

**Port:** 5002

---

### 7. Identity & Access Management Service

**Purpose:** User authentication and authorization

**Option A: Build Custom IAM (Java/Spring Boot)**

**Technology:**
- Java 25
- Spring Boot 3.4.0
- Spring Security
- Spring Authorization Server

**Database:** Aurora DSQL PostgreSQL

**Responsibilities:**
- User registration
- Login (username/password)
- JWT generation and validation
- Password hashing (BCrypt)
- Role-based access control (RBAC)
- OAuth 2.0 flows

**API Endpoints:**
```
POST   /api/auth/register         - User registration
POST   /api/auth/login            - User login (returns JWT)
POST   /api/auth/refresh          - Refresh JWT token
POST   /api/auth/logout           - Logout
GET    /api/auth/validate         - Validate token
POST   /api/auth/forgot-password  - Password reset
```

**Port:** 8084

**Learning Value:** Deep dive into Spring Security, OAuth 2.0, JWT

---

**Option B: AWS Cognito (Recommended)**

**Why Cognito?**
- ✅ Free tier: 50,000 monthly active users
- ✅ Fully managed (no code to maintain)
- ✅ OAuth 2.0, OIDC built-in
- ✅ JWT handling automatic
- ✅ MFA support
- ✅ Social login (Google, Facebook) ready
- ✅ Industry-standard security

**Integration:**
- All services validate JWT from Cognito
- User info stored in Cognito User Pool
- Custom attributes for roles

**Recommendation:** Use Cognito for this project to focus on microservices patterns. Build custom IAM in a separate learning project if you want to master Spring Security.

---

## Communication Patterns

### Synchronous Communication (REST)

**When to use:**
- Need immediate response
- Querying data
- User is waiting

**Examples:**
- Frontend → Product Service (get products)
- Cart Service → Product Service (verify product exists)
- Order Service → Inventory Service (check stock)
- Order Service → Payment Service (process payment)

**Technology:** REST APIs with JSON

**Optional Enhancement:** Use gRPC with Protocol Buffers for:
- Better performance
- Type safety across Java/.NET
- Smaller payloads

---

### Asynchronous Communication (Events)

**When to use:**
- No immediate response needed
- Side effects
- Eventual consistency acceptable
- Decoupling services

**Examples:**
- Order Service → Inventory Service (reduce stock)
- Order Service → Notification Service (send email)
- Payment Service → Order Service (payment completed)

**Technology:** AWS SNS + SQS

**Pattern:** Pub/Sub with Fan-out

```
Order Service publishes to SNS Topic
            ↓
    SNS broadcasts to multiple SQS queues
            ↓
    ┌───────┴────────┬──────────────┐
    ↓                ↓              ↓
Inventory SQS   Notification SQS  Other SQS
    ↓                ↓              ↓
Inventory Svc   Notification Svc  Other Svc
```

**Benefits:**
- Services process independently
- If one service is down, messages queue up
- No message loss
- Easy to add new subscribers

---

### Protocol Buffers (Optional)

**Use for:**
- gRPC service-to-service calls
- SQS message payloads (smaller, faster)
- Type-safe contracts across Java/.NET

**Setup:**
```
shared/
  proto/
    ├── common.proto        (Money, Address, AuditInfo)
    ├── product.proto       (Product, ProductService)
    ├── order.proto         (Order, OrderService)
    ├── payment.proto       (Payment, PaymentService)
    └── inventory.proto     (Inventory, InventoryService)
```

**Auto-generates:**
- Java classes (via protoc-gen-java)
- C# classes (via protoc-gen-csharp)

**Benefit:** Change `.proto` once, both Java and .NET get updated classes automatically.

---

## Event Flow Examples

### Checkout Flow (Happy Path)

```
1. User clicks "Checkout"
   Frontend → Order Service: POST /api/orders/checkout

2. Order Service orchestrates:
   a. Get cart items
      Order Service → Cart Service: GET /api/cart
   
   b. Verify inventory
      Order Service → Inventory Service: POST /api/inventory/check
   
   c. Create order (status: PENDING_PAYMENT)
      Save to PostgreSQL
   
   d. Process payment
      Order Service → Payment Service: POST /api/payments/process
      
   e. If payment succeeds:
      - Update order (status: CONFIRMED)
      - Publish event: OrderConfirmed → SNS
      - Return success to user
   
   f. If payment fails:
      - Update order (status: PAYMENT_FAILED)
      - Return error to user

3. Asynchronous processing (happens in background):
   
   SNS receives OrderConfirmed event
   ↓
   Broadcasts to SQS queues
   ↓
   ├─→ Inventory Service (reduces stock)
   ├─→ Notification Service (sends confirmation email)
   └─→ Cart Service (clears cart)

4. User receives:
   - Immediate: "Order placed successfully!"
   - Email: Order confirmation (few seconds later)
```

---

### Payment Failure Flow

```
1. Payment Service detects failure
   - Card declined
   - Insufficient funds
   - Invalid card

2. Payment Service:
   - Stores payment record (status: FAILED)
   - Publishes PaymentFailed event → SNS

3. Order Service (subscribed to PaymentFailed):
   - Updates order (status: PAYMENT_FAILED)
   - Publishes OrderPaymentFailed event

4. Notification Service:
   - Sends email: "Payment failed, please try again"

5. Inventory Service:
   - Releases any reserved stock
```

---

### Order Cancellation Flow

```
1. User requests cancellation
   Frontend → Order Service: PUT /api/orders/{id}/cancel

2. Order Service:
   - Checks if cancellation allowed (not yet shipped)
   - Updates order (status: CANCELLED)
   - Publishes OrderCancelled event → SNS

3. Payment Service (subscribed):
   - Initiates refund
   - Publishes PaymentRefunded event

4. Inventory Service (subscribed):
   - Restores stock

5. Notification Service (subscribed):
   - Sends cancellation confirmation email
```

---

## Database Strategy

### Polyglot Persistence Rationale

| Service | Database | Why? |
|---------|----------|------|
| Product Catalog | MongoDB | Flexible schema for varying product attributes |
| Inventory | PostgreSQL | ACID compliance for stock counts |
| Cart | Redis | Fast, temporary session data with TTL |
| Order | PostgreSQL | Complex transactions, critical business data |
| Payment | PostgreSQL | Financial data requires ACID compliance |
| Notification | MongoDB | Immutable audit logs, append-only |
| IAM | PostgreSQL | User credentials, security-critical |

### AWS Free Tier Setup

```
Aurora DSQL (Serverless PostgreSQL)
├── inventorydb      (Inventory Service)
├── orderdb          (Order Service)
├── paymentdb        (Payment Service)
└── iamdb            (IAM Service - if custom)

MongoDB Atlas (Free Tier: 512MB)
├── productdb        (Product Catalog)
└── notificationdb   (Notification logs)

Redis Labs Cloud (Free Tier: 30MB)
└── carts            (Shopping Cart data)
```

**All within free tier limits!**

---

## Testing Strategy

### Unit Tests

**Java Services:**
- JUnit 5
- Mockito
- AssertJ
- Test coverage: 80% minimum

**Example:**
```java
@ExtendWith(MockitoExtension.class)
class ProductServiceTest {
    @Mock
    private ProductRepository repository;
    
    @InjectMocks
    private ProductServiceImpl service;
    
    @Test
    void getProduct_Success() {
        // Given
        when(repository.findById("1"))
            .thenReturn(Optional.of(testProduct));
        
        // When
        Product result = service.getProductById("1");
        
        // Then
        assertThat(result.getName()).isEqualTo("Test Product");
    }
}
```

**.NET Services:**
- xUnit
- Moq
- FluentAssertions
- Test coverage: 80% minimum

---

### Integration Tests

**Java:**
- Spring Boot Test
- TestContainers (for real databases)
- REST Assured (for API testing)

**Example:**
```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Testcontainers
class ProductIntegrationTest {
    @Container
    static MongoDBContainer mongodb = new MongoDBContainer("mongo:7");
    
    @Test
    void createProduct_Success() {
        given()
            .contentType(JSON)
            .body(productRequest)
        .when()
            .post("/api/products")
        .then()
            .statusCode(201)
            .body("name", equalTo("Test Product"));
    }
}
```

**.NET:**
- WebApplicationFactory
- In-memory databases for testing
- Integration test projects

---

### Contract Tests

**For gRPC/Protobuf:**
- Test proto contracts
- Ensure Java and .NET services can communicate

**For Events:**
- Test event schemas
- Verify all subscribers handle events correctly

---

## Project Structure

```
online-shopping/
├── README.md
├── ARCHITECTURE.md                    (this file)
├── Makefile
├── docker-compose.yml
├── .gitignore
│
├── shared/
│   ├── proto/                         (Protobuf definitions)
│   │   ├── common.proto
│   │   ├── product.proto
│   │   ├── order.proto
│   │   ├── payment.proto
│   │   └── inventory.proto
│   ├── docker/                        (Dockerfiles)
│   └── test-data/                     (Shared test fixtures)
│
├── product-service/                   (Java)
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   └── src/
│       ├── main/
│       │   ├── java/.../product/
│       │   │   ├── controller/
│       │   │   ├── service/
│       │   │   ├── repository/
│       │   │   ├── model/
│       │   │   ├── dto/
│       │   │   ├── mapper/
│       │   │   └── config/
│       │   └── resources/
│       │       └── application.properties
│       └── test/
│
├── inventory-service/                 (Java)
│   └── (same structure as product-service)
│
├── cart-service/                      (Java)
│   └── (same structure)
│
├── order-service/                     (.NET)
│   ├── OrderService.csproj
│   ├── Program.cs
│   ├── Controllers/
│   ├── Services/
│   ├── Models/
│   ├── Data/
│   ├── DTOs/
│   ├── Mappers/
│   └── Tests/
│
├── payment-service/                   (.NET)
│   └── (same structure as order-service)
│
├── notification-service/              (.NET)
│   └── (same structure)
│
└── docs/
    ├── api/                          (API documentation)
    ├── diagrams/                     (Architecture diagrams)
    └── decisions/                    (ADRs - Architecture Decision Records)
```

---

## Build & Run

### Local Development

**Prerequisites:**
- Java 25
- .NET 8 SDK
- Docker & Docker Compose
- AWS CLI (configured)
- Maven or Gradle

**Setup:**
```bash
# Clone repository
git clone <repo-url>
cd online-shopping

# Start local infrastructure
docker-compose up -d
# Starts: PostgreSQL, MongoDB, Redis locally

# Run Java services
cd product-service && ./gradlew bootRun
cd inventory-service && ./gradlew bootRun
cd cart-service && ./gradlew bootRun

# Run .NET services
cd order-service && dotnet run
cd payment-service && dotnet run
cd notification-service && dotnet run
```

---

### Build All Services

```bash
# Using Makefile
make build-all

# Or manually
cd product-service && ./gradlew build
cd inventory-service && ./gradlew build
cd cart-service && ./gradlew build
cd order-service && dotnet build
cd payment-service && dotnet build
cd notification-service && dotnet build
```

---

### Run Tests

```bash
# All tests
make test-all

# Java services
cd product-service && ./gradlew test

# .NET services
cd order-service && dotnet test
```

---

### Docker Deployment

```bash
# Build and run all services
docker-compose up --build

# Run in detached mode
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all
docker-compose down
```

---

## AWS Deployment (Free Tier)

### Option 1: ECS Fargate (Recommended)

```bash
# Build Docker images
docker build -t product-service ./product-service
docker build -t order-service ./order-service

# Push to ECR
aws ecr create-repository --repository-name product-service
docker tag product-service:latest <account-id>.dkr.ecr.<region>.amazonaws.com/product-service:latest
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/product-service:latest

# Deploy to ECS (use Terraform or CloudFormation)
```

### Option 2: Single EC2 Instance

```bash
# SSH into EC2 t2.micro (free tier)
ssh -i key.pem ec2-user@<instance-ip>

# Install Docker
sudo yum install docker -y
sudo service docker start

# Clone and run
git clone <repo>
cd online-shopping
docker-compose up -d
```

---

## Monitoring & Observability

### Logging
- **Java:** SLF4J + Logback
- **.NET:** Serilog
- **Centralized:** AWS CloudWatch Logs (free tier: 5GB ingestion)

### Metrics
- **Java:** Spring Boot Actuator + Micrometer
- **.NET:** ASP.NET Health Checks
- **Dashboard:** AWS CloudWatch (free tier)

### Tracing (Optional)
- AWS X-Ray (free tier: 100K traces/month)
- Helps debug requests across services

### Health Checks

```
GET /actuator/health     (Java services)
GET /health              (.NET services)
```

---

## API Documentation

### OpenAPI/Swagger

**Java Services:**
```java
// Add dependency
implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.3.0")

// Access at:
http://localhost:8081/swagger-ui.html
```

**.NET Services:**
```csharp
// Built-in
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Access at:
http://localhost:5000/swagger
```

---

## Security Considerations

### Authentication
- JWT tokens from AWS Cognito (or custom IAM)
- All services validate JWT

### Authorization
- Role-based access control (RBAC)
- Roles: CUSTOMER, ADMIN, SELLER

### API Gateway
- Rate limiting
- Request throttling
- API key management

### Database
- Encrypted connections (SSL/TLS)
- Least privilege access
- No direct public access

### Secrets Management
- AWS Secrets Manager (free tier: 30-day trial)
- Or AWS Systems Manager Parameter Store (free)

---

## Cost Estimation

### Free Tier (12 months)
```
Aurora DSQL:  $0  (within 100K DPUs)
MongoDB Atlas: $0  (512MB free forever)
Redis Labs:    $0  (30MB free forever)
SQS:           $0  (1M requests free forever)
SNS:           $0  (1K emails)
Cognito:       $0  (50K MAUs)
ECS Fargate:   $0  (limited free compute)

Total: $0/month
```

### After Free Tier
```
Aurora DSQL:   ~$20/month  (light usage)
EC2 t2.micro:  ~$10/month  (single instance)
Data Transfer: ~$5/month
SQS:           $0          (still free!)

Total: ~$35/month
```

---

## Recommendations Summary

### Technology Choices
✅ **Use Aurora DSQL** - Modern, serverless, free tier generous  
✅ **Use SQS + SNS** - Simple, reliable, free forever  
✅ **Use AWS Cognito** - Save time, focus on microservices  
✅ **MongoDB Atlas** - Free tier sufficient for learning  
✅ **Redis Labs Cloud** - Free tier works great for carts  

### Architecture Patterns
✅ **Polyglot Persistence** - Right database for each job  
✅ **Event-Driven** - Decouple services with events  
✅ **API Gateway** - Single entry point  
✅ **Database per Service** - True microservices isolation  

### Development Workflow
✅ **Local First** - Develop with Docker locally, deploy to AWS for testing  
✅ **CI/CD** - GitHub Actions (free for public repos)  
✅ **Infrastructure as Code** - Terraform or CDK for AWS resources  

### Learning Path
1. Start with 3 services (Product, Order, Payment)
2. Add messaging (SQS/SNS)
3. Add remaining services
4. Add monitoring
5. Add advanced patterns (circuit breakers, saga pattern)

---

## Next Steps

1. **Setup local environment**
   - Install Java 25, .NET 8, Docker
   - Setup IDEs (IntelliJ, VS Code/Rider)

2. **Create project structure**
   - Initialize Spring Boot services
   - Initialize .NET services
   - Setup shared proto files

3. **Implement core services**
   - Start with Product Service
   - Add Cart Service
   - Implement Order Service
   - Add Payment Service

4. **Setup AWS infrastructure**
   - Create Aurora DSQL cluster
   - Setup MongoDB Atlas
   - Configure SQS queues and SNS topics
   - Setup Cognito User Pool

5. **Implement communication**
   - REST APIs between services
   - Event publishing/consuming
   - API Gateway configuration

6. **Add testing**
   - Unit tests for each service
   - Integration tests
   - End-to-end testing

7. **Deploy to AWS**
   - Containerize services
   - Deploy to ECS Fargate
   - Configure monitoring

---

## Detailed Checkout Flow (Final Design)

### Prerequisites
- User is authenticated (JWT from Cognito)
- User has items in cart
- Products exist and are active

### Step-by-Step Flow

#### Phase 1: User Initiates Checkout (Synchronous)

```
1. User clicks "Checkout" button
   ↓
2. Frontend sends request
   POST /api/orders/checkout
   Headers: Authorization: Bearer <JWT>
   Body: {
     "shippingAddress": {...},
     "paymentMethod": "CREDIT_CARD",
     "paymentDetails": {...}
   }
   ↓
3. Order Service receives request
```

#### Phase 2: Order Service Orchestration (Synchronous)

```
4. Order Service validates JWT
   ↓
5. Order Service → Cart Service
   GET /api/cart
   Response: {
     "items": [
       {"productId": "prod-1", "quantity": 2},
       {"productId": "prod-2", "quantity": 1}
     ]
   }
   ↓
6. Order Service → Product Service (for each item)
   GET /api/products/prod-1
   GET /api/products/prod-2
   Response: Product details with current prices
   ↓
7. Order Service calculates:
   - Subtotal
   - Tax
   - Shipping cost
   - Total amount
   ↓
8. Order Service → Inventory Service
   POST /api/inventory/check
   Body: {
     "items": [
       {"productId": "prod-1", "quantity": 2},
       {"productId": "prod-2", "quantity": 1}
     ]
   }
   Response: {
     "available": true,
     "reservationId": "res-123"  // Stock temporarily reserved
   }
   
   If not available → Return error to user immediately
   ↓
9. Order Service creates order record
   Status: PENDING_PAYMENT
   Save to PostgreSQL
   ↓
10. Order Service → Payment Service
    POST /api/payments/process
    Body: {
      "orderId": "order-123",
      "amount": 299.99,
      "currency": "USD",
      "paymentMethod": "CREDIT_CARD",
      "paymentDetails": {...}
    }
    
    Payment Service processes:
    - Validates payment details
    - Calls mock payment gateway
    - Returns success/failure
```

#### Phase 3: Payment Success Path (Synchronous → Async)

```
11. If payment succeeds:
    ↓
12. Order Service updates order
    Status: CONFIRMED
    PaymentId: "pay-456"
    ↓
13. Order Service publishes event to SNS
    Topic: "OrderEvents"
    Event: OrderConfirmed {
      "orderId": "order-123",
      "userId": "user-789",
      "items": [...],
      "totalAmount": 299.99,
      "reservationId": "res-123"
    }
    ↓
14. Order Service responds to user
    Status: 200 OK
    Body: {
      "orderId": "order-123",
      "status": "CONFIRMED",
      "message": "Order placed successfully!"
    }
    
    ⏱️ User sees success immediately (< 2 seconds)
```

#### Phase 4: Asynchronous Post-Processing

```
15. SNS broadcasts OrderConfirmed event to SQS queues
    ↓
    ├─→ inventory-service-queue
    ├─→ notification-service-queue
    └─→ cart-service-queue

16. Inventory Service (consumes from SQS)
    - Reads OrderConfirmed event
    - Confirms reservation (res-123)
    - Reduces actual stock
    - Publishes InventoryUpdated event
    
    If stock update fails:
    - Retry (SQS handles retries)
    - After max retries → Dead Letter Queue
    - Alert admin

17. Notification Service (consumes from SQS)
    - Reads OrderConfirmed event
    - Loads email template
    - Sends order confirmation email
    - Logs to MongoDB audit log
    - Marks message as processed
    
    ⏱️ Email arrives in 5-10 seconds

18. Cart Service (consumes from SQS)
    - Reads OrderConfirmed event
    - Clears user's cart from Redis
    - Marks message as processed
```

#### Phase 5: Payment Failure Path

```
11. If payment fails:
    ↓
12. Order Service updates order
    Status: PAYMENT_FAILED
    FailureReason: "Card declined"
    ↓
13. Order Service → Inventory Service
    POST /api/inventory/release
    Body: {"reservationId": "res-123"}
    (Releases reserved stock)
    ↓
14. Order Service publishes event
    Topic: "OrderEvents"
    Event: OrderPaymentFailed {
      "orderId": "order-123",
      "userId": "user-789",
      "reason": "Card declined"
    }
    ↓
15. Order Service responds to user
    Status: 402 Payment Required
    Body: {
      "orderId": "order-123",
      "status": "PAYMENT_FAILED",
      "message": "Payment failed: Card declined",
      "retryable": true
    }
    
    ⏱️ User sees error immediately

16. Notification Service (async)
    - Sends "Payment failed" email
    - Suggests retry or different payment method
```

---

## Error Handling & Resilience

### Retry Strategies

#### Synchronous Calls (Circuit Breaker Pattern)
```java
// Java - using Resilience4j
@CircuitBreaker(name = "inventory-service", fallbackMethod = "inventoryFallback")
public boolean checkInventory(List<OrderItem> items) {
    return inventoryClient.checkStock(items);
}

private boolean inventoryFallback(Exception e) {
    log.error("Inventory service unavailable", e);
    // Option 1: Fail fast
    throw new ServiceUnavailableException("Cannot verify stock");
    
    // Option 2: Optimistic (allow order, verify later)
    // return true;
}
```

```csharp
// .NET - using Polly
var retryPolicy = Policy
    .Handle<HttpRequestException>()
    .WaitAndRetryAsync(3, retryAttempt => 
        TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)));

var result = await retryPolicy.ExecuteAsync(async () =>
    await _paymentClient.ProcessPaymentAsync(request)
);
```

#### Asynchronous Processing (SQS)
```
SQS Configuration:
- Visibility Timeout: 30 seconds
- Max Receive Count: 3 attempts
- Dead Letter Queue: For failed messages after 3 retries
- Delay: 0 seconds (immediate processing)
```

### Timeout Configuration

```properties
# Java application.properties
# HTTP client timeouts
spring.cloud.openfeign.client.config.default.connectTimeout=5000
spring.cloud.openfeign.client.config.default.readTimeout=10000

# gRPC timeouts
grpc.client.*.deadline=10s
```

```json
// .NET appsettings.json
{
  "HttpClient": {
    "Timeout": "00:00:10"
  },
  "CircuitBreaker": {
    "FailureThreshold": 5,
    "SamplingDuration": "00:00:30",
    "MinimumThroughput": 10,
    "DurationOfBreak": "00:01:00"
  }
}
```

### Idempotency

**Problem:** Network issues might cause duplicate requests

**Solution:** Idempotency keys

```java
// Order Service
@PostMapping("/checkout")
public OrderResponse checkout(
    @RequestHeader("Idempotency-Key") String idempotencyKey,
    @RequestBody CheckoutRequest request) {
    
    // Check if we've already processed this request
    Order existingOrder = orderRepository.findByIdempotencyKey(idempotencyKey);
    if (existingOrder != null) {
        return OrderResponse.from(existingOrder); // Return cached result
    }
    
    // Process new order
    Order order = processCheckout(request);
    order.setIdempotencyKey(idempotencyKey);
    orderRepository.save(order);
    
    return OrderResponse.from(order);
}
```

---

## Data Consistency Patterns

### Saga Pattern (For Distributed Transactions)

**Problem:** Order involves multiple services - what if one fails after others succeed?

**Solution:** Choreography-based Saga

```
Happy Path:
Order Service → OrderCreated event
    ↓
Payment Service → Processes → PaymentCompleted event
    ↓
Inventory Service → Reduces stock → InventoryReduced event
    ↓
Notification Service → Sends email → NotificationSent event
    ↓
All done! ✅

Failure Path (Payment fails):
Order Service → OrderCreated event
    ↓
Payment Service → Processes → PaymentFailed event
    ↓
Order Service (listening) → Updates order status
    ↓
Inventory Service → Releases reserved stock
    ↓
Notification Service → Sends "payment failed" email
    ↓
Saga compensated! ↩️
```

### Eventual Consistency

**Accept that:**
- Stock might be slightly off for a few seconds
- Emails arrive after order confirmation
- Analytics are delayed

**Ensure that:**
- Critical data (payments, orders) are strongly consistent
- Users see eventual consistency as "processing"
- Compensating actions handle failures

---

## Performance Optimization

### Caching Strategy

#### Product Catalog (Read-Heavy)
```java
// Cache product details in Redis
@Cacheable(value = "products", key = "#productId")
public Product getProductById(String productId) {
    return productRepository.findById(productId)
        .orElseThrow(() -> new ProductNotFoundException(productId));
}

// Cache configuration
spring.cache.redis.time-to-live=3600000  # 1 hour
```

#### Inventory Counts (Frequent Reads)
```java
// Cache with short TTL
@Cacheable(value = "inventory", key = "#productId", unless = "#result < 10")
public int getStockLevel(String productId) {
    return inventoryRepository.getStock(productId);
}

spring.cache.redis.time-to-live=60000  # 1 minute (fresh stock data)
```

### Database Indexing

```sql
-- Product Service (MongoDB)
db.products.createIndex({ "sku": 1 }, { unique: true })
db.products.createIndex({ "category": 1, "price": 1 })
db.products.createIndex({ "name": "text" })  -- Full-text search

-- Inventory Service (PostgreSQL)
CREATE INDEX idx_inventory_product_id ON inventory(product_id);
CREATE INDEX idx_inventory_updated_at ON inventory(updated_at);

-- Order Service (PostgreSQL)
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
```

### Connection Pooling

```properties
# Java - HikariCP (default in Spring Boot)
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=5
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.idle-timeout=600000
```

```csharp
// .NET - Connection pooling built into Npgsql
"ConnectionStrings": {
  "DefaultConnection": "Host=localhost;Database=orderdb;Pooling=true;MinPoolSize=5;MaxPoolSize=20;ConnectionLifeTime=300"
}
```

---

## Monitoring & Alerts

### Key Metrics to Track

#### Service Health
- Response time (p50, p95, p99)
- Error rate (4xx, 5xx)
- Request rate (requests/second)
- Active connections

#### Business Metrics
- Orders per minute
- Cart abandonment rate
- Payment success rate
- Average order value
- Inventory turnover

#### Infrastructure
- CPU usage
- Memory usage
- Database connections
- Queue depth (SQS)

### Sample Dashboard (CloudWatch)

```
┌─────────────────────────────────────────────────┐
│          Order Service Dashboard                │
├─────────────────────────────────────────────────┤
│  📊 Request Rate: 150 req/min                   │
│  ⏱️  Avg Response Time: 245ms                   │
│  ❌ Error Rate: 0.5%                            │
│  💳 Payment Success Rate: 97.2%                 │
│  📦 Orders (last hour): 42                      │
└─────────────────────────────────────────────────┘
```

### Alerting Rules

```yaml
# CloudWatch Alarms
- Alarm: HighErrorRate
  Metric: ErrorRate
  Threshold: > 5% for 5 minutes
  Action: Send SNS notification to DevOps team

- Alarm: SlowResponses
  Metric: ResponseTime_p99
  Threshold: > 3 seconds for 10 minutes
  Action: Send SNS notification

- Alarm: PaymentFailures
  Metric: PaymentFailureRate
  Threshold: > 10% for 5 minutes
  Action: Page on-call engineer

- Alarm: QueueBacklog
  Metric: SQS_ApproximateNumberOfMessagesVisible
  Threshold: > 1000 messages
  Action: Auto-scale consumers
```

---

## Security Best Practices

### API Security Checklist

✅ **Authentication**
- All endpoints require valid JWT (except public product catalog)
- JWT validated in API Gateway or service level
- Short token expiry (15 minutes) with refresh tokens

✅ **Authorization**
- Role-based access control (RBAC)
- User can only access their own orders
- Admin endpoints require ADMIN role

✅ **Input Validation**
- Validate all input (Bean Validation in Java, Data Annotations in .NET)
- Sanitize user input to prevent injection attacks
- Limit request payload size

✅ **Rate Limiting**
- API Gateway: 1000 requests/minute per user
- Prevent brute force attacks
- Throttle abusive clients

✅ **HTTPS Only**
- All communication over TLS 1.3
- No plain HTTP endpoints
- Certificate management via AWS ACM

✅ **Secret Management**
- No hardcoded passwords
- Use AWS Secrets Manager or Parameter Store
- Rotate credentials regularly

✅ **Database Security**
- No public database access
- Use VPC and security groups
- Encrypted at rest and in transit
- Least privilege IAM roles

### Example Security Configuration

```java
// Java - Spring Security
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf().disable()  // Using JWT, not session-based
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/products/**").permitAll()  // Public
                .requestMatchers("/api/orders/**").authenticated()  // User only
                .requestMatchers("/admin/**").hasRole("ADMIN")  // Admin only
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer()
                .jwt();  // Validate JWT from Cognito
        
        return http.build();
    }
}
```

```csharp
// .NET - JWT Authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://cognito-idp.us-east-1.amazonaws.com/{userPoolId}";
        options.Audience = "your-client-id";
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy => 
        policy.RequireRole("Admin"));
});
```

---

## Deployment Pipeline (CI/CD)

### GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy Microservices

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test-java-services:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up JDK 25
        uses: actions/setup-java@v3
        with:
          java-version: '25'
          
      - name: Build and Test Product Service
        run: |
          cd product-service
          ./gradlew build test
          
      - name: Build and Test Inventory Service
        run: |
          cd inventory-service
          ./gradlew build test
          
      - name: Build and Test Cart Service
        run: |
          cd cart-service
          ./gradlew build test

  test-dotnet-services:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '8.0.x'
          
      - name: Build and Test Order Service
        run: |
          cd order-service
          dotnet build
          dotnet test
          
      - name: Build and Test Payment Service
        run: |
          cd payment-service
          dotnet build
          dotnet test

  build-and-push-images:
    needs: [test-java-services, test-dotnet-services]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
          
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
        
      - name: Build and push Docker images
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        run: |
          # Product Service
          docker build -t $ECR_REGISTRY/product-service:latest ./product-service
          docker push $ECR_REGISTRY/product-service:latest
          
          # Order Service
          docker build -t $ECR_REGISTRY/order-service:latest ./order-service
          docker push $ECR_REGISTRY/order-service:latest
          
          # ... other services
          
  deploy-to-ecs:
    needs: build-and-push-images
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster microservices-cluster \
            --service product-service \
            --force-new-deployment
```

---

## Learning Outcomes

By completing this project, you will have learned:

### Microservices Architecture
✅ Service decomposition and boundaries  
✅ Inter-service communication patterns  
✅ Event-driven architecture  
✅ Service discovery and registration  
✅ API Gateway pattern  

### Data Management
✅ Polyglot persistence  
✅ Database per service pattern  
✅ Eventual consistency  
✅ Saga pattern for distributed transactions  
✅ CQRS basics  

### Messaging & Events
✅ Pub/Sub pattern with SNS/SQS  
✅ Event sourcing concepts  
✅ Message queues and reliability  
✅ Asynchronous processing  

### Technology Stack
✅ Java 25 & Spring Boot 3.4  
✅ .NET 8 & ASP.NET Core  
✅ PostgreSQL & Aurora DSQL  
✅ MongoDB  
✅ Redis  
✅ Protocol Buffers & gRPC  

### Cloud & DevOps
✅ AWS services (Aurora DSQL, SQS, SNS, Cognito, ECS)  
✅ Docker & containerization  
✅ CI/CD with GitHub Actions  
✅ Infrastructure as Code basics  
✅ Monitoring and observability  

### Software Engineering
✅ Clean architecture principles  
✅ Domain-driven design basics  
✅ Test-driven development  
✅ Error handling and resilience  
✅ Security best practices  

---

## Resources & References

### Official Documentation
- [Spring Boot Reference](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [ASP.NET Core Documentation](https://docs.microsoft.com/en-us/aspnet/core/)
- [AWS Aurora DSQL](https://docs.aws.amazon.com/aurora-dsql/)
- [AWS SQS Developer Guide](https://docs.aws.amazon.com/sqs/)
- [Protocol Buffers](https://protobuf.dev/)

### Books (Recommended)
- "Building Microservices" by Sam Newman
- "Domain-Driven Design" by Eric Evans
- "Designing Data-Intensive Applications" by Martin Kleppmann
- "Enterprise Integration Patterns" by Gregor Hohpe

### Online Courses
- Udemy: Microservices with Spring Boot and Spring Cloud
- Pluralsight: Microservices Architecture
- AWS Training: Architecting on AWS

---

## Glossary

**Aurora DSQL** - AWS serverless distributed SQL database, PostgreSQL-compatible

**Circuit Breaker** - Design pattern that prevents cascading failures by failing fast

**DPU** - Database Processing Unit (Aurora DSQL's pricing metric)

**Eventual Consistency** - Data will become consistent over time, not immediately

**gRPC** - High-performance RPC framework using Protocol Buffers

**Idempotency** - Operation that produces same result if executed multiple times

**Polyglot Persistence** - Using different database technologies for different services

**Protocol Buffers** - Language-neutral data serialization format

**Saga Pattern** - Managing distributed transactions across microservices

**SNS** - Simple Notification Service (pub/sub messaging)

**SQS** - Simple Queue Service (message queuing)

---

## Contact & Contribution

This is a learning project. Feel free to:
- Fork and experiment
- Suggest improvements:
- Share your learnings
- Ask questions

**Happy Learning! 🚀**

---

*Last Updated: [Current Date]*  
*Version: 1.0*  
*Status: In Development*

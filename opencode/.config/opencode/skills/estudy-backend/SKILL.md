---
name: estudy-backend
description: Read and understand the LangMaster eStudy Backend API at ~/gitlab/api-estudy.langmaster.vn. Use when working on frontend-backend integration, debugging API calls, understanding data structures, checking endpoints, or verifying backend behavior. The backend is a Laravel 10 PHP app with JWT auth, multi-database architecture, and service layer pattern.
---

# eStudy Backend Reader

Guide for reading the LangMaster eStudy Backend API codebase.

## Backend Location

```
~/gitlab/api-estudy.langmaster.vn
```

## When to Use

- Frontend needs to call a new API endpoint
- Debugging API response mismatches
- Understanding data structures returned by backend
- Verifying endpoint paths, methods, or middleware
- Checking authentication flow
- Understanding business logic behind features

## Quick Start

1. Read `CLAUDE.md` first — it contains architecture overview
2. Check `routes/api/v1.php` for endpoint definitions
3. Follow the controller → service → model chain

## Key Paths

### Routes
- `routes/api/v1.php` — All v1 API endpoints (main entry point)

### Controllers
- `app/Http/Controllers/Api/V1/` — All API controllers organized by domain

### Services (Business Logic)
- `app/Services/` — Domain-organized business logic
  - `Assessment/` — Testing and evaluation
  - `StudentChallenge/` — Learning exercises
  - `RouteStudy/` — Course progression
  - `Contact/` — User profiles
  - `VirtualAssistant/` — AI chatbot
  - `ArtificialIntelligence/` — OpenAI integration
  - `Media/` — File uploads to S3
  - `IeltsPlacementTest/` — English proficiency testing

### Models
- `app/Models/` — Eloquent models
  - Extends `BaseErpAdmin` → `erp_admin` database
  - Extends `BaseErpLangmaster` → `erp_langmaster` database
  - Extends `BaseErpLangmasterLogs` → `erp_langmaster_logs` database

### Form Requests (Validation)
- `app/Http/Requests/` — Request validation classes organized by domain

### Constants
- `app/Services/_Constant/ConstantService.php` — All constants (use these, not magic numbers)

## Architecture Patterns

### Response Format
All services return:
```php
// Success
$this->sendSuccessResponse($data, 200, true, 'Message');
// Returns: { status: true, message: '', data: $data }

// Error
$this->sendErrorResponse('Error', 400, false, $errors);
// Returns: { status: false, message: 'Error', errors: $errors }
```

### Auth
- JWT via `tymon/jwt-auth`
- Guard: `contact` (not default `api`)
- Middleware: `auth:contact`
- Get user: `auth('contact')->user()`

### Multi-Database
Three MySQL databases with automatic routing via base model classes.

## Reading Flow

### To understand an endpoint:
1. Find route in `routes/api/v1.php`
2. Open the controller method
3. Read the service class it calls
4. Check any models/relations used
5. Review Form Request for validation rules

### To understand a feature:
1. Search for relevant service in `app/Services/DomainName/`
2. Read the service methods
3. Check related models and their relationships
4. Review constants in `ConstantService.php`

### To debug an issue:
1. Check the API response format in service
2. Review validation rules in Form Request
3. Check model scopes/filters in `app/Filters/`
4. Look for helper functions in `app/Helpers/`

## Important Notes

- Vietnamese language in comments and messages
- Timestamps disabled on base models — handle manually if needed
- Use `ConstantService` constants, not magic numbers
- Controllers should be thin — logic lives in services
- Namespace underscore prefix: `App\Services\_Abstract`, etc.

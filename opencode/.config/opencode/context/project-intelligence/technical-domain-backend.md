<!-- Context: project-intelligence/technical-backend | Priority: critical | Version: 1.0 | Updated: 2026-05-19 -->

# Technical Domain — HBR ERP Admin API (Backend)

> Laravel 13 modular monolith JSON API powering the HBR Holdings ERP admin backend.

## Quick Reference

- **Purpose**: Understand how the HBR Admin API works — stack, patterns, architecture
- **Update When**: New modules, pattern changes, library additions
- **Audience**: Developers, AI agents, new team members

## Primary Stack

| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| Language | PHP | 8.3 | Modern PHP with attribute support |
| Framework | Laravel | 13 | Full-featured, Sanctum auth, ecosystem |
| Dev DB | SQLite | — | Zero-config local development |
| Prod DB | MySQL | 8.x | Dual DB: `hbr_admin` (primary) + `hbr_logs` (logging) |
| Auth | Laravel Sanctum + Socialite | — | API token auth + Google OAuth login |
| API Docs | Scramble (dedoc/scramble) | 0.13 | Auto OpenAPI from code |
| Testing | Pest | 4.x | Laravel-native testing framework |
| Code Style | Laravel Pint | 1.x | Opinionated PHP code formatter |
| AI | laravel/ai + laravel/mcp | — | First-party AI SDK & MCP server |

## Architecture Pattern

```
Type: Modular Monolith
Pattern: Module-scoped Controller→Action (automated CRUD dispatch)
         POST-only JSON API with unified response envelope
```

### Why This Architecture?

Single admin backend powering multiple ERP domains (Admin, HRM, Langmaster, Auth, Dev).
Modules isolate domains; Action classes keep controllers thin and testable.
POST-only simplifies CSRF, auto-routing eliminates manual route registration.

## Project Structure

```
app/Modules/
├── Admin/          # User, Role, Province, Ward, Permission management
├── Auth/           # Login (password/OTP/Google), Logout, Profile, Permission
├── Base/           # Shared abstract classes & middleware
├── Dev/            # Developer tools (logs viewer, proxy middleware)
├── Hrm/            # HRM: Company, Department (tree structure)
└── Langmaster/     # Language master: dashboards, contracts

Each module:
  Controllers/      # Thin — delegates to Actions
  Actions/          # Business logic — one class per operation
  Requests/         # FormRequest validation per action
  Resources/        # API Resources (JsonResource)
  Models/           # Eloquent models (module-scoped)
  Rules/            # Custom validation rules
```

## Code Patterns

### API Endpoint (Controller → Action)

```php
// Controller: thin wrapper, delegates to Action
class ProvinceController extends BaseController
{
    public function list(ListRequest $request, ListAction $action): mixed
    {
        return $action->handle();
    }
}
```

```php
// Action: business logic, returns JsonResponse
class ListAction extends BaseAction
{
    public function handle(): JsonResponse
    {
        $perPage = $this->request->integer('per_page', 20);
        $query = ProvinceModel::query()
            ->whereConditions($this->request->input('conditions', []))
            ->orderByMany($this->request->input('order_by'));
        $data = $query->paginate($perPage);

        return $this->successResponse(
            data: ProvinceResource::collection($data->items()),
            meta: PaginatedResource::from($data),
        );
    }
}
```

```json
// Success response
{ "success": true, "data": [...], "meta": { "current_page": 1, "total": 50 } }

// Error response
{ "success": false, "message": "Validation failed", "errors": { "name": ["Required."] } }
```

### Model (Traditional `$fillable` / `$hidden`)

```php
class User extends Authenticatable
{
    use HasFactory, Notifiable;

    protected $fillable = ['name', 'email', 'password'];
    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password'          => 'hashed',
        ];
    }
}
```

## Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Files | StudlyCase | `ProvinceController.php`, `ListAction.php` |
| Classes | StudlyCase + suffix | `ProvinceController`, `ListAction`, `AddRequest` |
| Methods | camelCase | `allowedFilters()`, `successResponse()` |
| Variables | camelCase | `$perPage`, `$query`, `$data` |
| Routes | kebab-case | `/admin/province/change-status` |
| DB Tables | snake_case | `provinces`, `hbr_admin` |
| Modules | StudlyCase | `Admin`, `Hrm`, `Langmaster` |
| Suffixes | *Action, *Request, *Controller, *Model | `ListAction`, `AddRequest` |

## Code Standards

1. **Modular architecture** — `app/Modules/{Module}/` with Controllers/Actions/Requests/Resources/Models/Rules
2. **Thin controllers** — delegate all logic to Action classes
3. **FormRequest per action** — validation in dedicated Request classes extending `BaseRequest` / `BaseListRequest`
4. **Unified response** — `BaseAction::successResponse()` / `errorResponse()` for all endpoints
5. **Laravel Pint** for code formatting — run `vendor/bin/pint --format agent` before commit
6. **Pest 4** for testing — `php artisan make:test --pest {name}`
7. **Scramble** for auto-generated OpenAPI docs — annotate with PHPDoc
8. **PHP 8 constructor property promotion** — `public function __construct(protected Request $request) {}`
9. **PHPDoc on public methods** — sparse inline comments only for complex logic
10. **Attribute-based route overrides** — `#[Route(without: [PermissionMiddleware::class])]`
11. **Multi-database** — `hbr_admin` (primary) + `hbr_logs` (logging) on MySQL
12. **POST-only API** — all endpoints use POST, no GET/PUT/PATCH/DELETE (simplifies CSRF)

## Security

1. Sanctum token auth — `auth:sanctum` middleware on all API routes
2. PermissionMiddleware — role-based access on all admin/hrm routes
3. FormRequest validation — every endpoint validates input before reaching Action
4. Google OAuth — Socialite-based login flow (`auth/login/google-verify`)
5. OTP login — 2-step flow: request OTP → verify OTP
6. Token logout — single token (`auth/logout`) + all tokens (`auth/logout/all`)
7. Password hashing — Laravel built-in `hashed` cast
8. Route-level middleware exclusion — `#[Route(without: [...])]` for public endpoints

## 📂 Codebase References

| What | Where | Purpose |
|------|-------|---------|
| Base Controller | `app/Modules/Base/Controllers/BaseController.php` | All controllers extend this |
| Base Action | `app/Modules/Base/Actions/BaseAction.php` | successResponse/errorResponse helpers |
| Base Request | `app/Modules/Base/Requests/BaseRequest.php` | FormRequest base |
| Base ListRequest | `app/Modules/Base/Requests/BaseListRequest.php` | conditions/order_by/per_page |
| Route Attribute | `app/Modules/Base/Attributes/Route.php` | Middleware overrides |
| User Model | `app/Models/User.php` | Core auth model (Sanctum) |
| Auth Module | `app/Modules/Auth/` | Login, Logout, Profile, Permission |
| DB Config | `config/database.php` + `.env` | hbr_admin + hbr_logs connections |
| Route files | `routes/api.php`, `routes/web.php` | API + Dev routes |

## Related Files

- `business-domain.md` — What business problems does the ERP solve?
- `business-tech-bridge.md` — How business needs map to technical modules
- `decisions-log.md` — Major technical decisions and rationale
- `living-notes.md` — Active issues, technical debt, open questions

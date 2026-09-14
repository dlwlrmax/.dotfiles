<!-- Context: project-intelligence/technical-frontend | Priority: critical | Version: 1.0 | Updated: 2026-05-19 -->

# Technical Domain — Vue 3 Admin SPA

> Vue 3 + TypeScript SPA admin panel for HBR Holdings ERP. Built with Vite, Tailwind CSS v4, shadcn-vue, Pinia.

## Quick Reference

- **Purpose**: Understand frontend stack, patterns, architecture
- **Update When**: New deps, pattern changes, component conventions shift
- **Audience**: Frontend developers, AI agents

## Primary Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Framework | Vue 3 (Composition API) | `<script setup>`, TypeScript |
| Language | TypeScript 5.x | Strict, typed props |
| Build | Vite 6.x | Fast HMR, native ESM |
| Styling | Tailwind CSS v4 | `@theme inline`, no config |
| UI Library | shadcn-vue | reka-ui, `@/components/ui/` |
| State | Pinia | Composition stores, auto-imported |
| Routing | vue-router 4.x | History mode, auth guards |
| HTTP | Axios | Token interceptor, POST-only |
| Validation | vee-validate + zod | Form-level |
| Icons | @hugeicons/vue | core-free-icons, min size-4 |
| Auth | vue3-google-login | Google OAuth |
| Toast | vue-sonner | Success/error |
| Package | pnpm | Lockfile, workspace |

## Architecture Pattern

```
Type: SPA with Pinia stores + composables
Pattern: View → Composable → API call
         Core components wrap shadcn-vue primitives
         Router guards enforce auth + permissions
```

Composables extract logic from views → thin components. Core wrappers add project behavior to shadcn-vue primitives (e.g., `cursor-pointer` on Button). Pinia stores manage auth, permissions, config.

## Project Structure

```
src/
├── assets/index.css        # Tailwind v4 @theme inline
├── components/
│   ├── core/               # Project wrappers (Button, Form, TableData, Sidebar...)
│   └── ui/                 # shadcn-vue primitives (auto-generated, ESLint ignored)
├── composables/            # Shared logic (useHeaderActions, useDynamicFilter)
├── layouts/commons/        # AppLayout.vue (auth), GuestLayout.vue (guest)
├── lib/utils.ts            # cn() helper (clsx + tailwind-merge)
├── router/                 # index.ts + per-module route files
├── services/               # api.ts (Axios), endpoints.ts (URL catalog)
├── stores/                 # Pinia stores (auto-imported)
├── types/                  # Shared TypeScript interfaces
└── views/
    ├── Auth/Login/         # Login form
    └── Home/               # Protected pages (Roles, Users, Dashboard, Langmaster...)
        └── {Module}/
            ├── Index.vue           # List page
            ├── Create.vue / Edit.vue  # Form pages
            ├── components/         # Module-specific components
            └── composables/        # Module-specific composables (useXxxForm.ts)
```

## Code Patterns

### API Call (endpoints.ts + store/view)

```typescript
// endpoints.ts — const objects with { url, permission }
export const endpoints = {
    role: {
        list:    { url: "/admin/role/list", permission: "admin.role.list" },
        add:     { url: "/admin/role/add",  permission: "admin.role.add" },
    },
} as const;

// Usage: api.post(endpoint.url, payload) — response: { success, data, meta }
import api from "@/services/api";
const res = await api.post(endpoints.role.list.url, { per_page: 20, page: 1 });
```

### View Page (list)

```vue
<script setup lang="ts">
import { TableData } from "@/components/core/TableData";
import api from "@/services/api";
import { endpoints } from "@/services/endpoints";
import { useDynamicFilter } from "@/composables/useDynamicFilter";

const loading = ref(false);
const data = ref<Item[]>([]);

async function fetchData() {
    loading.value = true;
    try {
        const res = await api.post(endpoints.module.list.url, { /* filters */ });
        data.value = res.data.data as Item[];
    } catch { /* error handled by interceptor */ }
    finally { loading.value = false; }
}
onMounted(() => fetchData());
</script>
<template>
    <TableData :columns="columns" :data="data" :loading="loading" :pagination="{ serverSide: true }"
               @page-change="onPageChange" @sort-change="onSortChange" @dynamic-filter="onDynamicFilter" />
</template>
```

### Form Page (create/edit)

```vue
<script setup lang="ts">
import { Form, FormSkeleton } from "@/components/core/Form";
import { useXxxForm } from "./composables/useXxxForm";
import { useHeaderActions } from "@/composables/useHeaderActions";

const props = withDefaults(defineProps<{ mode?: "create" | "edit"; id?: string }>(), { mode: "create" });
const { formRef, loading, fields, response, handleSubmit, headerActions } = useXxxForm(props);
useHeaderActions(headerActions);
</script>
<template>
    <template v-if="loading"><FormSkeleton :fields="fields" /></template>
    <Form v-else ref="formRef" :fields="fields" :response="response" @submit="handleSubmit" />
</template>
```

### Core Wrapper Pattern

Wrap shadcn-vue primitives, add project-specific behavior via `cn()`:
`import { Button } from "@/components/ui/button"` → re-export with `cursor-pointer` class.

## Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Component files | PascalCase.vue | `TableData.vue`, `AppSidebar.vue` |
| Composable files | camelCase.ts | `useUserForm.ts`, `useDynamicFilter.ts` |
| Service/Store/Type files | camelCase.ts | `api.ts`, `userStore.ts`, `user.ts` |
| Components | PascalCase | `TableData`, `PermissionWrapper` |
| Composables | `use` + PascalCase | `useUserForm`, `useHeaderActions` |
| Stores | `use` + PascalCase + `Store` | `useUserStore`, `usePermissionStore` |
| Functions / Props | camelCase | `fetchRoles`, `sortKey` |
| Router names | dot.case | `home.roles.create`, `home.users.index` |
| Endpoint keys | camelCase | `changeStatus`, `googleVerify` |
| View dirs | PascalCase | `Home/Roles/Index.vue` |

## Code Standards

1. `<script setup lang="ts">` — Composition API only, never Options API
2. TypeScript strict — typed props via `defineProps<{}>()`, `vue-tsc -b` before build
3. Auto-imports — Vue/Pinia APIs pre-declared, `src/composables/` and `src/stores/` auto-imported
4. Core components over UI primitives — import from `@/components/core/` when wrapper exists
5. Logic in composables — views delegate to `composables/use*.ts`
6. ESLint + Prettier — `pnpm lint` / `pnpm format`, lint-staged on pre-commit
7. Formatting — 4-space indent, double quotes, semicolons, `trailingComma: es5`, `printWidth: 150`
8. `cn()` for class merging — from `@/lib/utils` (clsx + tailwind-merge)
9. shadcn-vue in `src/components/ui/` — ESLint ignores this directory
10. Tailwind v4 — `@theme inline` in `src/assets/index.css`, no `tailwind.config.js`
11. POST-only API — `api.post(endpoints.module.action.url, payload)`
12. Router guards — `requiresAuth` / `guest`, permission check on nav
13. HugeiconsIcon min `size-4` — `size-3` renders incorrectly
14. Component names — `vue/multi-word-component-names` off

## Security

1. Bearer token — Axios interceptor injects from `localStorage`
2. Auto-redirect on 401 — clears token → `/login`
3. Route guards — `requiresAuth` (protected) / `guest` (auth pages), permission check on nav
4. Permission-based UI — `PermissionWrapper` component + `permission` field in endpoints
5. Google OAuth — `vue3-google-login` with `VITE_GOOGLE_CLIENT_ID`

## 📂 Codebase References

| What | Where | Purpose |
|------|-------|---------|
| Axios instance | `src/services/api.ts` | Token + error interceptors |
| Endpoint catalog | `src/services/endpoints.ts` | All API URLs + permissions |
| Router | `src/router/index.ts` | Auth guards, lazy-loaded routes |
| Stores | `src/stores/userStore.ts`, `permissionStore.ts` | Auth state, permission cache |
| Core Button | `src/components/core/Button/Button.vue` | Wrapper adding `cursor-pointer` |
| Core Form | `src/components/core/Form/` | Form, Field, Checkbox, Combobox |
| Core TableData | `src/components/core/TableData/` | Server-side table with filters |
| Permission UI | `src/components/core/PermissionWrapper/` | Component-level permission gating |
| Sidebar | `src/components/core/Sidebar/` | App module nav, header actions |
| Form types | `src/types/form.ts` | `TFieldSets` interface |
| Config | `src/assets/index.css`, `AGENTS.md` | Tailwind theme, conventions |
| Layouts | `src/layouts/commons/` | AppLayout (auth), GuestLayout (guest) |

## Related Files

- `technical-domain-backend.md` — Laravel backend API stack & patterns
- `business-domain.md` — What business problems does the ERP solve?
- `business-tech-bridge.md` — How business needs map to modules
- `decisions-log.md` — Major technical decisions and rationale

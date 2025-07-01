# Frontend Guidelines (Vue.js + TypeScript)

**Status:** GUIDELINES - Preferred approaches

**Purpose:** Standard patterns for Vue.js frontend applications.

---

## Project Structure

```
app/{ServiceName}/
├── src/
│   ├── components/      # Reusable components
│   ├── composables/     # Composition API logic
│   ├── views/           # Page components
│   ├── stores/          # Pinia stores
│   ├── router/          # Vue Router
│   ├── services/        # API clients
│   └── types/           # TypeScript types
├── tests/
└── vite.config.ts
```

---

## Composition API

**Prefer Composition API over Options API:**

```typescript
<script setup lang="ts">
import { ref, computed } from 'vue'
import { useUserStore } from '@/stores/user'

const userStore = useUserStore()
const searchQuery = ref('')

const filteredUsers = computed(() =>
  userStore.users.filter(u => u.name.includes(searchQuery.value))
)

async function loadUsers() {
  await userStore.fetchUsers()
}
</script>

<template>
  <v-text-field v-model="searchQuery" label="Search" />
  <v-list>
    <v-list-item v-for="user in filteredUsers" :key="user.id">
      {{ user.name }}
    </v-list-item>
  </v-list>
</template>
```

**Why:** Better TypeScript support, clearer logic reuse.

---

## State Management (Pinia)

**Prefer Pinia over Vuex:**

```typescript
// stores/user.ts
import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { User } from '@/types'

export const useUserStore = defineStore('user', () => {
  const users = ref<User[]>([])
  const loading = ref(false)

  async function fetchUsers() {
    loading.value = true
    try {
      const response = await fetch('/api/users')
      users.value = await response.json()
    } finally {
      loading.value = false
    }
  }

  return { users, loading, fetchUsers }
})
```

**Usage:**
```typescript
<script setup lang="ts">
import { useUserStore } from '@/stores/user'

const userStore = useUserStore()
</script>
```

---

## TypeScript

**Always use TypeScript, avoid `any`:**

```typescript
// ✅ GOOD: Explicit types
interface User {
  id: string
  email: string
  name: string
}

const users = ref<User[]>([])

// ❌ BAD: any type
const users = ref<any[]>([])
```

---

## Testing

**Vitest + @vue/test-utils:**

```typescript
import { mount } from '@vue/test-utils'
import { describe, it, expect } from 'vitest'
import UserList from './UserList.vue'

describe('UserList', () => {
  it('renders users', () => {
    const wrapper = mount(UserList, {
      props: {
        users: [
          { id: '1', name: 'Alice' },
          { id: '2', name: 'Bob' }
        ]
      }
    })

    expect(wrapper.text()).toContain('Alice')
    expect(wrapper.text()).toContain('Bob')
  })
})
```

---

## Core Philosophy

**Principle:** Simplicity over flexibility, predictability over customization.

**Why:**
- Solo developer constraints demand reliability over features
- Reduce cognitive overhead when returning to code months later
- Minimize JavaScript complexity that breaks unexpectedly
- Compromise UI design for system stability

**In Practice:**
- ✅ Use framework patterns (Vue conventions, not custom abstractions)
- ✅ Prefer configuration over code
- ✅ Explicit over clever
- ✅ Boring, predictable solutions
- ❌ Avoid premature abstractions
- ❌ Avoid custom state management patterns
- ❌ No complex reactive chains

**Example - Predictability Over Customization:**

```typescript
// ✅ GOOD: Predictable, framework-aligned
<script setup lang="ts">
import { ref } from 'vue'

const isOpen = ref(false)

function toggle() {
  isOpen.value = !isOpen.value
}
</script>

<template>
  <v-dialog v-model="isOpen">
    <v-card>
      <v-card-title>Dialog Title</v-card-title>
      <v-card-text>Simple, predictable dialog using Vuetify</v-card-text>
    </v-card>
  </v-dialog>
</template>

// ❌ BAD: Custom complexity
<script setup lang="ts">
import { reactive, computed } from 'vue'
import { useCustomDialogManager } from '@/lib/dialogs'

const dialogState = reactive({
  isOpen: false,
  transitioning: false,
  queue: []
})

const manager = useCustomDialogManager(dialogState)
// Complex custom abstraction that's hard to debug months later
</script>
```

**Simplicity Checklist:**
- Can I understand this code 6 months from now?
- Does it follow Vue.js conventions?
- Is it documented in Vue.js or Vuetify docs?
- Will it break if framework updates?

---

## Component Reuse

**Principle:** Prefer well-vetted components over custom implementations.

**Component Selection Priority:**

1. **Vuetify components** (first choice)
   - Material Design patterns
   - Accessibility built-in
   - Well-tested, documented
   - Consistent across app

2. **Web Components** (when Vuetify insufficient)
   - Framework-agnostic
   - Reusable across Vue versions
   - Browser-native standards

3. **Internal generic components** (last resort)
   - Only when no suitable external option
   - Design for future extraction
   - Document thoroughly

**Example - Component Reuse Pattern:**

```typescript
// ✅ GOOD: Use Vuetify first
<template>
  <v-data-table
    :items="users"
    :headers="headers"
    :loading="loading"
  />
</template>

// ⚠️ ACCEPTABLE: Generic internal component when needed
// components/EmptyState.vue
<script setup lang="ts">
interface Props {
  icon?: string
  message: string
  action?: { label: string; onClick: () => void }
}

defineProps<Props>()
</script>

<template>
  <v-container class="text-center py-8">
    <v-icon v-if="icon" size="64" color="grey-lighten-1">{{ icon }}</v-icon>
    <p class="text-h6 text-grey mt-4">{{ message }}</p>
    <v-btn v-if="action" @click="action.onClick" class="mt-4">
      {{ action.label }}
    </v-btn>
  </v-container>
</template>

// Usage
<EmptyState
  icon="mdi-inbox"
  message="No users found"
  :action="{ label: 'Add User', onClick: () => showAddDialog() }"
/>

// ❌ BAD: Custom component duplicating Vuetify functionality
<CustomDataTable /> <!-- Reinventing v-data-table -->
```

**Generic Component Candidates:**
- Empty states
- Error states
- Loading states
- "No results" states
- Confirmation dialogs
- Toast notifications

**Utilities Over Ad-Hoc Logic:**

```typescript
// ✅ GOOD: Reusable utility
// utils/formatters.ts
export function formatDate(date: Date): string {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  }).format(date)
}

// Usage across components
<template>
  <p>{{ formatDate(user.createdAt) }}</p>
</template>

// ❌ BAD: Ad-hoc logic duplicated
<script setup lang="ts">
const formattedDate = computed(() => {
  const d = new Date(user.value.createdAt)
  return `${d.getMonth() + 1}/${d.getDate()}/${d.getFullYear()}`
})
</script>
```

**Design for Future Extraction:**
- Keep components focused (single responsibility)
- Use props/events, not global state
- Document expected behavior
- Include usage examples in comments

---

## Third-Party Libraries

**Principle:** Prefer popular, trusted packages over novelty dependencies.

**Selection Criteria:**

1. **Popularity:** 1,000+ stars on GitHub, active maintenance
2. **Maturity:** 1.0+ version, stable API
3. **Vue Compatibility:** Explicit Vue 3 support
4. **Bundle Size:** < 50KB (check bundlephobia.com)
5. **Type Safety:** Full TypeScript definitions

**Trusted Packages (Examples):**

```typescript
// Date handling
import { formatDistanceToNow } from 'date-fns'

// Form validation (if FluentValidation insufficient)
import { useVuelidate } from '@vuelidate/core'

// HTTP client (if fetch insufficient)
import axios from 'axios'

// Charts (if needed)
import { Line } from 'vue-chartjs'
```

**Avoid Novelty Dependencies:**

```typescript
// ❌ BAD: Unproven, experimental library
import { useMagicReactivity } from 'vue-magic-state' // 10 stars, beta

// ✅ GOOD: Established, proven library
import { useLocalStorage } from '@vueuse/core' // 20k+ stars, stable
```

**Wrap Third-Party Logic Intentionally:**

```typescript
// ✅ GOOD: Wrapper for third-party date library
// utils/dates.ts
import { formatDistanceToNow, format } from 'date-fns'

export const dates = {
  relative(date: Date): string {
    return formatDistanceToNow(date, { addSuffix: true })
  },

  short(date: Date): string {
    return format(date, 'MMM d, yyyy')
  }
}

// Usage
<template>
  <p>{{ dates.relative(user.lastSeen) }}</p>
</template>

// Why: If we swap date-fns for dayjs later, change one file
```

**Define Internal Standards When Ecosystem Lacks One:**

```typescript
// ✅ GOOD: Standard error handling across app
// utils/errors.ts
export interface AppError {
  code: string
  message: string
  details?: Record<string, unknown>
}

export function handleApiError(error: unknown): AppError {
  if (axios.isAxiosError(error)) {
    return {
      code: error.response?.data?.code ?? 'NETWORK_ERROR',
      message: error.response?.data?.message ?? 'Network request failed',
      details: error.response?.data
    }
  }

  return {
    code: 'UNKNOWN_ERROR',
    message: error instanceof Error ? error.message : 'An error occurred'
  }
}

// Usage in components
<script setup lang="ts">
import { handleApiError } from '@/utils/errors'

async function loadUsers() {
  try {
    await userStore.fetchUsers()
  } catch (error) {
    const appError = handleApiError(error)
    showError(appError.message)
  }
}
</script>
```

**Avoid Coupling UI to Business Rules:**

```typescript
// ❌ BAD: Business rule embedded in component
<script setup lang="ts">
const canDeleteUser = computed(() => {
  return user.value.role !== 'admin' && user.value.createdBy === currentUser.value.id
})
</script>

// ✅ GOOD: Business rule in service/composable
// services/userPermissions.ts
export function canDeleteUser(user: User, currentUser: User): boolean {
  return user.role !== 'admin' && user.createdBy === currentUser.id
}

// Usage in component
<script setup lang="ts">
import { canDeleteUser } from '@/services/userPermissions'

const canDelete = computed(() => canDeleteUser(user.value, currentUser.value))
</script>
```

---

## State Management Details

**Pinia Patterns:**

### Store Organization

```typescript
// ✅ GOOD: One store per domain entity
stores/
├── user.ts          # User authentication, profile
├── projects.ts      # Project CRUD
├── notifications.ts # Notifications
└── ui.ts           # UI state (sidebar, theme)

// ❌ BAD: Monolithic store
stores/
└── index.ts        # Everything in one file
```

### Store Structure (Setup Syntax)

```typescript
// stores/projects.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Project } from '@/types'
import { projectsApi } from '@/services/api'

export const useProjectsStore = defineStore('projects', () => {
  // State
  const projects = ref<Project[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const activeProjects = computed(() =>
    projects.value.filter(p => p.status === 'active')
  )

  const projectById = computed(() => (id: string) =>
    projects.value.find(p => p.id === id)
  )

  // Actions
  async function fetchProjects() {
    loading.value = true
    error.value = null

    try {
      projects.value = await projectsApi.getAll()
    } catch (e) {
      error.value = 'Failed to load projects'
      throw e
    } finally {
      loading.value = false
    }
  }

  async function createProject(data: Omit<Project, 'id'>) {
    const newProject = await projectsApi.create(data)
    projects.value.push(newProject)
    return newProject
  }

  async function deleteProject(id: string) {
    await projectsApi.delete(id)
    projects.value = projects.value.filter(p => p.id !== id)
  }

  return {
    // State
    projects,
    loading,
    error,
    // Getters
    activeProjects,
    projectById,
    // Actions
    fetchProjects,
    createProject,
    deleteProject
  }
})
```

### Composables for Shared Logic

```typescript
// composables/useApi.ts
import { ref } from 'vue'
import type { Ref } from 'vue'

export function useApi<T>(apiCall: () => Promise<T>) {
  const data = ref<T | null>(null) as Ref<T | null>
  const loading = ref(false)
  const error = ref<Error | null>(null)

  async function execute() {
    loading.value = true
    error.value = null

    try {
      data.value = await apiCall()
    } catch (e) {
      error.value = e instanceof Error ? e : new Error('Unknown error')
      throw e
    } finally {
      loading.value = false
    }
  }

  return { data, loading, error, execute }
}

// Usage in component
<script setup lang="ts">
import { useApi } from '@/composables/useApi'
import { projectsApi } from '@/services/api'

const { data: projects, loading, error, execute: loadProjects } = useApi(
  () => projectsApi.getAll()
)

onMounted(loadProjects)
</script>

<template>
  <v-progress-linear v-if="loading" indeterminate />
  <v-alert v-else-if="error" type="error">{{ error.message }}</v-alert>
  <v-list v-else-if="projects">
    <v-list-item v-for="project in projects" :key="project.id">
      {{ project.name }}
    </v-list-item>
  </v-list>
</template>
```

### Persistence

```typescript
// ✅ GOOD: Persist user preferences
import { defineStore } from 'pinia'
import { ref, watch } from 'vue'

export const useUiStore = defineStore('ui', () => {
  const sidebarOpen = ref(
    localStorage.getItem('sidebarOpen') === 'true'
  )
  const theme = ref<'light' | 'dark'>(
    (localStorage.getItem('theme') as 'light' | 'dark') ?? 'light'
  )

  // Persist to localStorage
  watch(sidebarOpen, (value) => {
    localStorage.setItem('sidebarOpen', String(value))
  })

  watch(theme, (value) => {
    localStorage.setItem('theme', value)
  })

  return { sidebarOpen, theme }
})
```

---

## Data Fetching (TanStack Query)

**Standard:** All server state management uses TanStack Query (Vue Query).

**Why TanStack Query:**
- Automatic caching reduces API calls (cost savings)
- Automatic refetching keeps data fresh without manual logic
- Built-in loading/error states (less boilerplate)
- Reduces manual state management complexity
- Well-adopted in Vue community

**Note:** Pinia is for client state only (UI preferences, current selections). TanStack Query is for server state (API data).

---

### Installation & Setup

```typescript
// plugins/query.ts
import { VueQueryPlugin, QueryClient } from '@tanstack/vue-query'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,      // 5 minutes - data considered fresh
      gcTime: 10 * 60 * 1000,         // 10 minutes - cache garbage collection
      retry: false,                   // No automatic retries (override default)
      refetchOnWindowFocus: true,     // Refetch when user returns to tab
    },
  },
})

export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.vueApp.use(VueQueryPlugin, { queryClient })
})
```

**Configuration Rationale:**
- `staleTime: 5 min` - Balance freshness vs API costs
- `retry: false` - Fail fast, user can manually retry
- `refetchOnWindowFocus: true` - Keep data current when user returns

---

### Composable Pattern

**Structure:** `use{Resource}()` composables wrapping service functions

**Pattern:** Component → Composable → Service → API Client

```
Component (BookList.vue)
    ↓ uses
Composable (useBooks.ts)
    ↓ calls
Service (bookService.ts)
    ↓ calls
API Client (apiClient.ts - from openapi-fetch)
```

---

### List Query Pattern

**Use Case:** Fetching all resources (e.g., all books, all loans)

```typescript
// composables/useBooks.ts
import { useQuery } from '@tanstack/vue-query'
import { bookService } from '@/services/bookService'

export function useBooks() {
  return useQuery({
    queryKey: ['books'],
    queryFn: bookService.getAll,
    staleTime: 5 * 60 * 1000,
    retry: false,
  })
}
```

**Usage in Component:**

```vue
<script setup lang="ts">
import { useBooks } from '@/composables/useBooks'

const { data: books, isLoading, error, refetch } = useBooks()
</script>

<template>
  <div v-if="isLoading">Loading...</div>
  <div v-else-if="error">Error: {{ error.message }}</div>
  <v-list v-else>
    <v-list-item v-for="book in books" :key="book.id">
      {{ book.title }}
    </v-list-item>
  </v-list>
  <v-btn @click="refetch">Refresh</v-btn>
</template>
```

**Key Points:**
- `queryKey: ['books']` - Unique identifier for this query
- `queryFn: bookService.getAll` - Function that fetches data
- `staleTime: 5 * 60 * 1000` - Cache for 5 minutes
- `retry: false` - Override default retry behavior

---

### Single Item Query Pattern

**Use Case:** Fetching one specific resource by ID

```typescript
// composables/useBooks.ts
export function useBook(id: string) {
  return useQuery({
    queryKey: ['books', id],
    queryFn: () => bookService.getById(id),
    staleTime: 5 * 60 * 1000,
    enabled: !!id,  // Only run query if ID is provided
    retry: false,
  })
}
```

**Usage in Component:**

```vue
<script setup lang="ts">
import { useBook } from '@/composables/useBooks'

const route = useRoute()
const bookId = computed(() => route.params.id as string)

const { data: book, isLoading } = useBook(bookId.value)
</script>

<template>
  <v-card v-if="book">
    <v-card-title>{{ book.title }}</v-card-title>
    <v-card-text>{{ book.description }}</v-card-text>
  </v-card>
</template>
```

**Key Points:**
- `queryKey: ['books', id]` - Includes ID for unique cache entry
- `enabled: !!id` - Conditional execution (only runs when ID exists)
- Query automatically re-runs when `id` changes

---

### Parameterized Query Pattern

**Use Case:** Queries with dynamic parameters (filters, pagination, date ranges)

```typescript
// composables/useLoans.ts
import { useQuery } from '@tanstack/vue-query'
import { computed } from 'vue'
import type { Ref } from 'vue'
import { loanService } from '@/services/loanService'

export function useLoans(options?: { months?: Ref<number> | number }) {
  // Convert parameter to reactive value
  const monthsValue = computed(() => {
    if (!options?.months) return undefined
    return typeof options.months === 'number' ? options.months : options.months.value
  })

  return useQuery({
    // IMPORTANT: queryKey must be computed to react to parameter changes
    queryKey: computed(() => ['loans', { months: monthsValue.value }]),
    queryFn: () => loanService.getAll({ months: monthsValue.value }),
    staleTime: 5 * 60 * 1000,
    retry: false,
  })
}
```

**Usage in Component:**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { useLoans } from '@/composables/useLoans'

const months = ref(3)
const { data: loans, isLoading } = useLoans({ months })
</script>

<template>
  <v-select v-model="months" :items="[1, 3, 6, 12]" label="Months" />
  <v-list v-if="loans">
    <v-list-item v-for="loan in loans" :key="loan.id">
      {{ loan.bookTitle }}
    </v-list-item>
  </v-list>
</template>
```

**Key Points:**
- `queryKey` must be `computed()` to react to parameter changes
- Query automatically re-runs when `months` changes
- Cache entries per parameter combination (separate cache for months=3 vs months=6)

---

### Mutation Pattern

**Use Case:** Creating, updating, or deleting resources

```typescript
// composables/useCreateLoan.ts
import { useMutation, useQueryClient } from '@tanstack/vue-query'
import { loanService } from '@/services/loanService'
import type { CreateLoanParams } from '@/types'

export function useCreateLoan() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (params: CreateLoanParams) =>
      loanService.create(params),
    onSuccess: () => {
      // Invalidate loans query to trigger refetch
      queryClient.invalidateQueries({ queryKey: ['loans'] })
    },
  })
}
```

**Usage in Component:**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { useCreateLoan } from '@/composables/useCreateLoan'

const { mutateAsync: createLoan, isPending, error } = useCreateLoan()
const bookId = ref('')

async function handleSubmit() {
  try {
    await createLoan({ bookId: bookId.value })
    showSuccess('Loan created successfully')
  } catch (error) {
    // Error is available in the `error` reactive value
    showError('Failed to create loan')
  }
}
</script>

<template>
  <v-form @submit.prevent="handleSubmit">
    <v-text-field v-model="bookId" label="Book ID" />
    <v-btn type="submit" :loading="isPending">Create Loan</v-btn>
    <v-alert v-if="error" type="error">{{ error.message }}</v-alert>
  </v-form>
</template>
```

**Key Points:**
- `mutationFn` - Function that performs the mutation
- `onSuccess` - Invalidate related queries to refresh data
- `mutateAsync` - Returns promise for async/await
- `isPending` - Loading state during mutation

---

### Query Key Structure

**Conventions:**

| Pattern | Query Key | Example |
|---------|-----------|---------|
| **List all** | `['resource']` | `['books']`, `['loans']` |
| **Single item** | `['resource', id]` | `['books', '123']` |
| **With params** | `['resource', { param: value }]` | `['loans', { months: 3 }]` |

**Library Scoping:**
- Library context is injected via API client middleware (X-Library-Id header)
- Query keys do NOT include `libraryId` (automatic scoping via header)
- Exception: If a resource explicitly spans multiple libraries

**Examples:**

```typescript
// ✅ GOOD: Consistent structure
queryKey: ['books']                        // All books
queryKey: ['books', bookId]                // Single book
queryKey: ['loans', { months: 3 }]         // Parameterized query
queryKey: ['books', { status: 'available' }]  // Filtered query

// ❌ BAD: Inconsistent structure
queryKey: ['getAllBooks']                  // Don't include verb in key
queryKey: ['book-123']                     // Don't concatenate ID
queryKey: ['books', libraryId, bookId]     // Don't include libraryId (automatic)
```

**Why Structure Matters:**
- Consistent keys enable efficient cache invalidation
- TanStack Query can invalidate related queries by prefix
- Example: `invalidateQueries({ queryKey: ['books'] })` invalidates ALL book queries

---

### Service Layer Integration

**Pattern:** Composables call service functions, services call API client

```typescript
// services/bookService.ts
import { apiClient } from './apiClient'
import type { Book } from '@/types'

function getLibraryId(): string {
  const libraryStore = useLibraryStore()
  if (!libraryStore.currentLibraryId) {
    throw new Error('No library selected')
  }
  return libraryStore.currentLibraryId
}

export const bookService = {
  async getAll(): Promise<Book[]> {
    const { data, error } = await apiClient.GET('/api/books')
    if (error) {
      throw new Error(error.detail || 'Failed to fetch books')
    }
    return data || []
  },

  async getById(id: string): Promise<Book> {
    const { data, error } = await apiClient.GET('/api/books/{id}', {
      params: { path: { id } },
    })
    if (error) {
      throw new Error(error.detail || 'Book not found')
    }
    return data!
  },

  async create(book: Omit<Book, 'id'>): Promise<Book> {
    const libraryId = getLibraryId()
    const { data, error } = await apiClient.POST('/api/books', {
      body: { ...book, libraryId },
    })
    if (error) {
      throw new Error(error.detail || 'Failed to create book')
    }
    return data!
  },
}
```

**API Client (openapi-fetch):**

```typescript
// services/apiClient.ts
import createClient from 'openapi-fetch'
import type { paths } from '@/types/api' // Auto-generated from OpenAPI spec

export const apiClient = createClient<paths>({
  baseUrl: import.meta.env.VITE_API_URL,
})

// Middleware: Inject library ID header
apiClient.use({
  async onRequest({ request }) {
    const libraryStore = useLibraryStore()
    if (libraryStore.currentLibraryId) {
      request.headers.set('X-Library-Id', libraryStore.currentLibraryId)
    }
    return request
  },
})
```

**Key Points:**
- Services handle business logic (library context, error mapping)
- API client handles HTTP communication
- Type safety from OpenAPI spec to service to composable to component

---

### Testing Pattern

**Mock Query Results:**

```typescript
// test/mocks/vueQuery.ts
import type { UseQueryReturnType } from '@tanstack/vue-query'
import { ref } from 'vue'
import { vi } from 'vitest'

export interface MockQueryResult<T> {
  data: T | undefined
  isLoading: boolean
  isError: boolean
  error: Error | null
  refetch: () => void
}

export function createMockQueryResult<T>(
  data?: T,
  overrides?: Partial<MockQueryResult<T>>
): MockQueryResult<T> {
  return {
    data,
    isLoading: false,
    isError: false,
    error: null,
    refetch: vi.fn(),
    ...overrides,
  }
}

// Helper for common scenarios
export function mockUseBooks(books?: Book[]) {
  return createMockQueryResult(books)
}

export function mockUseBooksLoading() {
  return createMockQueryResult(undefined, { isLoading: true })
}

export function mockUseBooksError(error = new Error('Failed to fetch')) {
  return createMockQueryResult(undefined, { isError: true, error })
}
```

**Component Test:**

```typescript
// components/BookList.spec.ts
import { mount } from '@vue/test-utils'
import { describe, it, expect, vi } from 'vitest'
import BookList from './BookList.vue'
import { mockUseBooks, mockUseBooksLoading } from '@/test/mocks/vueQuery'

vi.mock('@/composables/useBooks', () => ({
  useBooks: vi.fn(() => mockUseBooks([
    { id: '1', title: 'Book 1', author: 'Author 1' },
    { id: '2', title: 'Book 2', author: 'Author 2' },
  ])),
}))

describe('BookList', () => {
  it('renders books', () => {
    const wrapper = mount(BookList)
    expect(wrapper.text()).toContain('Book 1')
    expect(wrapper.text()).toContain('Book 2')
  })

  it('shows loading state', () => {
    vi.mocked(useBooks).mockReturnValue(mockUseBooksLoading())
    const wrapper = mount(BookList)
    expect(wrapper.text()).toContain('Loading')
  })
})
```

**Key Points:**
- Mock composables, not TanStack Query internals
- Use factory functions for common scenarios
- Test loading, error, and success states

---

### When to Use TanStack Query

**Always use for:**
- ✅ API data that needs caching (books, users, loans)
- ✅ List queries (fetching multiple resources)
- ✅ Single item queries with ID
- ✅ Mutations that affect cached data (with `invalidateQueries`)

**Do NOT use for:**
- ❌ Client-only state (UI preferences, form state) → Use Pinia or `ref`
- ❌ One-time operations with no caching benefit → Direct service call
- ❌ File downloads (blob responses) → Direct fetch
- ❌ Complex auth flows (multiple steps, non-API operations) → Direct service call

**Example - When NOT to Use:**

```typescript
// ❌ BAD: Client state in TanStack Query
const { data: sidebarOpen } = useQuery({
  queryKey: ['ui', 'sidebar'],
  queryFn: () => localStorage.getItem('sidebarOpen') === 'true',
})

// ✅ GOOD: Client state in Pinia
const uiStore = useUiStore()
const sidebarOpen = computed(() => uiStore.sidebarOpen)
```

---

### Standard Configuration

**Every query should use:**

```typescript
{
  staleTime: 5 * 60 * 1000,  // 5 minutes (balance freshness vs cost)
  retry: false,               // No automatic retries (fail fast)
  enabled: !!param,           // Conditional queries (when applicable)
}
```

**Every mutation should consider:**

```typescript
{
  onSuccess: () => {
    // Invalidate related queries to refresh data
    queryClient.invalidateQueries({ queryKey: ['resource'] })
  },
}
```

---

### Cache Invalidation

**After mutations, invalidate related queries:**

```typescript
// composables/useCreateBook.ts
export function useCreateBook() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (book: CreateBookParams) =>
      bookService.create(book),
    onSuccess: () => {
      // Invalidate ALL book queries (list and individual items)
      queryClient.invalidateQueries({ queryKey: ['books'] })
    },
  })
}
```

**Invalidation Strategies:**

| Scenario | Invalidation |
|----------|--------------|
| **Create book** | `invalidateQueries({ queryKey: ['books'] })` |
| **Update book** | `invalidateQueries({ queryKey: ['books'] })` (invalidates list + single item) |
| **Delete book** | `invalidateQueries({ queryKey: ['books'] })` |
| **Related resources** | Invalidate multiple: `['books']`, `['loans']` |

**Granular Invalidation:**

```typescript
// Invalidate specific item only
queryClient.invalidateQueries({ queryKey: ['books', bookId] })

// Invalidate all books (list + all items)
queryClient.invalidateQueries({ queryKey: ['books'] })
```

**Why Invalidate Instead of Update Cache Directly:**
- Simpler code (no manual cache manipulation)
- Refetch ensures data consistency with server
- Automatic for related queries

---

### Advanced Patterns

**Dependent Queries:**

```typescript
// composables/useLoanDetails.ts
export function useLoanDetails(loanId: string) {
  // First query: Get loan
  const { data: loan } = useQuery({
    queryKey: ['loans', loanId],
    queryFn: () => loanService.getById(loanId),
    staleTime: 5 * 60 * 1000,
    retry: false,
  })

  // Second query: Get associated book (depends on loan)
  const { data: book } = useQuery({
    queryKey: computed(() => ['books', loan.value?.bookId]),
    queryFn: () => bookService.getById(loan.value!.bookId),
    enabled: computed(() => !!loan.value?.bookId), // Only run when loan loaded
    staleTime: 5 * 60 * 1000,
    retry: false,
  })

  return { loan, book }
}
```

**Parallel Queries:**

```typescript
// composables/useDashboard.ts
export function useDashboard() {
  const books = useBooks()
  const loans = useLoans()
  const members = useMembers()

  const isLoading = computed(() =>
    books.isLoading || loans.isLoading || members.isLoading
  )

  return { books, loans, members, isLoading }
}
```

---

### Migration from Direct Service Calls

**Before (Direct Service + Pinia):**

```typescript
// services/libraryService.ts
export async function loadLibraries() {
  const store = useLibraryStore()
  store.setLoading(true)

  try {
    const { data } = await apiClient.GET('/api/libraries')
    store.setLibraries(data || [])
  } catch (error) {
    store.setError('Failed to load libraries')
  } finally {
    store.setLoading(false)
  }
}

// Component
onMounted(async () => {
  await loadLibraries()
})
```

**After (TanStack Query):**

```typescript
// composables/useLibraries.ts
export function useLibraries() {
  return useQuery({
    queryKey: ['libraries'],
    queryFn: libraryService.getAll,
    staleTime: 5 * 60 * 1000,
    retry: false,
  })
}

// services/libraryService.ts
export const libraryService = {
  async getAll(): Promise<Library[]> {
    const { data, error } = await apiClient.GET('/api/libraries')
    if (error) {
      throw new Error('Failed to fetch libraries')
    }
    return data || []
  },
}

// Component
const { data: libraries, isLoading } = useLibraries()
```

**Benefits:**
- Less boilerplate (no manual loading/error state)
- Automatic caching (reduces API calls)
- Automatic refetching (keeps data fresh)
- Consistent pattern across codebase

---

### Troubleshooting

**Query not refetching when expected:**

```typescript
// ✅ GOOD: queryKey is computed, reacts to changes
queryKey: computed(() => ['loans', { months: months.value }])

// ❌ BAD: queryKey is static, won't react
queryKey: ['loans', { months: months.value }]  // Captures initial value only
```

**Cache not invalidating:**

```typescript
// ✅ GOOD: Invalidate by prefix (matches all book queries)
queryClient.invalidateQueries({ queryKey: ['books'] })

// ❌ BAD: Exact match only (doesn't invalidate ['books', '123'])
queryClient.invalidateQueries({ queryKey: ['books'], exact: true })
```

**Stale data showing:**

```typescript
// Check staleTime configuration
staleTime: 5 * 60 * 1000  // 5 minutes

// Force refetch
const { refetch } = useBooks()
refetch()

// Or invalidate cache
queryClient.invalidateQueries({ queryKey: ['books'] })
```

---

## OpenAPI Code Generation

**Standard:** All API types are auto-generated from the backend OpenAPI specification using `openapi-typescript`.

**Why Auto-Generation:**
- Single source of truth (backend defines types)
- Compile-time type safety (catch API mismatches before runtime)
- IDE autocomplete for all endpoints
- No manual type drift
- Automatic sync with backend changes

---

### Architecture Overview

```
Backend (C# / .NET)
    ↓ builds
OpenAPI Spec (openapi.json)
    ↓ generates via openapi-typescript
TypeScript Types (api.d.ts)
    ↓ used by
API Client (openapi-fetch)
    ↓ wrapped by
Service Layer (bookService, etc.)
    ↓ called by
TanStack Query Composables
    ↓ used by
Components
```

---

### Backend OpenAPI Generation

**Configuration in `LibraryService.csproj`:**

```xml
<PropertyGroup>
  <GenerateDocumentationFile>true</GenerateDocumentationFile>
  <NoWarn>$(NoWarn);1591</NoWarn>

  <!-- Build-time OpenAPI generation -->
  <OpenApiDocumentsDirectory>../../api/LibraryService</OpenApiDocumentsDirectory>
  <OpenApiGenerateDocumentsOptions>--file-name openapi</OpenApiGenerateDocumentsOptions>
  <OpenApiGenerateDocumentsOnBuild>true</OpenApiGenerateDocumentsOnBuild>
</PropertyGroup>
```

**Packages:**
- `Microsoft.AspNetCore.OpenApi` (v9.0.0)
- `Swashbuckle.AspNetCore` (v9.0.6)
- `Microsoft.Extensions.ApiDescription.Server` (build-time generation)

**Output:**
- `api/LibraryService/openapi.json` - Generated during `dotnet build`

---

### Frontend Type Generation

**NPM Script in `package.json`:**

```json
{
  "scripts": {
    "generate:api": "openapi-typescript ../../api/LibraryService/openapi.json -o src/services/generated/api.d.ts"
  },
  "devDependencies": {
    "openapi-typescript": "^7.10.1"
  },
  "dependencies": {
    "openapi-fetch": "^0.15.0"
  }
}
```

**Generated File:**
- `src/services/generated/api.d.ts` - **DO NOT EDIT MANUALLY**
- Contains `paths` interface (all endpoints) and `components` interface (schemas)

**Generated Types Structure:**

```typescript
// Auto-generated api.d.ts
export interface paths {
  "/api/books": {
    get: operations["GetBooks"];
    parameters: { query?: never; header?: never; path?: never; };
  };
  "/api/{libraryId}/loans": {
    get: operations["ListLoans"];
    parameters: { path: { libraryId: string } };
  };
  // ... all endpoints
}

export interface components {
  schemas: {
    "Response": { bookId: string; title: string; author: string; ... };
    "Response6": { loanId: string; bookTitle: string; ... };
    // ... all schemas
  };
}
```

---

### API Client Setup

**File: `src/services/apiClient.ts`**

```typescript
import createClient from 'openapi-fetch'
import type { paths, components } from './generated/api'

const API_BASE_URL = import.meta.env.VITE_API_URL

export const apiClient = createClient<paths>({
  baseUrl: API_BASE_URL,
  credentials: 'include',  // For httpOnly cookies
})

// Middleware: Inject library ID header
apiClient.use({
  async onRequest({ request }) {
    const libraryStore = useLibraryStore()
    if (libraryStore.currentLibraryId) {
      request.headers.set('X-Library-Id', libraryStore.currentLibraryId)
    }
    return request
  },

  async onResponse({ response }) {
    // Auto-redirect to login on 401
    if (response.status === 401) {
      const userStore = useUserStore()
      await userStore.logout()
      router.push({ name: 'auth-login' })
    }
    return response
  },
})

// Re-export commonly used types
export type Loan = components['schemas']['Response6']
export type Book = components['schemas']['Response']
export type Membership = components['schemas']['Response9']
export type { paths, components }
```

**Key Features:**
- `createClient<paths>()` provides full type safety for all endpoints
- Middleware injects headers automatically (library context)
- Auto-handles authentication failures (401 → login redirect)
- `credentials: 'include'` for httpOnly cookie auth

---

### Service Layer Integration

**Pattern: Domain-specific services wrapping apiClient**

```typescript
// services/bookService.ts
import { apiClient } from './apiClient'
import type { Book } from './apiClient'

export const bookService = {
  async getAll(): Promise<Book[]> {
    const { data, error } = await apiClient.GET('/api/books')
    if (error) {
      throw new Error(error.detail || 'Failed to fetch books')
    }
    return data || []
  },

  async getById(id: string): Promise<Book> {
    const { data, error } = await apiClient.GET('/api/books/{id}', {
      params: { path: { id } },
    })
    if (error) {
      throw new Error(error.detail || 'Book not found')
    }
    return data!
  },

  async create(book: Omit<Book, 'id'>): Promise<Book> {
    const { data, error } = await apiClient.POST('/api/books', {
      body: book,
    })
    if (error) {
      throw new Error(error.detail || 'Failed to create book')
    }
    return data!
  },
}
```

**Error Handling Pattern:**

```typescript
const { data, error, response } = await apiClient.GET('/api/loans')

if (error) {
  // Handle specific status codes
  if (response.status === 404) {
    return null  // Resource not found
  }
  throw new Error(error.detail || 'Failed to fetch')
}

// data is guaranteed non-null here
return data
```

---

### Workflow: Regenerating Types After Backend Changes

**Step 1: Backend Changes**

When you modify the backend API (add endpoints, change schemas):

```bash
cd /workspaces/The First Keel

# Build backend (generates openapi.json)
dotnet build src/LibraryService/LibraryService.csproj

# OpenAPI spec written to:
# api/LibraryService/openapi.json
```

**Step 2: Frontend Type Regeneration**

```bash
cd app/LibraryService

# Regenerate TypeScript types
npm run generate:api

# This runs:
# openapi-typescript ../../api/LibraryService/openapi.json -o src/services/generated/api.d.ts
```

**Step 3: Verification**

```bash
# Type check the frontend
npm run type-check

# Run tests to catch breaking changes
npm run test

# Start dev server (if checks pass)
npm run dev
```

**When to Regenerate:**
- ✅ After adding new API endpoints
- ✅ After changing request/response schemas
- ✅ After modifying route parameters or query params
- ✅ After backend deployment (to sync with new API version)

---

### Type Safety Examples

**Endpoint Autocomplete:**

```typescript
// IDE autocomplete shows all available endpoints
await apiClient.GET('/api/books')       // ✅ Valid
await apiClient.GET('/api/loans')       // ✅ Valid
await apiClient.GET('/api/invalid')     // ❌ Type error

// Method validation
await apiClient.GET('/api/books')       // ✅ Valid (GET exists)
await apiClient.DELETE('/api/books')    // ❌ Type error (DELETE doesn't exist)
```

**Parameter Validation:**

```typescript
// Path parameters required and type-checked
await apiClient.GET('/api/books/{id}', {
  params: { path: { id: '123' } }  // ✅ Valid (string)
})

await apiClient.GET('/api/books/{id}', {
  params: { path: { id: 123 } }    // ❌ Type error (number, not string)
})

await apiClient.GET('/api/books/{id}')  // ❌ Type error (params missing)
```

**Request Body Validation:**

```typescript
await apiClient.POST('/api/books', {
  body: {
    title: 'New Book',
    author: 'Author Name',
    isbn: '978-0123456789'
  }  // ✅ Valid (matches schema)
})

await apiClient.POST('/api/books', {
  body: {
    title: 'New Book'
    // ❌ Type error (missing required fields)
  }
})
```

**Response Type Inference:**

```typescript
const { data } = await apiClient.GET('/api/books')

// TypeScript knows data is Book[] | undefined
if (data) {
  data.forEach(book => {
    console.log(book.title)      // ✅ Type-safe access
    console.log(book.invalid)    // ❌ Type error (property doesn't exist)
  })
}
```

---

### Common Patterns

**Library-Scoped Queries:**

```typescript
// Library ID automatically injected via middleware
// No need to pass libraryId in query parameters or path
const { data: loans } = await apiClient.GET('/api/loans')

// Backend receives X-Library-Id header, filters by library automatically
```

**Parameterized Queries:**

```typescript
const { data: loans } = await apiClient.GET('/api/loans', {
  params: {
    query: {
      months: 3,           // Type-safe query parameters
      status: 'active'
    }
  }
})
```

**File Downloads:**

```typescript
const { data } = await apiClient.GET('/api/invoices/{id}/pdf', {
  params: { path: { id: invoiceId } },
  parseAs: 'blob',  // Return blob instead of JSON
})

const url = URL.createObjectURL(data!)
const link = document.createElement('a')
link.href = url
link.download = `invoice-${invoiceId}.pdf`
link.click()
```

---

### Testing with Generated Types

**Mock Service Functions:**

```typescript
// test/services/bookService.spec.ts
import { describe, it, expect, vi } from 'vitest'
import { bookService } from '@/services/bookService'
import type { Book } from '@/services/apiClient'

vi.mock('@/services/apiClient', () => ({
  apiClient: {
    GET: vi.fn(),
    POST: vi.fn(),
  },
}))

describe('bookService', () => {
  it('fetches all books', async () => {
    const mockBooks: Book[] = [
      { id: '1', title: 'Book 1', author: 'Author 1' },
      { id: '2', title: 'Book 2', author: 'Author 2' },
    ]

    vi.mocked(apiClient.GET).mockResolvedValue({
      data: mockBooks,
      error: undefined,
      response: {} as Response,
    })

    const books = await bookService.getAll()
    expect(books).toEqual(mockBooks)
  })
})
```

---

### Troubleshooting

**Types not updating after backend changes:**

```bash
# 1. Rebuild backend
dotnet build src/LibraryService/LibraryService.csproj

# 2. Verify openapi.json updated
cat api/LibraryService/openapi.json | grep "yourNewEndpoint"

# 3. Regenerate frontend types
cd app/LibraryService
npm run generate:api

# 4. Restart TypeScript server in IDE
# VS Code: Cmd/Ctrl + Shift + P → "TypeScript: Restart TS Server"
```

**Type errors after regeneration:**

```typescript
// If backend response shape changed, update service functions:

// Before (old shape)
return data.items  // ❌ Type error (property doesn't exist)

// After (new shape)
return data.results  // ✅ Matches new schema
```

**Circular dependency errors:**

```typescript
// ❌ BAD: Import from generated file directly
import type { Book } from './generated/api'

// ✅ GOOD: Import from apiClient (re-exports types)
import type { Book } from './apiClient'
```

---

### File Locations

| File | Purpose | Edit? |
|------|---------|-------|
| `api/LibraryService/openapi.json` | Generated OpenAPI spec | ❌ Auto-generated |
| `app/LibraryService/src/services/generated/api.d.ts` | Generated TypeScript types | ❌ Auto-generated |
| `app/LibraryService/src/services/apiClient.ts` | Typed HTTP client + middleware | ✅ Manual |
| `app/LibraryService/src/services/bookService.ts` | Domain service (example) | ✅ Manual |
| `app/LibraryService/package.json` | `generate:api` script | ✅ Manual |
| `src/LibraryService/Program.cs` | Backend Swagger config | ✅ Manual |
| `src/LibraryService/LibraryService.csproj` | Build-time generation config | ✅ Manual |

---

### Best Practices

**DO:**
- ✅ Regenerate types after every backend API change
- ✅ Run `npm run type-check` before committing
- ✅ Use re-exported types from `apiClient.ts` (not `generated/api.d.ts`)
- ✅ Handle `error` cases in all API calls
- ✅ Document breaking API changes in commit messages

**DON'T:**
- ❌ Edit `generated/api.d.ts` manually (regenerated on next build)
- ❌ Import types directly from `generated/api.d.ts` (use `apiClient.ts`)
- ❌ Commit API changes without regenerating types
- ❌ Skip type checking before deployment
- ❌ Use `any` type to bypass type errors (fix the type instead)

---

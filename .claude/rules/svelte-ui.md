---
globs: ["ui/user/src/**/*.svelte"]
description: SvelteKit UI conventions - Svelte 5 runes, Profile component patterns
---

# SvelteKit UI Conventions (obot-entraid)

## Svelte 5 Runes (REQUIRED)

Always use Svelte 5 runes syntax:

| Rune | Purpose | Example |
|------|---------|---------|
| `$state()` | Reactive state | `let count = $state(0)` |
| `$derived()` | Computed values | `let doubled = $derived(count * 2)` |
| `$effect()` | Side effects | `$effect(() => { console.log(count) })` |
| `$props()` | Component props | `let { name } = $props<{ name: string }>()` |
| `$bindable()` | Two-way binding | `let { value = $bindable() } = $props()` |

## Component Structure

```svelte
<script lang="ts">
  // 1. Imports
  import { Component } from '$lib/components';
  import { api } from '$lib/services/api';

  // 2. Props (Svelte 5 runes)
  let { prop1, prop2 = 'default' } = $props<{
    prop1: string;
    prop2?: string;
  }>();

  // 3. State
  let loading = $state(false);
  let data = $state<MyType | null>(null);

  // 4. Derived
  let isValid = $derived(data !== null && !loading);

  // 5. Effects
  $effect(() => {
    if (prop1) {
      fetchData(prop1);
    }
  });

  // 6. Functions
  async function fetchData(id: string) {
    loading = true;
    data = await api.get(id);
    loading = false;
  }
</script>

<!-- Template -->
<div class="container">
  {#if loading}
    <Spinner />
  {:else if data}
    <Content {data} />
  {/if}
</div>

<style>
  /* Scoped styles - prefer Tailwind */
</style>
```

## File Organization

```
ui/user/src/
├── routes/           # SvelteKit file-based routing
│   ├── +page.svelte
│   ├── +layout.svelte
│   └── projects/
│       └── [id]/
│           └── +page.svelte
├── lib/
│   ├── components/   # Reusable components
│   │   ├── navbar/
│   │   │   ├── Navbar.svelte
│   │   │   └── Profile.svelte  # User profile (auth integration)
│   │   └── common/
│   ├── services/     # API clients
│   │   └── api.ts
│   └── stores/       # Shared state (minimal use with runes)
```

## Styling

- **Primary**: Tailwind CSS classes
- **Scoped**: `<style>` block for component-specific styles
- **Variables**: CSS custom properties for theming

```svelte
<div class="flex items-center gap-2 p-4 bg-surface-100 dark:bg-surface-900">
  <span class="text-primary-500">{name}</span>
</div>
```

## Profile Component Patterns

The Profile component (`lib/components/navbar/Profile.svelte`) handles:

1. **User avatar** - Uses `icon_url` from auth provider (base64 data URL)
2. **User name** - Uses `name` field from auth provider
3. **Sign out** - Redirects to `/oauth2/sign_out`

```svelte
<script lang="ts">
  import { user } from '$lib/stores/user';

  let { showDropdown = $bindable(false) } = $props();
</script>

{#if $user}
  <div class="profile">
    <img src={$user.icon_url} alt={$user.name} />
    <span>{$user.name}</span>
  </div>
{/if}
```

## API Integration

Use the typed API client from `$lib/services/api`:

```typescript
import { api } from '$lib/services/api';

// GET request
const project = await api.projects.get(id);

// POST request
const newThread = await api.threads.create(projectId, { name: 'New Thread' });
```

## Anti-Patterns

- **Don't use `let:` syntax** - Deprecated in Svelte 5
- **Don't use `$$props` or `$$restProps`** without typing
- **Don't mutate props directly** - Use callbacks or bindable
- **Don't use stores for local state** - Use `$state()` instead
- **Don't use `on:event`** - Use `onevent` (lowercase) in Svelte 5

```svelte
<!-- WRONG (Svelte 4) -->
<button on:click={handleClick}>Click</button>

<!-- CORRECT (Svelte 5) -->
<button onclick={handleClick}>Click</button>
```

## TypeScript

All components must use TypeScript:

```svelte
<script lang="ts">
  import type { Project } from '$lib/types';

  let { project } = $props<{ project: Project }>();
</script>
```

## Testing

```typescript
import { render, screen } from '@testing-library/svelte';
import Profile from './Profile.svelte';

test('displays user name', () => {
  render(Profile, {
    props: {
      user: { name: 'John', icon_url: 'data:image/...' }
    }
  });
  expect(screen.getByText('John')).toBeInTheDocument();
});
```

## Validation Commands

```bash
cd ui/user
pnpm run ci      # Run format, lint, and check
pnpm run check   # TypeScript type checking only
pnpm run lint    # ESLint + Prettier check
pnpm run format  # Auto-format code
```

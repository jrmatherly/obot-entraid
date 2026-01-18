# App Preferences & Branding Implementation

## Overview

The App Preferences system allows administrators to customize the visual appearance and branding of the obot platform. This includes theme colors, logos/icons, and footer branding.

## Architecture

### Data Flow

```
Admin UI → API Handler → K8s Storage (CRD) → Frontend Store → Components
```

### Key Files

**Backend (Go):**

- `apiclient/types/apppreferences.go` - API types (LogoPreferences, ThemePreferences, BrandingPreferences)
- `pkg/storage/apis/obot.obot.ai/v1/apppreferences.go` - K8s CRD spec
- `pkg/api/handlers/apppreferences.go` - CRUD handlers

**Frontend (Svelte):**

- `ui/user/src/lib/services/admin/types.ts` - TypeScript interfaces
- `ui/user/src/lib/stores/appPreferences.svelte.ts` - Reactive store with defaults
- `ui/user/src/lib/components/Thread.svelte` - Footer component using branding
- `ui/user/src/routes/admin/app-preferences/+page.svelte` - Admin configuration UI

## BrandingPreferences Structure

```go
type BrandingPreferences struct {
    ProductName    string `json:"productName,omitempty"`
    IssueReportURL string `json:"issueReportUrl,omitempty"`
    FooterMessage  string `json:"footerMessage,omitempty"`
    ShowFooter     *bool  `json:"showFooter,omitempty"`
}
```

```typescript
branding: {
    productName: string;
    issueReportUrl: string;
    footerMessage: string;
    showFooter: boolean;
}
```

## Default Values

Located in `ui/user/src/lib/stores/appPreferences.svelte.ts`:

```typescript
export const DEFAULT_BRANDING = {
    productName: 'Obot',
    issueReportUrl: 'https://github.com/jrmatherly/obot-entraid/issues/new?template=bug_report.md',
    footerMessage: "{productName} isn't perfect. Double check its work.",
    showFooter: true
} as const;
```

## Placeholder Support

The `footerMessage` field supports the `{productName}` placeholder, which is replaced at render time:

```svelte
{appPreferences.current.branding.footerMessage.replace(
    '{productName}',
    appPreferences.current.branding.productName
)}
```

## SSR Data Loading

App preferences are loaded server-side in the root layout:

- `ui/user/src/routes/+layout.ts` - Fetches preferences during SSR
- `compileAppPreferences()` - Merges API response with defaults

## API Endpoints

- `GET /api/admin/app-preferences` - Retrieve current preferences
- `PUT /api/admin/app-preferences` - Update preferences (creates if not exists)

## ESLint Configuration

External links in Svelte require disabling the navigation rule:

```svelte
<!-- eslint-disable svelte/no-navigation-without-resolve -- external issue report URL -->
<a href={appPreferences.current.branding.issueReportUrl} target="_blank" rel="noopener noreferrer">
    Report issues here
</a>
<!-- eslint-enable svelte/no-navigation-without-resolve -->
```

## Documentation

See `docs/docs/configuration/app-preferences.md` for user-facing documentation.

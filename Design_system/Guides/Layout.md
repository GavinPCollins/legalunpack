# Layout Guide

This guide explains how the Legalunpack application layout is organised, where its parts are stored, and how to use or adjust the available page layouts.

## Layout Overview

Every Rails page is rendered inside the main application layout:

```text
application.html.erb
  navigation and mobile header
  main.app-shell
    page view
      optional page header
      page content or details layout
```

The application layout owns the single `<main>` element. Individual page views should use `<section>`, `<article>`, `<div>`, and `<aside>` rather than adding another `<main>`.

## File Locations

### Main Application Layout

```text
app/views/layouts/application.html.erb
```

This file contains:

- The HTML document and `<head>`
- The signed-in desktop navigation
- The mobile navigation drawer and top bar
- The signed-out header
- The application `<main class="app-shell">`
- The main `<%= yield %>` where page views are inserted

Most pages use this layout automatically. A controller does not need to select it explicitly.

### Details Page Wrapper

```text
app/views/layouts/_details_page.html.erb
```

This reusable partial creates:

- A flexible main content column
- An optional sticky panel on the right
- Responsive spacing and maximum page width

It is currently used by:

```text
app/views/packages/show.html.erb
app/views/doc_files/summary.html.erb
```

### Header Components

Header components are stored together in:

```text
app/views/components/headers/
```

Available headers:

```text
_header_main.html.erb
_header_item.html.erb
_section_header.html.erb
```

Render them without the leading underscore or file extension:

```erb
<%= render "components/headers/header_main",
      page_header: "Packages" %>
```

```erb
<%= render "components/headers/header_item",
      item_title: @package.name.presence || "Untitled package" %>
```

```erb
<%= render "components/headers/section_header" %>
```

`_section_header.html.erb` is currently an empty placeholder. Define its accepted local variables before using it across pages, then add a dedicated guide for those options.

Check the individual header guides for their supported options:

```text
Design_system/Guides/Main_header.md
Design_system/Guides/Item_header.md
```

### Shared Layout Styling

```text
app/assets/tailwind/components/page_layout.css
```

This file defines shared classes including:

- `.side-nav-desktop`
- `.app-shell`
- `.mobile-top-bar`
- `.mobile-sidebar-shell`
- `.side-nav-inner`
- `.page-main`
- `.page-item`
- `.content`

## Standard Page Layout

Use the normal application layout for pages that only need one content column.

```erb
<div class="page-main">
  <%= render "components/headers/header_main",
        page_header: "New Package",
        page_subheader: "Upload the legal files you want to review." %>

  <section class="content">
    Page content
  </section>
</div>
```

The `page-main` class currently limits the page to `600px`:

```css
.page-main {
  @apply mx-auto w-full max-w-[600px] px-6 py-8;
}
```

Change `max-w-[600px]` when standard pages should be wider or narrower.

## Details Page Layout

Use the details wrapper when a page needs:

- Scrollable primary content
- A right-hand information or actions panel
- A panel that remains visible while the page scrolls

### Basic Usage

First capture the right panel:

```erb
<% details_panel = capture do %>
  <div class="space-y-4 border-l border-neutral-200 pl-6">
    <section class="rounded-md border border-neutral-200 bg-white p-4">
      <h2 class="text-sm font-semibold text-neutral-950">Details</h2>
      <p class="mt-2 text-sm text-neutral-600">Panel content</p>
    </section>
  </div>
<% end %>
```

Then render the wrapper as a partial layout:

```erb
<%= render layout: "layouts/details_page",
      locals: { panel: details_panel } do %>
  <section class="content">
    Main page content
  </section>
<% end %>
```

The `layout:` syntax is important because the partial wraps the block containing the main page content.

### Complete Page Structure

```erb
<div class="page-item">
  <%= render "components/headers/header_item",
        item_title: "Page title",
        item_subheader: "Supporting information" %>

  <% details_panel = capture do %>
    <div class="space-y-4 border-l border-neutral-200 pl-6">
      <section class="rounded-md border border-neutral-200 bg-white p-4">
        <h2 class="text-sm font-semibold text-neutral-950">Details</h2>
        Right panel content
      </section>
    </div>
  <% end %>

  <%= render layout: "layouts/details_page",
        locals: { panel: details_panel } do %>
    <section class="content">
      Main content
    </section>
  <% end %>
</div>
```

### Page Without a Right Panel

The panel is optional:

```erb
<%= render layout: "layouts/details_page",
      locals: { panel: nil } do %>
  <section class="content">
    Full-width content
  </section>
<% end %>
```

## Details Layout Styling

The wrapper currently uses:

```erb
<div class="mx-auto flex w-full max-w-7xl items-start gap-8 px-6 py-8">
```

Important classes:

| Class | Purpose |
| --- | --- |
| `max-w-7xl` | Sets the maximum width of the two-column area |
| `items-start` | Aligns the main content and panel at the top |
| `gap-8` | Controls the space between the columns |
| `px-6` | Adds horizontal page padding |
| `py-8` | Adds vertical page padding |
| `min-w-0 flex-1` | Allows the main column to fill the remaining space without overflowing |

The right panel currently uses:

```erb
<aside class="sticky top-8 hidden max-h-[calc(100vh-4rem)] w-80 shrink-0 overflow-y-auto xl:block">
```

Important classes:

| Class | Purpose |
| --- | --- |
| `sticky` | Keeps the panel visible while the page scrolls |
| `top-8` | Leaves `2rem` between the panel and the top of the viewport |
| `w-80` | Sets the panel width to `20rem` |
| `shrink-0` | Prevents the panel from becoming narrower |
| `max-h-[calc(100vh-4rem)]` | Keeps the panel within the viewport height |
| `overflow-y-auto` | Lets long panel content scroll internally |
| `hidden xl:block` | Hides the panel below the `xl` breakpoint |

### Show the Panel on Smaller Screens

The panel currently appears at Tailwind's `xl` breakpoint, normally `1280px` and wider:

```erb
hidden xl:block
```

To show it from the `lg` breakpoint, normally `1024px` and wider:

```erb
hidden lg:block
```

### Change the Panel Width

Current width:

```erb
w-80
```

Common alternatives:

```text
w-72    narrower
w-80    current width
w-96    wider
```

### Change the Sticky Offset

Current offset:

```erb
top-8
```

For more room above the panel:

```erb
top-12
```

When changing the offset, update the maximum height calculation to leave similar space above and below the panel.

## Application Shell Styling

The signed-in desktop navigation and application content are connected through these classes:

```css
.side-nav-desktop {
  @apply hidden lg:fixed lg:inset-y-0 lg:z-50 lg:flex lg:w-72 lg:flex-col;
}

.app-shell {
  @apply min-w-0 w-full lg:ml-72 lg:w-[calc(100%-18rem)];
}
```

The sidebar is `w-72`, which equals `18rem`. The application shell therefore uses:

```text
lg:ml-72
lg:w-[calc(100%-18rem)]
```

If the desktop sidebar width changes, update all three values together:

1. Sidebar width
2. Application shell left margin
3. Width calculation

For example, a `w-64` sidebar would require:

```css
.side-nav-desktop {
  @apply ... lg:w-64 ...;
}

.app-shell {
  @apply ... lg:ml-64 lg:w-[calc(100%-16rem)];
}
```

## Content Card Styling

The shared `.content` class is defined in `page_layout.css`:

```css
.content {
  @apply flex w-full flex-col bg-white rounded-lg p-6 text-cyan-950;
  @apply border border-neutral-200 border-t-6 border-t-cyan-600;
}
```

Adjust this class to change all shared content cards at once.

Examples:

- Change `p-6` to adjust internal spacing
- Change `rounded-lg` to adjust corner radius
- Change `border-t-cyan-600` to adjust the accent colour
- Remove `border-t-6` and `border-t-cyan-600` to remove the top accent
- Change `bg-white` to adjust the content background

Use page-specific Tailwind classes directly in the page view when a change should apply to only one page.

## Responsive Behaviour

### Below `lg`

- The desktop sidebar is hidden
- The mobile top bar is visible
- The sidebar opens as a mobile drawer
- Standard page content uses the full available width
- The details panel is hidden

### From `lg`

- The fixed desktop sidebar appears
- The mobile top bar is hidden
- `.app-shell` moves right to make room for the sidebar

### From `xl`

- The details page right panel appears
- Main content and the panel display side by side

## Adding the Details Layout to Another Page

1. Keep the page inside the existing `application.html.erb` layout.
2. Do not add another `<main>` element.
3. Render the appropriate page or item header.
4. Capture the right panel content.
5. Render `layouts/details_page` using the `layout:` option.
6. Put the main page content inside the render block.

Example:

```erb
<% panel = capture do %>
  <section class="rounded-md border border-neutral-200 bg-white p-4">
    Panel content
  </section>
<% end %>

<%= render layout: "layouts/details_page",
      locals: { panel: panel } do %>
  <article class="content">
    Main content
  </article>
<% end %>
```

## Troubleshooting

### The Right Panel Is Not Visible

Check:

- The browser is at least `1280px` wide
- The panel variable contains content
- The partial is rendered with `locals: { panel: panel }`
- Tailwind is rebuilding after class changes

To show the panel sooner, replace `xl:block` with `lg:block`.

### The Page Has Nested Main Elements

Do not add `<main>` inside a page view. The application layout already provides it:

```erb
<main class="app-shell">
  <%= yield %>
</main>
```

Use `<section>` or `<article>` for the main content inside a page.

### The Header Partial Cannot Be Found

Use the full current component path:

```erb
components/headers/header_main
components/headers/header_item
components/headers/section_header
```

Do not use the old paths:

```erb
components/header_main
components/header_item
```

### Sticky Positioning Does Not Work

Sticky positioning can be affected by ancestor elements with restrictive `overflow` styles. Check that the panel's parent containers do not use `overflow-hidden`, `overflow-auto`, or a fixed height unless that scrolling behaviour is intentional.

# Badge and Pill

Use the shared component for filled badges and outlined pills.

## Filled Badge

```erb
<%= render "components/badge", label: "High priority", variant: :warning %>
```

Equivalent classes:

```html
<span class="badge badge-warning">High priority</span>
```

## Pill

Pills are transparent with cyan text and border by default.

```erb
<%= render "components/badge", label: "Open", style: :pill %>
```

Equivalent classes:

```html
<span class="pill">Open</span>
```

Use `pill-neutral` for the neutral palette:

```html
<span class="pill pill-neutral">Open</span>
```

Combine `pill` with a badge variant for matching text and border colors without a background:

```erb
<%= render "components/badge", label: "High priority", style: :pill, variant: :warning %>
```

```html
<span class="pill badge-warning">High priority</span>
```

Available variants:

- `neutral`
- `success`
- `warning`
- `danger`
- `info`

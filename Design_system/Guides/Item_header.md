# Item Header

Partial:

```erb
<%= render "components/headers/header_item",
      parent_label: "Packages",
      parent_path: packages_path,
      item_title: @package.name.presence || "Untitled package" %>
```

### Parent Return

Use `parent_label` and `parent_path` when the item header should show a return link above the main header row.

```erb
<%= render "components/headers/header_item",
      parent_label: "Packages",
      parent_path: packages_path,
      item_title: @package.name.presence || "Untitled package" %>
```

### Package Name

Use `item_title` for the item or package name shown on the left side of the header. Use `item_subheader` for helper text below the heading.

```erb
<%= render "components/headers/header_item",
      item_title: @package.name.presence || "Untitled package",
      item_subheader: "Created #{ @package.created_at.to_fs(:long)}" %>
```

### Badge

Use `badge_label` to show a badge next to the item title. The `badge` class is always included, and `badge_class` adds the item-specific style.

```erb
<%= render "components/headers/header_item",
      item_title: "Matter review",
      badge_label: "Open",
      badge_class: "badge-succsses" %>
```

### Search

Use the search options when the item header search should point to a real page.

```erb
<%= render "components/headers/header_item",
      item_title: @package.name.presence || "Untitled package",
      search_path: packages_path,
      search_name: :q,
      search_value: @query,
      search_placeholder: "Search packages",
      search_label: "Search packages" %>
```

The search form opens a drawer on submit by default. Use the drawer options to adjust its copy.

```erb
<%= render "components/headers/header_item",
      item_title: @package.name.presence || "Untitled package",
      search_drawer_title: "Search package",
      search_drawer_body: "Package search results will appear here." %>
```

Disable the drawer when the search form should submit normally.

```erb
<%= render "components/headers/header_item",
      item_title: @package.name.presence || "Untitled package",
      show_search_drawer: false %>
```

### AI Chat

The AI chat button shows by default. Leave out `ai_chat_path` while the feature is only a placeholder, or add a path once the chat page/action exists.

```erb
<%= render "components/headers/header_item",
      ai_chat_path: root_path %>
```

```erb
<%= render "components/headers/header_item",
      show_ai_chat: false %>
```

### Overflow Actions

Use `overflow_actions` to choose which items show in the overflow menu.

```erb
<%= render "components/headers/header_item",
      item_title: @package.name.presence || "Untitled package",
      overflow_actions: [
        { label: "Rename package", type: :button, data: { action: "modal#open", modal_dialog_param: "rename" } },
        { label: "Add documents", type: :button, data: { action: "modal#open", modal_dialog_param: "documents" } },
        {
          label: "Delete package",
          path: package_path(@package),
          method: :delete,
          danger: true,
          form: { data: { turbo_confirm: "Delete #{@package.name.presence || "this package"}?" } }
        }
      ] %>
```

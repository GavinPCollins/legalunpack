# Item Header

Partial:

```erb
<%= render "components/header_item" %>
```

### Search

Use the search options when the item header search should point to a real page.

```erb
<%= render "components/header_item",
      search_path: packages_path,
      search_name: :q,
      search_value: @query,
      search_placeholder: "Search packages",
      search_label: "Search packages" %>
```

### Notifications

Notifications show by default. Add a path to make the icon a link, or hide it when the page should not show notifications.

```erb
<%= render "components/header_item",
      notification_path: root_path %>
```

```erb
<%= render "components/header_item",
      show_notifications: false %>
```

### Profile

The profile name defaults to the signed-in user name or username. Pass profile values when the header needs custom account details.

```erb
<%= render "components/header_item",
      profile_name: current_user.name,
      profile_image_url: current_user.avatar_url,
      profile_links: [
        { label: "Your profile", path: edit_user_registration_path },
        { label: "Sign out", path: destroy_user_session_path, method: :delete }
      ] %>
```

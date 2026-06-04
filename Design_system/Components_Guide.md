# Components Guide

Usage notes for reusable view components.

## Page

### page wrapper
 wrap the oage with the type of page

 ```erb
 <div class="page-main">
 </div>
 ```


## Main Header

Partial:

```erb
<%= render "components/header_main", page_header: "Search Packages" %>
```

### Title Only

Use this when the page only needs a heading.

```erb
<%= render "components/header_main",
      page_header: "Search Packages" %>
```

### Title With Helper Text

Use `page_subheader` for a short description below the heading.

```erb
<%= render "components/header_main",
      page_header: "Create Package",
      page_subheader: "Upload the legal files you want to review." %>
```

### Back Link

Use `back_label` and `back_path` when the page should show a back link above the heading.

```erb
<%= render "components/header_main",
      page_header: @package.name.presence || "Package",
      back_label: "Back to packages",
      back_path: packages_path %>
```

### Action Buttons

The header supports three optional action button styles:

- `borderless`
- `secondary`
- `primary`

Leave out any label/path pair when that button should not render.

```erb
<%= render "components/header_main",
      page_header: "Page title",
      borderless_label: "Delete",
      borderless_path: package_path(@package),
      borderless_method: :delete,
      secondary_label: "Edit",
      secondary_path: edit_package_path(@package),
      primary_label: "New package",
      primary_path: new_package_path %>
```

### Button Methods

Button methods default to `:get`.

Only add a method when the action needs a different HTTP verb:

```erb
borderless_method: :delete
secondary_method: :patch
primary_method: :post
```

### Form Submit Primary Button

Use `primary_type: :submit` when the primary header button should submit a form instead of linking to another page.

>Importent - placment of `form_with` and `render` commends
* The form with commend (see below) most be ABOVE the render header
  - Example:
  ```erb
  <%= form_with model: @package, html: { multipart: true }, class: "upload-form", data: { controller: "file-upload" } do |form| %>
  <%= render "components/header_main",
        page_header: "New Package",
        borderless_label: "Reset",
        borderless_path: root_path,
        primary_label: "Create",
        primary_type: :submit %>
  ```

* If the header is outside the form, add an id to the form and pass the same id as `primary_form_id`.
  - Example:
  ```erb
  <%= render "components/header_main",
        page_header: "New Package",
        borderless_label: "Reset",
        borderless_path: root_path,
        primary_label: "Create",
        primary_type: :submit,
        primary_form_id: "new-package-form" %>

  <%= form_with model: @package, html: { id: "new-package-form" } do |form| %>
    ...
  <% end %>
  ```

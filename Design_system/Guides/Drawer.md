# Drawer

Use a drawer when supporting content should slide over the current page without sending the user to a new screen.

This project currently uses two drawer patterns:

- Native `<dialog>` drawers for content panels like search, AI chat, and high-risk clauses.
- A class-toggled mobile sidebar drawer for navigation.

For most new drawers, use the native `<dialog>` pattern.

## Shared Drawer Partial

The shared drawer shell lives in this partial:

```text
app/views/components/_drawer.html.erb
```

Use it when a drawer needs its own custom content.

```erb
<%= render layout: "components/drawer",
      locals: {
        controller: "example-drawer",
        title: "Drawer title"
      } do %>
  <p class="search-drawer-empty">Custom drawer content goes here.</p>
<% end %>
```

The trigger must use the same controller name.

```erb
<div data-controller="example-drawer">
  <button type="button" data-action="example-drawer#open">
    Open drawer
  </button>

  <%= render layout: "components/drawer",
        locals: {
          controller: "example-drawer",
          title: "Drawer title"
        } do %>
    <p class="search-drawer-empty">Custom drawer content goes here.</p>
  <% end %>
</div>
```

The shared drawer partial owns:

- The `<dialog>` element.
- The drawer shell, panel, header, scrollable body, optional footer, and close button.
- The `aria-labelledby` relationship between the dialog and title.
- The `data-controller-name-target="dialog"` target.
- The close action.

The drawer is structured into three zones:

- Header stays fixed at the top of the drawer.
- Body is the render block and scrolls when content is long.
- Footer is optional and stays fixed at the bottom of the drawer.

Common locals:

- `controller` is required. Use the Stimulus controller name, such as `"search-drawer"`.
- `title` is required. This appears in the drawer header.
- `title_id` is optional. Use it when the page may contain more than one drawer.
- `subtitle` is optional. Use it for helper text under the title.
- `footer` is optional. Use it for actions, form controls, or summary information that should stay visible at the bottom.

Footer example:

```erb
<% drawer_footer = capture do %>
  <div class="flex items-center justify-end gap-2">
    <button type="button" class="rounded-md px-3 py-2 text-sm font-semibold text-neutral-700">
      Cancel
    </button>
    <button type="button" class="rounded-md bg-cyan-950 px-3 py-2 text-sm font-semibold text-white">
      Save
    </button>
  </div>
<% end %>

<%= render layout: "components/drawer",
      locals: {
        controller: "example-drawer",
        title: "Drawer title",
        footer: drawer_footer
      } do %>
  <p class="search-drawer-empty">Scrollable drawer content goes here.</p>
<% end %>
```

Styling locals:

- `dialog_class`
- `shell_class`
- `panel_class`
- `content_class`
- `header_class`
- `title_class`
- `subtitle_class`
- `close_wrap_class`
- `close_button_class`
- `body_class`
- `footer_class`

Leave these out to use the standard right-side drawer styles.

## AI Chat Drawer Partial

The AI chat drawer markup lives in this partial:

```text
app/views/components/_ai_chat_drawer.html.erb
```

This partial now uses the shared drawer partial internally. It is currently rendered from the item header when `show_ai_chat` is true and `ai_chat_path` is blank.

```erb
<%= render "components/ai_chat_drawer",
      drawer_title: ai_chat_drawer_title,
      drawer_body: ai_chat_drawer_body %>
```

Use `drawer_title` to control the heading at the top of the drawer.

```erb
<%= render "components/ai_chat_drawer",
      drawer_title: "Ask AI",
      drawer_body: "Ask a question about this package." %>
```

The trigger for this drawer must use the `ai-chat-drawer` controller.

```erb
<button type="button"
        class="item-header-icon-button"
        data-action="ai-chat-drawer#open">
  Open AI chat
</button>
```

The parent wrapper must include the controller.

```erb
<div data-controller="ai-chat-drawer">
  <button type="button" data-action="ai-chat-drawer#open">
    Open AI chat
  </button>

  <%= render "components/ai_chat_drawer",
        drawer_title: "AI chat",
        drawer_body: "Ask a question about this package." %>
</div>
```

Use the shared drawer partial directly when the drawer body needs richer custom content than plain AI chat text.

## Basic Dialog Drawer

Create a Stimulus controller with a `dialog` target.

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open() {
    if (!this.dialogTarget.open) {
      this.dialogTarget.showModal()
    }
  }

  close() {
    this.dialogTarget.close()
  }
}
```

Use the controller on a wrapper that contains both the trigger and the drawer.

```erb
<div data-controller="example-drawer">
  <button type="button" data-action="example-drawer#open">
    Open drawer
  </button>

  <%= render layout: "components/drawer",
        locals: {
          controller: "example-drawer",
          title: "Drawer title",
          title_id: "example-drawer-title"
        } do %>
    <p class="search-drawer-empty">Drawer content goes here.</p>
  <% end %>
</div>
```

## Controller Naming

Stimulus controller names come from the file name.

```text
app/javascript/controllers/example_drawer_controller.js
```

Use this controller name in HTML:

```erb
data-controller="example-drawer"
data-action="example-drawer#open"
```

The drawer partial creates the `data-example-drawer-target="dialog"` attribute for you.

## Drawer Styling

The shared drawer styles are in:

```text
app/assets/tailwind/components/headers_style.css
```

The reusable classes are:

- `search-drawer` for the full-screen dialog layer.
- `search-drawer-shell` for the inner overlay area.
- `search-drawer-panel` for the right-side panel width and animation timing.
- `search-drawer-content` for the white panel layout.
- `search-drawer-header` for the title and close button row.
- `search-drawer-body` for the scrollable drawer content area.
- `search-drawer-footer` for sticky footer content.

Even though these classes are named `search-drawer`, they are currently used by other drawers too.

## Add Dynamic Text

If the drawer needs to show text from an input, add more targets.

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "input", "preview"]

  open() {
    this.previewTarget.textContent = this.inputTarget.value.trim()

    if (!this.dialogTarget.open) {
      this.dialogTarget.showModal()
    }
  }

  close() {
    this.dialogTarget.close()
  }
}
```

```erb
<div data-controller="example-drawer">
  <input type="search" data-example-drawer-target="input">

  <button type="button" data-action="example-drawer#open">
    Open drawer
  </button>

  <%= render layout: "components/drawer",
        locals: {
          controller: "example-drawer",
          title: "Preview"
        } do %>
    <p data-example-drawer-target="preview"></p>
  <% end %>
</div>
```

## Use With Turbo Frames

If the drawer should open while Turbo loads content, put the Turbo frame inside the drawer body.

```erb
<%= form_with url: search_path,
      method: :get,
      data: {
        action: "submit->search-drawer#open",
        turbo_frame: "drawer_results"
      } do %>
  <%= search_field_tag :search, nil, data: { search_drawer_target: "query" } %>
<% end %>

<%= render layout: "components/drawer",
      locals: {
        controller: "search-drawer",
        title: "Search",
        title_id: "search-drawer-title"
      } do %>
  <%= turbo_frame_tag "drawer_results" do %>
    <p class="search-drawer-empty">Results will appear here.</p>
  <% end %>
<% end %>
```

## Mobile Sidebar Drawer

Use the sidebar pattern only for app navigation. It does not use `<dialog>`.

The sidebar controller has three targets:

- `drawer` for the full overlay.
- `backdrop` for the dark background.
- `panel` for the sliding navigation panel.

Opening removes hidden and translated classes:

```js
this.drawerTarget.classList.remove("hidden")
this.backdropTarget.classList.remove("opacity-0")
this.panelTarget.classList.remove("-translate-x-full")
document.body.classList.add("overflow-hidden")
```

Closing adds those classes back:

```js
this.backdropTarget.classList.add("opacity-0")
this.panelTarget.classList.add("-translate-x-full")
document.body.classList.remove("overflow-hidden")
```

The drawer shell becomes `hidden` after a short timeout so the close animation can finish.

## Checklist

When creating a new drawer:

- Add a Stimulus controller with a `dialog` target.
- Put the trigger and shared drawer partial inside the same controller wrapper.
- Use `data-action="controller-name#open"` on the trigger.
- Render `components/drawer` with the matching `controller` local.
- Pass a clear `title`.
- Pass `title_id` when more than one drawer could appear on the page.
- Put custom drawer content inside the render block.
- Pass `footer` when the drawer needs bottom actions or a composer.
- Leave styling locals blank unless the drawer needs a different layout.
- Use a Turbo frame inside the drawer body when the content loads from a request.

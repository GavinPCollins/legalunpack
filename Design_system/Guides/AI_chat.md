# AI Chat

AI chat view components live under:

```text
app/views/components/ai_chat
```

The header still renders the drawer through this wrapper:

```text
app/views/components/_ai_chat_drawer.html.erb
```

That wrapper keeps existing calls working while the AI-specific pieces stay grouped inside `components/ai_chat`.

## Component Map

- `components/ai_chat_drawer` renders the full AI chat drawer.
- `components/ai_chat/chat_content` owns the drawer body, message thread, and footer input.
- `components/ai_chat/ai_output1` renders an AI response bubble.
- `components/ai_chat/user_message` renders a user message bubble.
- `components/ai_chat/ai_output2` still renders the user message bubble for compatibility.
- `app/assets/tailwind/components/ai_chat.css` contains the chat-specific styles.
- `app/javascript/controllers/ai_chat_drawer_controller.js` opens and closes the drawer dialog.

## Default Drawer Render

The item header renders the drawer automatically when `show_ai_chat` is true and `ai_chat_path` is blank.

```erb
<%= render "components/ai_chat_drawer",
      drawer_title: "AI chat",
      drawer_body: "Ask a question about this package." %>
```

The trigger must sit inside an element with `data-controller="ai-chat-drawer"` and use:

```erb
data-action="ai-chat-drawer#open"
```

The shared header already does this when the AI chat button is enabled without a path.

## Rendering Messages

Pass messages into the drawer as an array. Each item names the partial and the locals for that message.

```erb
<%= render "components/ai_chat_drawer",
      drawer_title: "AI chat",
      messages: [
        {
          partial: "components/ai_chat/ai_output1",
          locals: {
            sender: "LegalUnpack AI",
            message: "This file contains one high-risk indemnity clause.",
            time: "10:14"
          }
        },
        {
          partial: "components/ai_chat/user_message",
          locals: {
            sender: "You",
            message: "Can you explain it in plain English?",
            time: "10:15"
          }
        }
      ] %>
```

## AI Response Bubble

Use `ai_output1` for AI messages.

```erb
<%= render "components/ai_chat/ai_output1",
      message: "This package looks mostly standard, but the termination clause needs review.",
      time: "Now" %>
```

Supported locals:

- `sender`, default: `LegalUnpack AI`
- `message`, default: placeholder chat text
- `time`, optional
- `status`, optional. Leave it out unless you need a delivery, loading, or completion label.

## User Message Bubble

Use `user_message` for user messages.

```erb
<%= render "components/ai_chat/user_message",
      message: "What should I check first?",
      time: "Now" %>
```

Supported locals:

- `sender`, default: `You`
- `message`, default: placeholder chat text
- `time`, optional
- `status`, optional. Leave it out unless you need a delivery, loading, or completion label.

## Suggested Next Clarifications

These are possible enhancements to discuss before implementing:

- Decide whether the chat input should submit through Turbo, a Stimulus action, or a standard Rails controller action.
- Decide whether messages should be saved to the database or only shown during the current session.
- Add loading, error, and empty states once the AI endpoint is connected.
- Add source references when an answer is based on a specific file, clause, or package summary.
- Consider a single message partial later if the two visual options converge into one shared pattern.

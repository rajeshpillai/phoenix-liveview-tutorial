# Lesson 6: JS Hooks & Commands

## Overview

LiveView minimizes JavaScript, but some things require client-side code: clipboard
access, canvas drawing, third-party JS libraries, browser APIs. JS Hooks and JS
Commands bridge this gap.

**Source files:**
- `lib/liveview_lab_web/live/lesson6_js_hooks_live.ex`
- `assets/js/app.js` (hooks section)

---

## JS Commands (Phoenix.LiveView.JS)

JS Commands run **client-side** — no WebSocket roundtrip. They manipulate the DOM
directly.

### Available Commands

```elixir
alias Phoenix.LiveView.JS

JS.toggle(to: "#element")              # Show/hide
JS.show(to: "#element")                # Show
JS.hide(to: "#element")                # Hide
JS.add_class("active", to: "#el")      # Add CSS class
JS.remove_class("active", to: "#el")   # Remove CSS class
JS.toggle_class("active", to: "#el")   # Toggle CSS class
JS.set_attribute({"disabled", ""}, to: "#el")
JS.remove_attribute("disabled", to: "#el")
JS.transition("fade-in", to: "#el")    # Run CSS transition
JS.dispatch("my-event", to: "#el")     # Dispatch DOM event
JS.push("server-event")                # Push event to server
JS.navigate("/path")                   # Navigate (live)
JS.patch("/path")                      # Patch current LV
JS.focus(to: "#input")                 # Focus element
JS.focus_first(to: "#container")       # Focus first focusable
JS.exec("phx-click", to: "#other")     # Execute another binding
```

### Chaining Commands

Commands are chainable — they execute sequentially on the client:

```elixir
JS.push("submit")
|> JS.hide(to: "#form")
|> JS.show(to: "#loading")
|> JS.transition("fade-in", to: "#loading")
```

### Using in Templates

```heex
<button phx-click={JS.toggle(to: "#panel")}>Toggle Panel</button>
<button phx-click={JS.push("save") |> JS.hide(to: "#modal")}>Save & Close</button>

<%!-- Combine server event + client action --%>
<button phx-click={JS.push("delete") |> JS.transition("fade-out", to: "#row-1")}>
  Delete
</button>
```

### JS + Server Events

A common pattern: optimistic UI with JS Commands + server confirmation.

```heex
<button phx-click={
  JS.push("like")
  |> JS.add_class("text-red-500", to: "#heart")
  |> JS.transition("scale-125", to: "#heart")
}>
  <span id="heart">♥</span>
</button>
```

The heart immediately turns red (client-side), while the server processes the "like".

---

## JS Hooks

Hooks are JavaScript objects attached to DOM elements via `phx-hook="HookName"`.
They provide lifecycle callbacks and bidirectional communication.

### Defining Hooks

```javascript
// In assets/js/app.js
const Hooks = {}

Hooks.MyHook = {
  // Called when the element is added to the DOM
  mounted() {
    console.log("Element mounted:", this.el)
  },

  // Called when the element's server-side assigns change
  updated() {
    console.log("Element updated")
  },

  // Called when the element is removed from the DOM
  destroyed() {
    console.log("Element destroyed")
  },

  // Called when the element is disconnected from the server
  disconnected() {
    console.log("Server disconnected")
  },

  // Called when the element reconnects to the server
  reconnected() {
    console.log("Server reconnected")
  }
}

// Register hooks with LiveSocket
const liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  // ...
})
```

### Attaching Hooks

```heex
<div id="my-element" phx-hook="MyHook" data-config={Jason.encode!(@config)}>
  Content
</div>
```

**Rules:**
- Element MUST have a unique `id`
- Only one hook per element
- Access data attributes via `this.el.dataset`

### Hook API: `this`

Inside hook callbacks, `this` provides:

```javascript
this.el          // The DOM element
this.viewName    // The LiveView module name
this.pushEvent(event, payload, callback)  // Client → Server
this.pushEventTo(selector, event, payload, callback)  // To specific LV/component
this.handleEvent(event, callback)         // Listen for server → client
this.upload(name, files)                  // Trigger file upload
this.liveSocket                          // The LiveSocket instance
```

---

## Client → Server: pushEvent

```javascript
Hooks.SearchInput = {
  mounted() {
    let timeout
    this.el.addEventListener("input", (e) => {
      clearTimeout(timeout)
      timeout = setTimeout(() => {
        this.pushEvent("search", { query: e.target.value })
      }, 300) // Debounce 300ms
    })
  }
}
```

```elixir
# Server
def handle_event("search", %{"query" => query}, socket) do
  results = search(query)
  {:noreply, assign(socket, results: results)}
end
```

### With Callbacks

```javascript
this.pushEvent("validate", { data: value }, (reply, ref) => {
  // reply = the server's response
  console.log("Server replied:", reply)
})
```

```elixir
def handle_event("validate", params, socket) do
  # Return a reply
  {:reply, %{valid: true, errors: []}, socket}
end
```

---

## Server → Client: push_event + handleEvent

```elixir
# Server pushes event to client
def handle_event("trigger", _, socket) do
  {:noreply, push_event(socket, "highlight", %{color: "yellow", duration: 2000})}
end
```

```javascript
// Client hook receives it
Hooks.Highlighter = {
  mounted() {
    this.handleEvent("highlight", ({ color, duration }) => {
      this.el.style.backgroundColor = color
      setTimeout(() => {
        this.el.style.backgroundColor = ""
      }, duration)
    })
  }
}
```

---

## Common Hook Patterns

### Clipboard

```javascript
Hooks.Clipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      navigator.clipboard.writeText(this.el.dataset.text)
    })
  }
}
```

### Auto-resize Textarea

```javascript
Hooks.AutoResize = {
  mounted() {
    this.resize()
    this.el.addEventListener("input", () => this.resize())
  },
  updated() { this.resize() },
  resize() {
    this.el.style.height = "auto"
    this.el.style.height = this.el.scrollHeight + "px"
  }
}
```

### Chart.js Integration

```javascript
Hooks.Chart = {
  mounted() {
    this.chart = new Chart(this.el, JSON.parse(this.el.dataset.config))

    this.handleEvent("update_chart", ({ data }) => {
      this.chart.data = data
      this.chart.update()
    })
  },
  destroyed() {
    this.chart.destroy()
  }
}
```

### Scroll to Bottom (Chat)

```javascript
Hooks.ScrollBottom = {
  mounted() { this.scrollToBottom() },
  updated() { this.scrollToBottom() },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}
```

### Keyboard Shortcuts

```javascript
Hooks.KeyHandler = {
  mounted() {
    this.handler = (e) => {
      if (e.ctrlKey && e.key === "Enter") {
        this.pushEvent("submit", {})
      }
      if (e.key === "Escape") {
        this.pushEvent("cancel", {})
      }
    }
    document.addEventListener("keydown", this.handler)
  },
  destroyed() {
    document.removeEventListener("keydown", this.handler)
  }
}
```

---

## When to Use What

| Need | Use |
|---|---|
| Show/hide/toggle | `JS.toggle`, `JS.show`, `JS.hide` |
| CSS transitions | `JS.transition` |
| Optimistic UI | `JS.push` + `JS.add_class` chained |
| Browser APIs (clipboard, geolocation) | JS Hook |
| Third-party JS library | JS Hook |
| Complex client state | JS Hook |
| Debounce/throttle input | JS Hook |
| Canvas/WebGL | JS Hook |
| Server-initiated client action | `push_event` + `handleEvent` |

---

## Debugging

```javascript
// Enable LiveSocket debug logging
liveSocket.enableDebug()

// Simulate latency (test loading states)
liveSocket.enableLatencySim(2000) // 2 second delay

// In hooks
mounted() {
  console.log("Hook mounted:", this.el.id, this.el.dataset)
}
```

---

## Exercises

1. Build a CodeMirror/Monaco editor hook that syncs content with the server
2. Implement drag-and-drop reordering with a JS hook + stream updates
3. Create a keyboard shortcut system (Ctrl+K for command palette)
4. Build a canvas drawing hook where strokes are broadcast via PubSub
5. Implement optimistic UI for a todo list (check/uncheck with JS, confirm on server)

# Lesson 4: LiveComponents Deep Dive

## Overview

LiveView has two kinds of components: **function components** (stateless) and
**LiveComponents** (stateful). Knowing when to use which — and how they communicate
— is essential for building maintainable LiveView applications.

**Source files:**
- `lib/liveview_lab_web/live/lesson4_components_live.ex`
- `lib/liveview_lab_web/components/counter_component.ex`
- `lib/liveview_lab_web/components/editable_card_component.ex`

---

## Function Components vs LiveComponents

### Function Components (Stateless)

```elixir
# Definition
attr :name, :string, required: true
attr :class, :string, default: ""
slot :inner_block

def greeting(assigns) do
  ~H"""
  <div class={@class}>
    Hello, {@name}!
    {render_slot(@inner_block)}
  </div>
  """
end

# Usage
<.greeting name="World" class="text-lg">
  <p>Welcome to LiveView</p>
</.greeting>
```

**Characteristics:**
- Just a function — no process, no state
- Re-renders when parent re-renders (with changed assigns)
- Defined with `attr` and `slot` declarations
- Called with `<.component_name>` syntax
- **Use by default** — covers 90% of cases

### LiveComponents (Stateful)

```elixir
defmodule MyApp.CounterComponent do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, assign(socket, count: 0)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <span>{@count}</span>
      <button phx-click="inc" phx-target={@myself}>+</button>
    </div>
    """
  end

  def handle_event("inc", _, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end
end

# Usage
<.live_component module={MyApp.CounterComponent} id="my-counter" />
```

**Characteristics:**
- Has its own state, isolated from parent
- Has lifecycle callbacks (mount, update, render)
- Events target `@myself` to stay within the component
- **Must have a unique `id` prop**
- Re-renders independently of parent (when its own assigns change)

---

## Lifecycle

```
First render:          Subsequent renders:
mount/1 → update/2 → render/1    update/2 → render/1
```

### mount/1
Called once per component instance (first render only).

```elixir
def mount(socket) do
  {:ok, assign(socket, editing: false, count: 0)}
end
```

### update/2
Called on every render (including first). Receives props from parent.

```elixir
def update(assigns, socket) do
  # assigns = props passed from parent
  # socket.assigns = current component state

  socket =
    socket
    |> assign(:title, assigns.title)
    |> assign_new(:form, fn -> build_form(assigns) end)

  {:ok, socket}
end
```

**Important:** `update/2` receives ALL assigns from the parent each time.
Use `assign_new/3` to avoid overwriting component-internal state.

### render/1
Standard render function. Use `@myself` for event targeting.

---

## Communication Patterns

### Parent → Child: Props

```elixir
# Parent
<.live_component module={Card} id="card-1" title={@title} />
```

The child receives `title` in `update/2` on every parent re-render.

### Parent → Child: send_update

For imperative updates (e.g., "reset this component"):

```elixir
# Parent handle_event
def handle_event("reset", %{"id" => id}, socket) do
  send_update(CounterComponent, id: id, reset: true)
  {:noreply, socket}
end

# Child update/2
def update(%{reset: true}, socket) do
  {:ok, assign(socket, count: 0)}
end

def update(assigns, socket) do
  {:ok, assign(socket, assigns)}
end
```

**Pattern match in `update/2`** to distinguish between regular props and
imperative commands.

### Child → Parent: send/2

```elixir
# Child (in handle_event)
def handle_event("save", params, socket) do
  # self() in a LiveComponent refers to the PARENT LiveView process
  send(self(), {:card_saved, socket.assigns.id, params})
  {:noreply, socket}
end

# Parent (handle_info)
def handle_info({:card_saved, card_id, params}, socket) do
  # Handle the child's message
  {:noreply, socket}
end
```

### Child → Parent: Events Bubbling

Events without `phx-target` bubble up to the parent LiveView:

```heex
<%!-- In child template, NO phx-target --%>
<button phx-click="delete" phx-value-id={@id}>Delete</button>
```

The parent's `handle_event("delete", ...)` will be called.

---

## Slots

### Basic Slots

```elixir
slot :inner_block, required: true

def card(assigns) do
  ~H"""
  <div class="card">
    {render_slot(@inner_block)}
  </div>
  """
end
```

### Named Slots

```elixir
slot :header, required: true
slot :footer

def card(assigns) do
  ~H"""
  <div class="card">
    <header>{render_slot(@header)}</header>
    <main>{render_slot(@inner_block)}</main>
    <footer :if={@footer != []}>{render_slot(@footer)}</footer>
  </div>
  """
end

# Usage
<.card>
  <:header>Title</:header>
  Body content
  <:footer>Footer</:footer>
</.card>
```

### Slots with Arguments

```elixir
slot :col, required: true do
  attr :label, :string, required: true
end

def table(assigns) do
  ~H"""
  <table>
    <thead>
      <tr>
        <th :for={col <- @col}>{col.label}</th>
      </tr>
    </thead>
    <tbody>
      <tr :for={row <- @rows}>
        <td :for={col <- @col}>
          {render_slot(col, row)}
        </td>
      </tr>
    </tbody>
  </table>
  """
end

# Usage
<.table rows={@users}>
  <:col :let={user} label="Name">{user.name}</:col>
  <:col :let={user} label="Email">{user.email}</:col>
</.table>
```

---

## When to Use LiveComponent

Use a **LiveComponent** when you need:
1. **Isolated state** — component tracks its own state (e.g., open/closed, form data)
2. **Independent re-renders** — component should update without re-rendering parent
3. **Component-scoped events** — events handled within the component
4. **Form isolation** — component manages its own form/changeset

Use a **function component** for everything else:
- Display-only UI (cards, badges, layouts)
- Reusable markup patterns
- Slot-based composition

**Rule of thumb:** Start with function components. Only "upgrade" to LiveComponent
when you hit a wall.

---

## Anti-Patterns

### 1. LiveComponent for pure display
```elixir
# BAD: No state needed, just use a function component
defmodule Badge do
  use Phoenix.LiveComponent
  def render(assigns), do: ~H"<span class='badge'>{@text}</span>"
end

# GOOD
def badge(assigns), do: ~H"<span class='badge'>{@text}</span>"
```

### 2. Passing too many props
```elixir
# BAD: Component knows about everything
<.live_component module={UserCard}
  id={user.id} user={user} permissions={@perms}
  current_user={@current_user} theme={@theme} />

# GOOD: Pass only what's needed
<.live_component module={UserCard}
  id={user.id} user={user} can_edit?={can_edit?(user, @current_user)} />
```

### 3. Deep component nesting
LiveComponents add overhead (extra process messages). Don't nest them 5 levels deep.
Flatten when possible.

---

## Exercises

1. Convert the CounterComponent to emit events to the parent (track total clicks)
2. Build a TabsComponent with named slots for each tab panel
3. Create a Modal LiveComponent with open/close state and `send_update` trigger
4. Implement an Accordion component using only function components + JS commands

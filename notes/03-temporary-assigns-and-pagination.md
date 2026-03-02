# Lesson 3: Temporary Assigns & Pagination

## Overview

This lesson covers memory management strategies in LiveView, with focus on how
streams replaced the older `temporary_assigns` pattern, and how to implement
efficient pagination.

**Source file:** `lib/liveview_lab_web/live/lesson3_temp_assigns_live.ex`

---

## The Memory Problem

Every LiveView process holds its assigns in memory. For a list of 10,000 items:

```elixir
# BAD: 10,000 items in process memory, full diff on every change
assign(socket, items: Repo.all(Item))
```

Each connected user holds a copy. 1,000 users × 10,000 items = massive memory.

---

## Solution 1: temporary_assigns (Legacy)

> **Note:** `temporary_assigns` with `phx-update="append"` is deprecated in
> Phoenix LiveView 1.0+. Use streams instead. This section is for understanding
> existing codebases.

```elixir
# mount/3 returns a third element
def mount(_, _, socket) do
  {:ok, assign(socket, items: fetch_items()), temporary_assigns: [items: []]}
end
```

After each render:
1. `@items` is sent to the client
2. Server resets `@items` to `[]` (the default)
3. Client keeps the DOM — elements persist

Required `phx-update="append"` on the container:
```heex
<div id="items" phx-update="append">
  <div :for={item <- @items} id={"item-#{item.id}"}>{item.name}</div>
</div>
```

**Limitations:**
- Append-only (no delete, no reorder)
- No way to reset/clear from server
- `phx-update="append"` is a footgun — easy to get wrong

---

## Solution 2: Streams (Modern)

Streams solve all the problems of temporary_assigns:

```elixir
def mount(_, _, socket) do
  {:ok, stream(socket, :items, fetch_items())}
end
```

```heex
<div id="items" phx-update="stream">
  <div :for={{dom_id, item} <- @streams.items} id={dom_id}>
    {item.name}
  </div>
</div>
```

### Stream Operations

```elixir
# Append items
stream(socket, :items, new_items)

# Prepend a single item
stream_insert(socket, :items, item, at: 0)

# Append a single item (default)
stream_insert(socket, :items, item)

# Delete an item
stream_delete(socket, :items, item)
# or by constructing a struct with just the id:
stream_delete(socket, :items, %{id: item_id})

# Replace/update an item (same id = replace)
stream_insert(socket, :items, updated_item)

# Reset entire stream
stream(socket, :items, new_items, reset: true)

# Clear everything
stream(socket, :items, [], reset: true)
```

### Why Streams Win

| Feature | temporary_assigns | Streams |
|---|---|---|
| Server memory | O(1) after render | O(1) always |
| Append items | Yes | Yes |
| Prepend items | No | Yes (`at: 0`) |
| Delete items | No | Yes |
| Update items | No | Yes (re-insert) |
| Reset/clear | No | Yes (`reset: true`) |
| Reorder | No | Yes |

---

## Stream-Based Pagination

### Load More Pattern

```elixir
@page_size 20

def mount(_, _, socket) do
  socket =
    socket
    |> assign(page: 1, end_of_data: false)
    |> stream(:items, fetch_page(1))

  {:ok, socket}
end

def handle_event("load_more", _, socket) do
  page = socket.assigns.page + 1
  items = fetch_page(page)

  socket =
    socket
    |> stream(:items, items)
    |> assign(page: page, end_of_data: length(items) < @page_size)

  {:noreply, socket}
end

defp fetch_page(page) do
  Item
  |> order_by(desc: :inserted_at)
  |> limit(@page_size)
  |> offset(^((page - 1) * @page_size))
  |> Repo.all()
end
```

### Infinite Scroll with Viewport Hook

```heex
<div id="items" phx-update="stream">
  <div :for={{dom_id, item} <- @streams.items} id={dom_id}>
    {item.name}
  </div>
</div>

<div
  :if={not @end_of_data}
  id="infinite-scroll-marker"
  phx-hook="InfiniteScroll"
  data-page={@page}
/>
```

```javascript
Hooks.InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver((entries) => {
      const entry = entries[0]
      if (entry.isIntersecting) {
        this.pushEvent("load_more", {})
      }
    })
    this.observer.observe(this.el)
  },
  destroyed() {
    this.observer.disconnect()
  }
}
```

### Cursor-Based Pagination (Better for Real Apps)

Offset pagination has performance issues at scale. Use cursor-based instead:

```elixir
def fetch_page(nil) do
  Item |> order_by(desc: :id) |> limit(@page_size) |> Repo.all()
end

def fetch_page(cursor) do
  Item
  |> where([i], i.id < ^cursor)
  |> order_by(desc: :id)
  |> limit(@page_size)
  |> Repo.all()
end

# In handle_event, pass the last item's ID as cursor
last_id = List.last(items).id
assign(socket, cursor: last_id)
```

---

## Bidirectional Scrolling

For chat-like UIs where you scroll up to load older messages:

```elixir
def mount(_, _, socket) do
  messages = fetch_recent_messages(50)

  socket =
    socket
    |> stream(:messages, messages)
    |> assign(oldest_id: List.first(messages).id)

  {:ok, socket}
end

def handle_event("load_older", _, socket) do
  older = fetch_before(socket.assigns.oldest_id, 20)

  socket =
    socket
    |> stream(:messages, older, at: 0)  # Prepend
    |> assign(oldest_id: List.first(older).id)

  {:noreply, socket}
end
```

---

## Performance Checklist

- [ ] Lists > 50 items should use streams
- [ ] Never load unbounded data (`Repo.all` without limit)
- [ ] Use cursor-based pagination for large datasets
- [ ] Consider `assign_async` for initial page load
- [ ] Cap real-time streams (e.g., keep last 500 log lines)

---

## Exercises

1. Implement cursor-based pagination with a database-backed stream
2. Build bidirectional scrolling (load older on scroll up, newer on scroll down)
3. Add a "jump to top" button that resets the stream to the first page
4. Implement virtual scrolling (only render visible items) using a JS hook

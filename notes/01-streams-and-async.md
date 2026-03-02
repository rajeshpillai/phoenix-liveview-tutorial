# Lesson 1: Streams & Async

## Overview

Streams and async assigns are two of the most important performance primitives in
Phoenix LiveView. Together they solve the two biggest bottlenecks in server-rendered
real-time UIs: **memory** and **latency**.

**Source file:** `lib/liveview_lab_web/live/lesson1_streams_live.ex`

---

## Core Concepts

### 1. Streams (`stream/3`)

Streams are LiveView's mechanism for rendering large collections **without keeping
them in server memory**. When you use `stream/3`, the items are sent to the client
once and then forgotten by the server.

```elixir
# In mount/3
socket
|> stream(:messages, [])           # Initialize empty stream
|> stream(:messages, initial_list) # Or with initial data

# Adding items
stream_insert(socket, :messages, new_message)

# Removing items
stream_delete(socket, :messages, %{id: id})

# Batch append
stream(socket, :messages, list_of_items)

# Reset (clear all)
stream(socket, :messages, [], reset: true)
```

**In the template:**
```heex
<div id="messages" phx-update="stream">
  <div :for={{dom_id, msg} <- @streams.messages} id={dom_id}>
    {msg.body}
  </div>
</div>
```

Key rules:
- Container must have `phx-update="stream"` and a unique `id`
- Each child must have `id={dom_id}` from the stream tuple
- Items need an `:id` field (integer or string)
- Access via `@streams.messages`, not `@messages`

### How Streams Work Internally

1. Server sends items with a `stream_insert` instruction
2. Client morphdom patches the DOM, inserting/removing elements
3. Server immediately discards the items — only tracks the operation
4. On reconnect, mount runs again and re-streams initial data

**Memory impact:** A chat with 10,000 messages uses the same server memory as one
with 10 messages. The items only exist in the browser DOM.

---

### 2. Async Assigns (`assign_async/3`)

`assign_async` spawns a task to load data without blocking the initial render.
The LiveView renders immediately with a `:loading` state, then updates when data arrives.

```elixir
# In mount/3
assign_async(socket, :user_profile, fn ->
  {:ok, %{user_profile: Accounts.get_profile(user_id)}}
end)
```

**In the template:**
```heex
<.async_result :let={profile} assign={@user_profile}>
  <:loading>Loading...</:loading>
  <:failed :let={reason}>Error: {inspect(reason)}</:failed>
  Welcome, {profile.name}!
</.async_result>
```

The async result goes through states:
- `%AsyncResult{ok?: false, loading: initial_data}` — task running
- `%AsyncResult{ok?: true, result: data}` — task completed
- `%AsyncResult{ok?: false, failed: reason}` — task failed

**Re-triggering:** Call `assign_async` again to re-fetch:
```elixir
def handle_event("refresh", _, socket) do
  {:noreply, assign_async(socket, :data, fn -> fetch_data() end)}
end
```

---

### 3. Combining Streams + Async

A common pattern: use `assign_async` for the initial data fetch, then switch to
`stream_insert` for real-time updates.

```elixir
def mount(_, _, socket) do
  socket =
    socket
    |> stream(:items, [])
    |> assign_async(:initial_load, fn ->
      items = Repo.all(Item)
      {:ok, %{initial_load: items}}
    end)

  {:ok, socket}
end

def handle_async(:initial_load, {:ok, %{initial_load: items}}, socket) do
  {:noreply, stream(socket, :items, items)}
end
```

---

## When to Use What

| Scenario | Use |
|---|---|
| List of 100+ items | `stream/3` |
| Initial data that's slow to load | `assign_async/3` |
| Data you need to filter/sort on server | Regular `assign` |
| Real-time feed (chat, logs) | `stream/3` + PubSub |
| One-time expensive computation | `assign_async/3` |

---

## Common Pitfalls

1. **Forgetting `phx-update="stream"`** — items will re-render on every update
2. **Missing `:id` on items** — streams require unique IDs for diffing
3. **Trying to access stream items on server** — they don't exist there
4. **Not handling async failures** — always provide a `<:failed>` slot
5. **Blocking mount with slow queries** — use `assign_async` instead

---

## Exercises

1. Add a "filter" input that resets the stream and re-populates with filtered items
2. Implement `stream_insert` with `at: 0` to prepend items instead of appending
3. Create an async assign that can be cancelled (hint: track the task reference)
4. Build a "live search" that uses assign_async with debounce

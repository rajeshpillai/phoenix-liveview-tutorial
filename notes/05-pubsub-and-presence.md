# Lesson 5: PubSub & Presence

## Overview

Phoenix.PubSub enables real-time communication between LiveView processes.
Combined with Phoenix.Presence, you can build collaborative features: shared
counters, live chat, typing indicators, cursor tracking, and more.

**Source file:** `lib/liveview_lab_web/live/lesson5_pubsub_live.ex`

---

## Core Concepts

### Phoenix.PubSub

PubSub is a topic-based message broker built into Phoenix. It works across nodes
in a cluster (via pg/Phoenix.PubSub.PG2).

```
┌──────────┐   broadcast("room:1", msg)    ┌──────────┐
│ LiveView  │ ─────────────────────────────► │ PubSub   │
│ Process A │                                │ (pg)     │
└──────────┘                                 └──┬───┬───┘
                                                │   │
                              ┌─────────────────┘   └──────────────────┐
                              ▼                                        ▼
                        ┌──────────┐                            ┌──────────┐
                        │ LiveView │                            │ LiveView │
                        │ Process B│                            │ Process C│
                        └──────────┘                            └──────────┘
```

### Three Operations

```elixir
# 1. Subscribe (in mount, only when connected)
if connected?(socket) do
  Phoenix.PubSub.subscribe(MyApp.PubSub, "room:lobby")
end

# 2. Broadcast (send to ALL subscribers, including self)
Phoenix.PubSub.broadcast(MyApp.PubSub, "room:lobby", {:new_message, msg})

# 3. Receive (in handle_info)
def handle_info({:new_message, msg}, socket) do
  {:noreply, assign(socket, messages: [msg | socket.assigns.messages])}
end
```

---

## Pattern 1: Shared Counter

The simplest PubSub example — all tabs see the same counter.

```elixir
@topic "counter:global"

def mount(_, _, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, @topic)
  end
  {:ok, assign(socket, count: 0)}
end

def handle_event("increment", _, socket) do
  Phoenix.PubSub.broadcast(MyApp.PubSub, @topic, :increment)
  {:noreply, socket}
end

def handle_info(:increment, socket) do
  {:noreply, assign(socket, count: socket.assigns.count + 1)}
end
```

**Note:** The broadcaster also receives the message (it's subscribed too).
This keeps state consistent without special-casing the sender.

---

## Pattern 2: Live Chat Room

```elixir
def handle_event("send_message", %{"body" => body}, socket) do
  msg = %{
    id: System.unique_integer([:positive]),
    user_id: socket.assigns.user_id,
    body: body,
    sent_at: DateTime.utc_now()
  }

  Phoenix.PubSub.broadcast(MyApp.PubSub, @topic, {:new_message, msg})
  {:noreply, socket}
end

def handle_info({:new_message, msg}, socket) do
  {:noreply, stream_insert(socket, :messages, msg)}
end
```

Using streams for chat messages = O(1) server memory per user.

---

## Pattern 3: User Presence

### Simple Presence (Manual Tracking)

```elixir
def mount(_, _, socket) do
  user_id = generate_user_id()

  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, @topic)
    broadcast(:user_joined, %{user_id: user_id})
  end

  {:ok, assign(socket, user_id: user_id, online_users: [])}
end

def terminate(_reason, socket) do
  broadcast(:user_left, %{user_id: socket.assigns.user_id})
end
```

**Caveat:** `terminate/2` is not guaranteed to be called (process crash, node
failure). For reliable presence, use Phoenix.Presence.

### Phoenix.Presence (Production)

```elixir
# Define a Presence module
defmodule MyAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :my_app,
    pubsub_server: MyApp.PubSub
end

# In LiveView mount
def mount(_, _, socket) do
  if connected?(socket) do
    {:ok, _} = MyAppWeb.Presence.track(self(), @topic, socket.assigns.user_id, %{
      joined_at: DateTime.utc_now(),
      username: socket.assigns.username
    })

    Phoenix.PubSub.subscribe(MyApp.PubSub, @topic)
  end

  presences = MyAppWeb.Presence.list(@topic)
  {:ok, assign(socket, presences: presences)}
end

def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
  presences =
    socket.assigns.presences
    |> MyAppWeb.Presence.sync_diff(diff)

  {:noreply, assign(socket, presences: presences)}
end
```

**Phoenix.Presence advantages:**
- Handles crashes/disconnects automatically (heartbeat-based)
- Works across cluster nodes
- Provides `sync_diff` for efficient updates
- CRDTs under the hood — no conflicts

---

## Topic Design

Topics are just strings. Design them hierarchically:

```
"chat:lobby"          — Global chat room
"chat:room:42"        — Specific room
"user:123:activity"   — User-specific events
"game:abc:moves"      — Game-specific events
"admin:notifications" — Admin broadcast channel
```

### Scoped Subscriptions

```elixir
# User subscribes only to their rooms
for room_id <- user.room_ids do
  Phoenix.PubSub.subscribe(MyApp.PubSub, "chat:room:#{room_id}")
end
```

---

## broadcast vs broadcast_from

```elixir
# broadcast — sends to ALL subscribers (including self)
Phoenix.PubSub.broadcast(MyApp.PubSub, topic, msg)

# broadcast_from — sends to all EXCEPT the sender
Phoenix.PubSub.broadcast_from(MyApp.PubSub, self(), topic, msg)
```

Use `broadcast_from` when the sender already applied the change locally:

```elixir
def handle_event("increment", _, socket) do
  # Apply locally first (optimistic update)
  socket = assign(socket, count: socket.assigns.count + 1)
  # Then tell others
  Phoenix.PubSub.broadcast_from(MyApp.PubSub, self(), @topic, :increment)
  {:noreply, socket}
end
```

---

## Performance Considerations

1. **Fan-out cost** — Broadcasting to 10,000 subscribers = 10,000 messages. Keep
   topic scopes narrow.
2. **Message size** — PubSub copies the message to each subscriber. Keep payloads
   small.
3. **Frequency** — Don't broadcast on every keystroke. Debounce/throttle.
4. **Node affinity** — PubSub works across Erlang nodes, but latency increases.

---

## Common Real-time Features

| Feature | Pattern |
|---|---|
| Live chat | PubSub broadcast + streams |
| Typing indicator | PubSub broadcast_from + debounce |
| Live cursors | PubSub broadcast_from + JS hook |
| Collaborative editing | PubSub + CRDTs/OT |
| Live notifications | Per-user topic + PubSub |
| Real-time dashboard | PubSub + telemetry events |

---

## Exercises

1. Implement `broadcast_from` for the shared counter (optimistic update)
2. Add Phoenix.Presence for reliable online user tracking
3. Build a typing indicator that shows "User X is typing..."
4. Create a scoped chat with multiple rooms (each room = separate topic)
5. Implement rate limiting on broadcasts (max 10 messages/second per user)

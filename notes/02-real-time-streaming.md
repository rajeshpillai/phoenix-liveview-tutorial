# Lesson 2: Real-time Streaming

## Overview

This lesson covers patterns for streaming data to the client in real-time — token
by token, chunk by chunk, or as a continuous log. These patterns power LLM chat
interfaces, progress indicators, and live tailing UIs.

**Source file:** `lib/liveview_lab_web/live/lesson2_streaming_live.ex`

---

## Core Pattern: Task + send + handle_info

The fundamental streaming pattern in LiveView:

```
┌─────────────┐      send(lv, msg)      ┌──────────────┐
│  Task/       │ ──────────────────────► │  LiveView    │
│  GenServer   │                         │  process     │
│  (producer)  │                         │              │
└─────────────┘                          │ handle_info  │
                                         │   → assign   │
                                         │   → re-render│
                                         └──────────────┘
```

```elixir
def handle_event("start", _, socket) do
  lv = self()

  Task.start(fn ->
    for chunk <- produce_chunks() do
      Process.sleep(50)
      send(lv, {:chunk, chunk})
    end
    send(lv, :done)
  end)

  {:noreply, assign(socket, streaming: true)}
end

def handle_info({:chunk, chunk}, socket) do
  {:noreply, assign(socket, text: socket.assigns.text <> chunk)}
end

def handle_info(:done, socket) do
  {:noreply, assign(socket, streaming: false)}
end
```

---

## Pattern 1: Token-by-Token Streaming (LLM Style)

Used for: Chat AI responses, typewriter effects, real-time transcription.

```elixir
# The producer task
Task.start(fn ->
  for token <- tokenize(response) do
    Process.sleep(Enum.random(30..120))  # Simulate varying latency
    send(lv_pid, {:token, token})
  end
  send(lv_pid, :stream_complete)
end)
```

**Template pattern — append to text:**
```heex
<div class="response">
  {@accumulated_text}
  <span :if={@streaming} class="animate-pulse">|</span>
</div>
```

**Why this is efficient:** LiveView only sends the diff of the changed text.
Even though the full string is re-sent in the assign, the client-side morphdom
only patches the new characters.

### Production Considerations

For real LLM streaming (OpenAI, Anthropic APIs):

```elixir
def handle_event("ask", %{"prompt" => prompt}, socket) do
  lv = self()

  Task.start(fn ->
    stream = MyApp.LLM.stream_completion(prompt)

    Enum.each(stream, fn
      {:chunk, text} -> send(lv, {:token, text})
      :done -> send(lv, :stream_complete)
      {:error, reason} -> send(lv, {:stream_error, reason})
    end)
  end)

  {:noreply, assign(socket, streaming: true, response: "")}
end
```

---

## Pattern 2: Progress Streaming

Used for: File uploads, batch processing, ETL jobs, deployments.

```elixir
# Producer
Task.start(fn ->
  for i <- 1..total_steps do
    perform_step(i)
    send(lv_pid, {:progress, round(i / total_steps * 100)})
  end
  send(lv_pid, :complete)
end)

# LiveView
def handle_info({:progress, pct}, socket) do
  {:noreply, assign(socket, progress: pct)}
end
```

**Template:**
```heex
<progress class="progress" value={@progress} max="100" />
<span>{@progress}%</span>
```

**Optimization:** Don't send every single update. Batch or throttle:
```elixir
# Only send every 2%
if rem(i, div(total, 50)) == 0 do
  send(lv_pid, {:progress, round(i / total * 100)})
end
```

---

## Pattern 3: Live Log Tail

Used for: Server logs, build output, deployment logs, monitoring.

```elixir
def handle_info({:log_line, line}, socket) do
  # Cap at N lines to prevent unbounded memory growth
  lines = Enum.take(socket.assigns.log_lines ++ [line], -500)
  {:noreply, assign(socket, log_lines: lines)}
end
```

**With a JS Hook for auto-scroll:**
```javascript
Hooks.ScrollBottom = {
  mounted() { this.scrollToBottom() },
  updated() { this.scrollToBottom() },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}
```

**For high-volume logs, use streams instead:**
```elixir
def handle_info({:log_line, line}, socket) do
  entry = %{id: System.unique_integer([:positive]), text: line}
  {:noreply, stream_insert(socket, :log_lines, entry)}
end
```

---

## Task Supervision

For production code, use `Task.Supervisor` instead of bare `Task.start`:

```elixir
# In application.ex
children = [
  {Task.Supervisor, name: MyApp.StreamingSupervisor}
]

# In LiveView
Task.Supervisor.start_child(MyApp.StreamingSupervisor, fn ->
  # streaming work
end)
```

This ensures:
- Tasks are properly supervised and logged on failure
- Tasks are terminated when the application shuts down
- You can set max concurrency with `max_children`

---

## Cancellation

To cancel a running stream:

```elixir
def handle_event("start", _, socket) do
  {:ok, pid} = Task.start(fn -> stream_work(self()) end)
  {:noreply, assign(socket, task_pid: pid, streaming: true)}
end

def handle_event("cancel", _, socket) do
  if pid = socket.assigns.task_pid do
    Process.exit(pid, :kill)
  end
  {:noreply, assign(socket, streaming: false, task_pid: nil)}
end
```

Or better, use `Task.async` with `handle_async`:

```elixir
def handle_event("start", _, socket) do
  {:noreply, start_async(socket, :my_stream, fn -> do_work() end)}
end

# LiveView 1.0+ handles cancellation automatically on disconnect
```

---

## Performance Tips

1. **Throttle updates** — Don't send on every byte; batch to ~60fps (16ms intervals)
2. **Cap accumulation** — Set max length for accumulated text/lines
3. **Use streams for lists** — If streaming list items, use `stream_insert` not append to assign
4. **Handle disconnects** — Tasks should detect dead LiveView PIDs gracefully
5. **Binary optimization** — For large text, consider IOdata instead of string concatenation

---

## Exercises

1. Build a streaming file download progress bar with actual byte counts
2. Implement cancellation with a "Stop" button that kills the streaming task
3. Create a streaming diff viewer that highlights new characters as they arrive
4. Build a multi-stream UI showing 3 parallel tasks with independent progress

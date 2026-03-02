defmodule LiveviewLabWeb.HomeLive do
  use LiveviewLabWeb, :live_view

  @lessons [
    %{
      path: "/lessons/streams",
      title: "Streams & Async",
      desc: "LiveView streams for efficient list rendering, async_result for non-blocking data loading",
      tag: "Performance"
    },
    %{
      path: "/lessons/streaming",
      title: "Real-time Streaming",
      desc: "Server-sent chunked data, token-by-token streaming UI, progress indicators",
      tag: "Streaming"
    },
    %{
      path: "/lessons/temporary-assigns",
      title: "Temporary Assigns & Pagination",
      desc: "Memory optimization with temporary_assigns, infinite scroll, phx-update=stream",
      tag: "Performance"
    },
    %{
      path: "/lessons/components",
      title: "LiveComponents Deep Dive",
      desc: "Stateful components, lifecycle callbacks, send_update, slots & function components",
      tag: "Components"
    },
    %{
      path: "/lessons/pubsub",
      title: "PubSub & Presence",
      desc: "Multi-user real-time with Phoenix.PubSub, broadcast patterns, live cursors",
      tag: "Real-time"
    },
    %{
      path: "/lessons/js-hooks",
      title: "JS Hooks & Commands",
      desc: "JavaScript interop, push events, JS commands, client-side state",
      tag: "Interop"
    }
  ]

  def mount(_params, _session, socket) do
    {:ok, assign(socket, lessons: @lessons, page_title: "LiveView Lab")}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="text-center space-y-4">
        <h1 class="text-4xl font-bold">LiveView Lab</h1>
        <p class="text-lg opacity-70 max-w-xl mx-auto">
          Advanced Phoenix LiveView patterns — streams, real-time streaming,
          performance optimization, components, PubSub, and JS interop.
        </p>
      </div>

      <div class="grid gap-4">
        <.link
          :for={{lesson, idx} <- Enum.with_index(@lessons, 1)}
          navigate={lesson.path}
          class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
        >
          <div class="card-body p-4">
            <div class="flex items-start gap-3">
              <span class="badge badge-neutral font-mono">{idx}</span>
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <h2 class="card-title text-base">{lesson.title}</h2>
                  <span class="badge badge-sm badge-outline">{lesson.tag}</span>
                </div>
                <p class="text-sm opacity-70 mt-1">{lesson.desc}</p>
              </div>
              <span class="text-lg opacity-50">→</span>
            </div>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end

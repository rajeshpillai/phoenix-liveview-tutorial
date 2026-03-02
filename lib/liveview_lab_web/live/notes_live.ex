defmodule LiveviewLabWeb.NotesLive do
  @moduledoc """
  Renders lesson notes from the notes/ directory as HTML.
  """
  use LiveviewLabWeb, :live_view

  @notes_dir Path.expand("../../../../notes", __DIR__)

  @lessons %{
    "streams" => "01-streams-and-async.md",
    "streaming" => "02-real-time-streaming.md",
    "temporary-assigns" => "03-temporary-assigns-and-pagination.md",
    "components" => "04-livecomponents-deep-dive.md",
    "pubsub" => "05-pubsub-and-presence.md",
    "js-hooks" => "06-js-hooks-and-commands.md"
  }

  def mount(%{"lesson" => lesson_slug}, _session, socket) do
    case Map.get(@lessons, lesson_slug) do
      nil ->
        {:ok, push_navigate(socket, to: "/")}

      filename ->
        path = Path.join(@notes_dir, filename)

        content =
          case File.read(path) do
            {:ok, md} -> md
            {:error, _} -> "# Notes not found\n\nCould not read #{filename}."
          end

        socket =
          socket
          |> assign(
            page_title: "Notes: #{lesson_slug}",
            lesson_slug: lesson_slug,
            content: content,
            back_path: "/lessons/#{lesson_slug}"
          )

        {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-4">
        <.link navigate={@back_path} class="btn btn-ghost btn-sm">← Back to Lesson</.link>
        <.link navigate="/" class="btn btn-ghost btn-sm">Home</.link>
      </div>

      <div class="prose prose-sm max-w-none">
        <pre class="whitespace-pre-wrap text-sm bg-base-200 p-6 rounded-lg overflow-x-auto"><code>{@content}</code></pre>
      </div>
    </div>
    """
  end
end

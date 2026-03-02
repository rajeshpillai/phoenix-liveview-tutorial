defmodule LiveviewLabWeb.NotesLive do
  @moduledoc """
  Renders lesson notes from the notes/ directory as formatted HTML
  with syntax-highlighted code blocks.
  """
  use LiveviewLabWeb, :live_view

  # Resolve at compile time relative to project root
  @notes_dir Path.expand("notes", File.cwd!())

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

        html_content =
          case File.read(path) do
            {:ok, md} -> md_to_html(md)
            {:error, _} -> "<p>Could not read #{filename}.</p>"
          end

        socket =
          socket
          |> assign(
            page_title: "Notes: #{lesson_slug}",
            lesson_slug: lesson_slug,
            html_content: html_content,
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

      <article class="prose prose-sm max-w-none prose-headings:text-base-content prose-p:text-base-content prose-li:text-base-content prose-strong:text-base-content prose-code:text-primary prose-td:text-base-content prose-th:text-base-content">
        {raw(@html_content)}
      </article>
    </div>
    """
  end

  defp md_to_html(markdown) do
    {:ok, html, _} = Earmark.as_html(markdown, code_class_prefix: "language-")

    html
    |> highlight_code_blocks()
  end

  defp highlight_code_blocks(html) do
    Regex.replace(
      ~r/<pre><code class="language-(\w+)">([\s\S]*?)<\/code><\/pre>/,
      html,
      fn _full, lang, code ->
        highlighted = highlight(lang, unescape_html(code))
        ~s(<pre class="highlight bg-base-300 p-4 rounded-lg overflow-x-auto text-sm"><code class="language-#{lang}">#{highlighted}</code></pre>)
      end
    )
  end

  defp highlight("elixir", code), do: Makeup.highlight(code, lexer: Makeup.Lexers.ElixirLexer)
  defp highlight("heex", code), do: Makeup.highlight(code, lexer: Makeup.Lexers.ElixirLexer)
  defp highlight("javascript", code), do: Makeup.highlight(code, lexer: Makeup.Lexers.JsLexer)
  defp highlight("js", code), do: Makeup.highlight(code, lexer: Makeup.Lexers.JsLexer)
  defp highlight("html", code), do: Makeup.highlight(code, lexer: Makeup.Lexers.HTMLLexer)
  defp highlight(_lang, code), do: code

  defp unescape_html(html) do
    html
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
  end
end

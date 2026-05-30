defmodule HermesTrictracWeb.RulesController do
  use HermesTrictracWeb, :controller

  alias HermesTrictrac.RulesLibrary

  def index(conn, params) do
    return_context = RulesLibrary.return_context(params)
    query = return_context.query

    render(conn, :index,
      page_title: "Trictrac Rules Library",
      books: RulesLibrary.books(),
      query: query,
      results: if(query == "", do: [], else: RulesLibrary.search(query)),
      return_context: return_context,
      nav_context: RulesLibrary.clear_query(return_context)
    )
  end

  def book(conn, %{"book_slug" => book_slug} = params) do
    return_context = RulesLibrary.return_context(params)

    with {:ok, book} <- RulesLibrary.fetch_book(book_slug) do
      render(conn, :book,
        page_title: "#{book.title} · Trictrac Rules",
        book: book,
        query: return_context.query,
        return_context: return_context,
        nav_context: RulesLibrary.clear_query(return_context)
      )
    else
      :error -> not_found(conn)
    end
  end

  def chapter(conn, %{"book_slug" => book_slug, "chapter_path" => chapter_path} = params) do
    return_context = RulesLibrary.return_context(params)
    route_path = chapter_path |> List.wrap() |> Enum.join("/")

    with {:ok, book} <- RulesLibrary.fetch_book(book_slug),
         {:ok, chapter} <- RulesLibrary.fetch_chapter(book_slug, route_path) do
      {previous_chapter, next_chapter} = chapter_neighbors(book, route_path)

      render(conn, :chapter,
        page_title: "#{chapter.title} · #{book.title}",
        book: book,
        chapter: chapter,
        chapter_html: RulesLibrary.render_chapter_html(chapter, return_context),
        previous_chapter: previous_chapter,
        next_chapter: next_chapter,
        query: return_context.query,
        return_context: return_context,
        nav_context: RulesLibrary.clear_query(return_context)
      )
    else
      :error -> not_found(conn)
    end
  end

  def asset(conn, %{"book_slug" => book_slug, "asset_path" => asset_path}) do
    with {:ok, book} <- RulesLibrary.fetch_book(book_slug),
         {:ok, resolved_path} <- resolve_asset(book, asset_path) do
      case String.downcase(Path.extname(resolved_path)) do
        ".epub" ->
          send_download(conn, {:file, resolved_path}, filename: Path.basename(resolved_path))

        _other ->
          content_type = MIME.from_path(resolved_path) || "application/octet-stream"

          conn
          |> put_resp_content_type(content_type)
          |> send_file(200, resolved_path)
      end
    else
      :error -> not_found(conn)
    end
  end

  defp chapter_neighbors(book, route_path) do
    case Enum.find_index(book.chapters, &(&1.route_path == route_path)) do
      nil ->
        {nil, nil}

      index ->
        {Enum.at(book.chapters, index - 1), Enum.at(book.chapters, index + 1)}
    end
  end

  defp resolve_asset(book, asset_path) do
    relative_path = asset_path |> List.wrap() |> Enum.join("/")
    absolute_path = Path.expand(relative_path, book.docs_root)

    if inside_root?(absolute_path, book.docs_root) and File.regular?(absolute_path) do
      {:ok, absolute_path}
    else
      :error
    end
  end

  defp inside_root?(absolute_path, root) do
    normalized_absolute = Path.expand(absolute_path)
    normalized_root = Path.expand(root)

    normalized_absolute == normalized_root ||
      String.starts_with?(normalized_absolute, normalized_root <> "/")
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(html: HermesTrictracWeb.ErrorHTML)
    |> render(:"404")
  end
end

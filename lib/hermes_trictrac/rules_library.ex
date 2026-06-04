defmodule HermesTrictrac.RulesLibrary do
  use GenServer

  alias HermesTrictrac.Identity

  @book_configs [
    %{slug: "traite-complet-trictrac", source_dir: "traiteCompletTrictrac"},
    %{slug: "cours-complet-de-trictrac", source_dir: "coursCompletdeTrictrac"},
    %{slug: "le-jeu-de-trictrac-rendu-facile", source_dir: "leJeuDeTrictracRenduFacile"}
  ]
  @heading_tags ~w(h1 h2 h3 h4 h5 h6)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def books do
    GenServer.call(__MODULE__, :books)
  end

  def fetch_book(slug) when is_binary(slug) do
    GenServer.call(__MODULE__, {:fetch_book, slug})
  end

  def fetch_chapter(book_slug, route_path) when is_binary(book_slug) and is_binary(route_path) do
    GenServer.call(__MODULE__, {:fetch_chapter, book_slug, route_path})
  end

  def search(query) when is_binary(query) do
    GenServer.call(__MODULE__, {:search, query})
  end

  def search(_query), do: []

  def render_chapter_html(chapter, return_context \\ %{}) when is_map(chapter) do
    chapter.html
    |> Floki.parse_fragment!()
    |> rewrite_return_links(return_context)
    |> Floki.raw_html(pretty: false)
  end

  def return_context(params) when is_map(params) do
    return_to =
      case Map.get(params, "return_to") do
        value when is_binary(value) and value != "" ->
          sanitized = Identity.sanitize_return_to(value)
          if sanitized == "/" and value != "/", do: nil, else: sanitized

        _ ->
          nil
      end

    return_label =
      case Map.get(params, "return_label") do
        value when is_binary(value) and value != "" -> String.slice(value, 0, 120)
        _ -> "Back to game"
      end

    %{
      return_to: return_to,
      return_label: if(return_to, do: return_label, else: nil),
      query: (Map.get(params, "q") || "") |> to_string() |> String.trim()
    }
  end

  def library_path(return_context \\ %{}) do
    with_query("/rules", return_params(return_context, include_query?: true))
  end

  def clear_query(return_context) when is_map(return_context) do
    Map.put(return_context, :query, "")
  end

  def book_path(book_slug, return_context \\ %{}) do
    with_query(
      "/rules/#{encode_segment(book_slug)}",
      return_params(return_context, include_query?: true)
    )
  end

  def chapter_path(book_slug, route_path, return_context \\ %{}) do
    encoded_route =
      route_path
      |> String.split("/", trim: true)
      |> Enum.map_join("/", &encode_segment/1)

    with_query(
      "/rules/#{encode_segment(book_slug)}/#{encoded_route}",
      return_params(return_context, include_query?: true)
    )
  end

  def asset_path(book_slug, asset_path) do
    encoded_asset =
      asset_path
      |> String.split("/", trim: true)
      |> Enum.map_join("/", &encode_segment/1)

    "/rules-assets/#{encode_segment(book_slug)}/#{encoded_asset}"
  end

  @impl true
  def init(_opts) do
    {:ok, load_catalog()}
  end

  @impl true
  def handle_call(:books, _from, state) do
    {:reply, state.books, state}
  end

  def handle_call({:fetch_book, slug}, _from, state) do
    {:reply, Map.fetch(state.books_by_slug, slug), state}
  end

  def handle_call({:fetch_chapter, book_slug, route_path}, _from, state) do
    chapters = Map.get(state.chapters_by_book, book_slug, %{})
    {:reply, Map.fetch(chapters, route_path), state}
  end

  def handle_call({:search, query}, _from, state) do
    {:reply, do_search(state.search_documents, query), state}
  end

  defp load_catalog do
    books =
      @book_configs
      |> Enum.with_index()
      |> Enum.map(fn {config, book_index} -> load_book(config, book_index) end)

    %{
      books: books,
      books_by_slug: Map.new(books, &{&1.slug, &1}),
      chapters_by_book:
        Map.new(books, fn book ->
          {book.slug, Map.new(book.chapters, fn chapter -> {chapter.route_path, chapter} end)}
        end),
      search_documents: build_search_documents(books)
    }
  end

  defp load_book(config, book_index) do
    source_root = Path.join(sources_root(), config.source_dir)
    mkdocs = YamlElixir.read_from_file!(Path.join(source_root, "mkdocs.yml"))
    metadata = parse_metadata(Path.join(source_root, "src/metadata.yaml"))
    docs_root = Path.join(source_root, normalize_docs_dir(mkdocs["docs_dir"]))
    nav = parse_nav(mkdocs["nav"] || [])
    nav_title_map = build_nav_title_map(nav)
    toc_entries = flatten_nav(nav)

    chapters =
      docs_root
      |> Path.join("**/*.md")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.with_index()
      |> Enum.map(fn {source_path, chapter_index} ->
        route_path = source_path |> Path.relative_to(docs_root) |> route_path_for()
        nav_title = Map.get(nav_title_map, route_path)

        render_source_chapter(
          config.slug,
          docs_root,
          source_path,
          nav_title,
          book_index,
          chapter_index
        )
      end)

    first_chapter_path =
      case toc_entries do
        [%{route_path: route_path} | _] when is_binary(route_path) -> route_path
        _ -> chapters |> List.first() |> Map.get(:route_path)
      end

    %{
      slug: config.slug,
      source_dir: config.source_dir,
      source_root: source_root,
      docs_root: docs_root,
      book_index: book_index,
      title: metadata.title || mkdocs["site_name"] || config.slug,
      site_name: mkdocs["site_name"] || metadata.title || config.slug,
      site_author: mkdocs["site_author"],
      repo_url: mkdocs["repo_url"],
      author: metadata.author,
      editors: metadata.editors,
      toc_entries: toc_entries,
      chapters: chapters,
      first_chapter_path: first_chapter_path
    }
  end

  defp render_source_chapter(
         book_slug,
         docs_root,
         source_path,
         nav_title,
         book_index,
         chapter_index
       ) do
    route_path = source_path |> Path.relative_to(docs_root) |> route_path_for()
    markdown = File.read!(source_path)
    source_dir = Path.dirname(source_path)

    fragment =
      markdown
      |> Earmark.as_html!(escape: false)
      |> Floki.parse_fragment!()
      |> rewrite_document(%{
        book_slug: book_slug,
        docs_root: docs_root,
        source_dir: source_dir
      })

    sanitized_html =
      fragment
      |> Floki.raw_html(pretty: false)
      |> HermesTrictrac.RulesLibrary.Scrubber.sanitize()

    sanitized_fragment = Floki.parse_fragment!(sanitized_html)

    title =
      nav_title ||
        extract_first_heading(sanitized_fragment) ||
        infer_title_from_filename(Path.basename(source_path, ".md"))

    text =
      sanitized_fragment
      |> Floki.text(sep: " ")
      |> normalize_whitespace()

    %{
      book_slug: book_slug,
      route_path: route_path,
      source_path: Path.relative_to(source_path, docs_root),
      title: title,
      html: sanitized_html,
      text: text,
      book_index: book_index,
      chapter_index: chapter_index
    }
  end

  defp build_search_documents(books) do
    for book <- books,
        chapter <- book.chapters do
      %{
        book_slug: book.slug,
        book_title: book.title,
        book_index: book.book_index,
        chapter_index: chapter.chapter_index,
        route_path: chapter.route_path,
        title: chapter.title,
        title_downcase: String.downcase(chapter.title),
        book_title_downcase: String.downcase(book.title),
        text: chapter.text,
        text_downcase: String.downcase(chapter.text)
      }
    end
  end

  defp do_search(_documents, query) when not is_binary(query), do: []

  defp do_search(documents, query) do
    needle = query |> String.trim() |> String.downcase()

    if needle == "" do
      []
    else
      documents
      |> Enum.reduce([], fn document, acc ->
        case search_rank(document, needle) do
          nil ->
            acc

          {rank, position} ->
            [
              %{
                book_slug: document.book_slug,
                book_title: document.book_title,
                route_path: document.route_path,
                title: document.title,
                snippet: snippet_for(document.text, query),
                rank: rank,
                position: position,
                book_index: document.book_index,
                chapter_index: document.chapter_index
              }
              | acc
            ]
        end
      end)
      |> Enum.sort_by(fn result ->
        {result.rank, result.position, result.book_index, result.chapter_index, result.title}
      end)
    end
  end

  defp search_rank(document, needle) do
    cond do
      String.starts_with?(document.title_downcase, needle) ->
        {0, 0}

      String.contains?(document.title_downcase, needle) ->
        {1, binary_match_position(document.title_downcase, needle)}

      String.contains?(document.book_title_downcase, needle) ->
        {2, binary_match_position(document.book_title_downcase, needle)}

      String.contains?(document.text_downcase, needle) ->
        {3, binary_match_position(document.text_downcase, needle)}

      true ->
        nil
    end
  end

  defp snippet_for(text, query) do
    normalized_query = query |> String.trim() |> String.downcase()
    normalized_text = String.downcase(text)

    case :binary.match(normalized_text, normalized_query) do
      {position, length} ->
        start_at = max(position - 90, 0)
        stop_at = min(position + length + 90, String.length(text))
        prefix = if start_at > 0, do: "…", else: ""
        suffix = if stop_at < String.length(text), do: "…", else: ""

        prefix <>
          (text |> String.slice(start_at, max(stop_at - start_at, 0)) |> normalize_whitespace()) <>
          suffix

      :nomatch ->
        text
        |> String.slice(0, 180)
        |> normalize_whitespace()
    end
  end

  defp rewrite_return_links(fragment, return_context) do
    return_params = return_params(return_context, include_query?: false)

    if map_size(return_params) == 0 do
      fragment
    else
      {rewritten, _state} =
        walk_nodes(fragment, %{}, fn
          {"a", attrs, children} = node, state ->
            href = attr_value(attrs, "href")

            case href do
              <<"/rules", _::binary>> ->
                updated =
                  {"a", put_attr(attrs, "href", append_query(href, return_params)), children}

                {updated, state}

              _ ->
                {node, state}
            end

          node, state ->
            {node, state}
        end)

      rewritten
    end
  end

  defp rewrite_document(fragment, context) do
    {rewritten, _state} =
      walk_nodes(fragment, %{heading_counts: %{}}, fn
        {tag, attrs, children}, state when tag in @heading_tags ->
          text = Floki.text([{tag, attrs, children}], sep: " ") |> normalize_whitespace()
          {id, next_counts} = unique_heading_id(text, state.heading_counts)
          updated = {tag, put_attr(attrs, "id", id), children}
          {updated, %{state | heading_counts: next_counts}}

        {"a", attrs, children}, state ->
          {tag, attrs, children} = normalize_named_anchor({"a", attrs, children})

          case tag do
            "a" ->
              {{tag, rewrite_link_attrs(attrs, "href", context), children}, state}

            _other ->
              {{tag, attrs, children}, state}
          end

        {"img", attrs, children}, state ->
          attrs = rewrite_link_attrs(attrs, "src", context)
          {{"img", attrs, children}, state}

        node, state ->
          {node, state}
      end)

    rewritten
  end

  defp walk_nodes(nodes, state, updater) when is_list(nodes) do
    Enum.map_reduce(nodes, state, fn node, acc ->
      walk_node(node, acc, updater)
    end)
  end

  defp walk_node({tag, attrs, children}, state, updater) do
    {children, state} = walk_nodes(children, state, updater)
    updater.({tag, attrs, children}, state)
  end

  defp walk_node(node, state, _updater), do: {node, state}

  defp rewrite_link_attrs(attrs, attr_name, context) do
    case attr_value(attrs, attr_name) do
      nil -> attrs
      value -> put_attr(attrs, attr_name, rewrite_relative_reference(value, context))
    end
  end

  defp rewrite_relative_reference(value, _context) when not is_binary(value), do: value

  defp rewrite_relative_reference("#" <> _ = value, _context), do: value

  defp rewrite_relative_reference(value, context) do
    uri = URI.parse(value)

    cond do
      uri.scheme not in [nil, ""] ->
        value

      is_binary(uri.path) and String.starts_with?(uri.path, "/") ->
        value

      true ->
        case normalize_relative_path(uri.path) do
          nil ->
            value

          path ->
            absolute = Path.expand(path, context.source_dir)

            if inside_docs_root?(absolute, context.docs_root) do
              relative = Path.relative_to(absolute, context.docs_root)
              fragment = if uri.fragment, do: "##{uri.fragment}", else: ""

              if String.ends_with?(relative, ".md") do
                chapter_path(context.book_slug, route_path_for(relative)) <> fragment
              else
                asset_path(context.book_slug, relative)
              end
            else
              value
            end
        end
    end
  end

  defp binary_match_position(text, needle) do
    case :binary.match(text, needle) do
      {position, _length} -> position
      :nomatch -> 0
    end
  end

  defp normalize_named_anchor({"a", attrs, children}) do
    name = attr_value(attrs, "name") |> normalize_anchor_name()

    case {name, attr_value(attrs, "href"), attr_value(attrs, "id")} do
      {name, nil, _id} when is_binary(name) and name != "" ->
        {"span", attrs |> delete_attr("name") |> put_attr("id", name), children}

      {name, _href, nil} when is_binary(name) and name != "" ->
        {"a", put_attr(attrs, "id", name), children}

      _other ->
        {"a", attrs, children}
    end
  end

  defp extract_first_heading(fragment) do
    fragment
    |> Floki.find(Enum.join(@heading_tags, ", "))
    |> List.first()
    |> case do
      nil -> nil
      node -> Floki.text([node], sep: " ") |> normalize_whitespace()
    end
  end

  defp parse_nav(items) when is_list(items) do
    Enum.flat_map(items, fn
      item when is_binary(item) ->
        [
          %{
            title: infer_title_from_filename(Path.basename(item, ".md")),
            route_path: route_path_for(item)
          }
        ]

      item when is_map(item) ->
        Enum.flat_map(item, fn {title, value} ->
          cond do
            is_binary(value) ->
              [%{title: title, route_path: route_path_for(value), children: []}]

            is_list(value) ->
              [%{title: title, route_path: nil, children: parse_nav(value)}]

            true ->
              []
          end
        end)

      _other ->
        []
    end)
  end

  defp flatten_nav(nodes, depth \\ 0) do
    Enum.flat_map(nodes, fn node ->
      current =
        if is_binary(node.route_path) do
          [%{title: node.title, route_path: node.route_path, depth: depth}]
        else
          []
        end

      current ++ flatten_nav(Map.get(node, :children, []), depth + 1)
    end)
  end

  defp build_nav_title_map(nodes) do
    Enum.reduce(nodes, %{}, fn node, acc ->
      acc =
        if is_binary(node.route_path) do
          Map.put(acc, node.route_path, node.title)
        else
          acc
        end

      Map.merge(acc, build_nav_title_map(Map.get(node, :children, [])))
    end)
  end

  defp parse_metadata(path) do
    document =
      path
      |> File.read!()
      |> String.trim()
      |> String.trim_leading("---")
      |> String.trim_trailing("---")
      |> String.trim()

    yaml = YamlElixir.read_from_string!(document)
    creators = yaml["creator"] || []

    %{
      title: extract_title(yaml["title"]),
      author: creator_text(creators, "author"),
      editors:
        creators
        |> Enum.filter(&(Map.get(&1, "role") == "editor"))
        |> Enum.map(&Map.get(&1, "text"))
        |> Enum.reject(&is_nil/1)
    }
  end

  defp creator_text(creators, role) do
    creators
    |> Enum.find(&(Map.get(&1, "role") == role))
    |> case do
      nil -> nil
      creator -> Map.get(creator, "text")
    end
  end

  defp extract_title([%{"text" => text} | _rest]) when is_binary(text), do: text
  defp extract_title(text) when is_binary(text), do: text
  defp extract_title(_other), do: nil

  defp unique_heading_id(text, counts) do
    base =
      text
      |> slugify()
      |> case do
        "" -> "section"
        value -> value
      end

    case Map.get(counts, base, 0) do
      0 ->
        {base, Map.put(counts, base, 1)}

      count ->
        {"#{base}-#{count + 1}", Map.put(counts, base, count + 1)}
    end
  end

  defp slugify(text) do
    text
    |> String.downcase()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.replace(~r/[^\p{L}\p{N}]+/u, "-")
    |> String.trim("-")
  end

  defp infer_title_from_filename(name) do
    name
    |> String.replace(~r/[-_]+/, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp route_path_for(path) do
    path
    |> String.trim()
    |> String.trim_leading("./")
    |> String.trim_trailing("/")
    |> String.replace_suffix(".md", "")
  end

  defp normalize_docs_dir(nil), do: "src"

  defp normalize_docs_dir(dir),
    do: dir |> to_string() |> String.trim() |> String.trim_trailing("/")

  defp normalize_relative_path(nil), do: nil

  defp normalize_relative_path(path) do
    path
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      value -> String.trim_trailing(value, "/")
    end
  end

  defp normalize_anchor_name(nil), do: nil

  defp normalize_anchor_name(name) do
    name
    |> to_string()
    |> String.trim()
    |> String.replace(~r/["'“”‘’]/u, "")
  end

  defp inside_docs_root?(absolute, docs_root) do
    normalized_absolute = Path.expand(absolute)
    normalized_root = Path.expand(docs_root)

    normalized_absolute == normalized_root ||
      String.starts_with?(normalized_absolute, normalized_root <> "/")
  end

  defp attr_value(attrs, name) do
    attrs
    |> Enum.find_value(fn
      {^name, value} -> value
      _other -> nil
    end)
  end

  defp put_attr(attrs, name, value) do
    attrs
    |> delete_attr(name)
    |> Kernel.++([{name, value}])
  end

  defp delete_attr(attrs, name) do
    attrs
    |> Enum.reject(fn
      {^name, _existing} -> true
      _other -> false
    end)
  end

  defp return_params(return_context, opts) do
    include_query? = Keyword.get(opts, :include_query?, false)

    params =
      case return_context do
        %{return_to: return_to, return_label: return_label} when is_binary(return_to) ->
          %{
            "return_to" => return_to,
            "return_label" => return_label || "Back to game"
          }

        _ ->
          %{}
      end

    if include_query? do
      case return_context do
        %{query: query} when is_binary(query) and query != "" -> Map.put(params, "q", query)
        _ -> params
      end
    else
      params
    end
  end

  defp with_query(path, params) when map_size(params) == 0, do: path
  defp with_query(path, params), do: path <> "?" <> URI.encode_query(params)

  defp append_query(path, params) when map_size(params) == 0, do: path

  defp append_query(path, params) do
    uri = URI.parse(path)
    existing = URI.decode_query(uri.query || "")
    merged_query = Map.merge(existing, params) |> URI.encode_query()
    updated = %{uri | query: merged_query}
    URI.to_string(updated)
  end

  defp encode_segment(value) do
    URI.encode(value, &URI.char_unreserved?/1)
  end

  defp normalize_whitespace(text) do
    text
    |> to_string()
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp sources_root do
    candidates = [
      System.get_env("HERMES_TRICTRAC_RULES_SOURCES_DIR"),
      Path.expand("gamedocs/sources", File.cwd!()),
      Path.expand("../../../../gamedocs/sources", Application.app_dir(:hermes_trictrac)),
      "/app/gamedocs/sources"
    ]
    |> Enum.reject(&is_nil/1)

    Enum.find(candidates, &File.dir?/1) ||
      raise "Unable to find gamedocs/sources for the Trictrac rules library"
  end
end

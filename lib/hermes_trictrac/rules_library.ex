defmodule HermesTrictrac.RulesLibrary do
  use GenServer
  require Logger

  alias HermesTrictrac.Identity
  alias HermesTrictrac.Rules.Registry
  alias HermesTrictrac.RulesLibrary.{Markdown, Scrubber}

  @compile {:no_warn_undefined, [Floki, MDEx, YamlElixir]}

  @language_options [
    %{id: "en", label: "English"},
    %{id: "fr", label: "Français"},
    %{id: "de", label: "Deutsch"},
    %{id: "sv", label: "Svenska"},
    %{id: "da", label: "Dansk"}
  ]
  @supported_languages MapSet.new(Enum.map(@language_options, & &1.id))
  @core_trictrac_variants ~w(trictrac_classique trictrac_aecrire trictrac_combine)
  @multi_rules_variants @core_trictrac_variants ++ ~w(toccategli toc plein brade)

  @book_configs [
    %{
      slug: "traite-complet-trictrac",
      source_dir: "traiteCompletTrictrac",
      languages: ~w(fr),
      variant_ids: @core_trictrac_variants
    },
    %{
      slug: "cours-complet-de-trictrac",
      source_dir: "coursCompletdeTrictrac",
      languages: ~w(fr),
      variant_ids: @core_trictrac_variants
    },
    %{
      slug: "le-jeu-de-trictrac-rendu-facile",
      source_dir: "leJeuDeTrictracRenduFacile",
      languages: ~w(fr),
      variant_ids: @core_trictrac_variants
    },
    %{
      slug: "english-rules-trictrac",
      source_path: "english_rules_trictrac.md",
      title: "Trictrac: Complete Table Rulebook",
      site_name: "English Trictrac Rulebook",
      languages: ~w(en),
      variant_ids: @core_trictrac_variants
    },
    %{
      slug: "multi-rules",
      source_path: "multilingual/multi-rules.md",
      title: "Multilingual Trictrac, Toccategli, Toc, Plein, and Bräde Rules",
      site_name: "Multilingual Rules",
      languages: ~w(fr de sv da),
      variant_ids: @multi_rules_variants
    }
  ]
  @heading_tags ~w(h1 h2 h3 h4 h5 h6)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def language_options, do: @language_options

  def language_label(language) do
    @language_options
    |> Enum.find(&(&1.id == normalize_language(language)))
    |> case do
      nil -> to_string(language)
      option -> option.label
    end
  end

  def variant_label(variant_id) when is_binary(variant_id), do: variant_title(variant_id)
  def variant_label(_variant_id), do: ""

  def variant_options do
    GenServer.call(__MODULE__, :variant_options)
  end

  def books(filters \\ %{}) do
    GenServer.call(__MODULE__, {:books, normalize_filters(filters)})
  end

  def fetch_book(slug, filters \\ %{}) when is_binary(slug) do
    GenServer.call(__MODULE__, {:fetch_book, slug, normalize_filters(filters)})
  end

  def fetch_chapter(book_slug, route_path, filters \\ [])
      when is_binary(book_slug) and is_binary(route_path) do
    GenServer.call(
      __MODULE__,
      {:fetch_chapter, book_slug, route_path, normalize_filters(filters)}
    )
  end

  def search(query, filters \\ %{})

  def search(query, filters) when is_binary(query) do
    GenServer.call(__MODULE__, {:search, query, normalize_filters(filters)})
  end

  def search(_query, _filters), do: []

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
      query: (Map.get(params, "q") || "") |> to_string() |> String.trim(),
      language: normalize_language(Map.get(params, "lang"), "en"),
      variant_id: normalize_variant_id(Map.get(params, "variant_id"))
    }
  end

  def library_path(return_context \\ %{}) do
    with_query("/rules", return_params(return_context, include_query?: true))
  end

  def clear_query(return_context) when is_map(return_context) do
    Map.put(return_context, :query, "")
  end

  def clear_variant(return_context) when is_map(return_context) do
    Map.put(return_context, :variant_id, nil)
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
  def handle_call(:variant_options, _from, state) do
    {:reply, state.variant_options, state}
  end

  def handle_call({:books, filters}, _from, state) do
    {:reply, filter_books(state.books, filters), state}
  end

  def handle_call({:fetch_book, slug, filters}, _from, state) do
    reply =
      with {:ok, book} <- Map.fetch(state.books_by_slug, slug),
           true <- book_matches_filters?(book, filters) do
        {:ok, book}
      else
        _ -> :error
      end

    {:reply, reply, state}
  end

  def handle_call({:fetch_chapter, book_slug, route_path, filters}, _from, state) do
    reply =
      with {:ok, book} <- Map.fetch(state.books_by_slug, book_slug),
           true <- book_matches_filters?(book, filters),
           chapters <- Map.get(state.chapters_by_book, book_slug, %{}),
           {:ok, chapter} <- Map.fetch(chapters, route_path) do
        {:ok, chapter}
      else
        _ -> :error
      end

    {:reply, reply, state}
  end

  def handle_call({:search, query, filters}, _from, state) do
    documents = Enum.filter(state.search_documents, &document_matches_filters?(&1, filters))
    {:reply, do_search(documents, query), state}
  end

  defp load_catalog do
    books =
      @book_configs
      |> Enum.with_index()
      |> Enum.map(fn {config, book_index} -> load_book(config, book_index) end)
      |> finalize_catalog_links()

    %{
      books: books,
      books_by_slug: Map.new(books, &{&1.slug, &1}),
      chapters_by_book:
        Map.new(books, fn book ->
          {book.slug, Map.new(book.chapters, fn chapter -> {chapter.route_path, chapter} end)}
        end),
      search_documents: build_search_documents(books),
      variant_options: build_variant_options(books)
    }
  end

  defp load_book(%{source_dir: _source_dir} = config, book_index) do
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
      languages: normalize_languages(config.languages),
      variant_ids: normalize_variant_ids(config.variant_ids),
      toc_entries: toc_entries,
      chapters: chapters,
      first_chapter_path: first_chapter_path
    }
  end

  defp load_book(%{source_path: source_path} = config, book_index) do
    absolute_source_path = Path.join(gamedocs_root(), source_path)
    docs_root = Path.dirname(absolute_source_path)
    route_path = absolute_source_path |> Path.relative_to(docs_root) |> route_path_for()

    chapter =
      render_source_chapter(
        config.slug,
        docs_root,
        absolute_source_path,
        Map.get(config, :title),
        book_index,
        0
      )

    title = Map.get(config, :title) || chapter.title || config.slug

    %{
      slug: config.slug,
      source_dir: nil,
      source_root: docs_root,
      docs_root: docs_root,
      book_index: book_index,
      title: title,
      site_name: Map.get(config, :site_name) || title,
      site_author: Map.get(config, :site_author),
      repo_url: Map.get(config, :repo_url),
      author: Map.get(config, :author),
      editors: Map.get(config, :editors, []),
      languages: normalize_languages(config.languages),
      variant_ids: normalize_variant_ids(config.variant_ids),
      toc_entries: [%{title: title, route_path: route_path, depth: 0}],
      chapters: [chapter],
      first_chapter_path: route_path
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

    fragment =
      markdown
      |> Markdown.to_html!()
      |> Floki.parse_fragment!()
      |> prepare_document()

    sanitized_html =
      fragment
      |> Floki.raw_html(pretty: false)
      |> Scrubber.sanitize()

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
      outline_entries: outline_entries(sanitized_fragment),
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
        languages: book.languages,
        variant_ids: book.variant_ids,
        title_downcase: String.downcase(chapter.title),
        book_title_downcase: String.downcase(book.title),
        text: chapter.text,
        text_downcase: String.downcase(chapter.text)
      }
    end
  end

  defp build_variant_options(books) do
    books
    |> Enum.flat_map(& &1.variant_ids)
    |> Enum.uniq()
    |> Enum.map(fn variant_id -> %{id: variant_id, label: variant_title(variant_id)} end)
    |> Enum.sort_by(&String.downcase(&1.label))
  end

  defp filter_books(books, filters) do
    Enum.filter(books, &book_matches_filters?(&1, filters))
  end

  defp book_matches_filters?(book, filters) do
    language_matches?(book.languages, filters.language) and
      variant_matches?(book.variant_ids, filters.variant_id)
  end

  defp document_matches_filters?(document, filters) do
    language_matches?(document.languages, filters.language) and
      variant_matches?(document.variant_ids, filters.variant_id)
  end

  defp language_matches?(_languages, nil), do: true

  defp language_matches?(languages, language) do
    language in List.wrap(languages)
  end

  defp variant_matches?(_variant_ids, nil), do: true

  defp variant_matches?(variant_ids, variant_id) do
    variant_id in List.wrap(variant_ids)
  end

  defp normalize_filters(filters) when is_map(filters) do
    %{
      language:
        normalize_language(
          Map.get(filters, :language) || Map.get(filters, "language") || Map.get(filters, "lang") ||
            Map.get(filters, :lang)
        ),
      variant_id:
        normalize_variant_id(
          Map.get(filters, :variant_id) || Map.get(filters, "variant_id") ||
            Map.get(filters, "game_type") || Map.get(filters, :game_type)
        )
    }
  end

  defp normalize_filters(_filters), do: %{language: nil, variant_id: nil}

  defp normalize_languages(languages) do
    languages
    |> List.wrap()
    |> Enum.map(&normalize_language/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_variant_ids(variant_ids) do
    variant_ids
    |> List.wrap()
    |> Enum.map(&normalize_variant_id/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_language(language, default \\ nil)

  defp normalize_language(nil, default), do: default

  defp normalize_language(language, default) do
    normalized =
      language
      |> to_string()
      |> String.trim()
      |> String.downcase()
      |> String.split("-", parts: 2)
      |> List.first()

    if MapSet.member?(@supported_languages, normalized), do: normalized, else: default
  end

  defp normalize_variant_id(nil), do: nil

  defp normalize_variant_id(variant_id) do
    variant_id
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      value -> String.slice(value, 0, 120)
    end
  end

  defp variant_title(variant_id) do
    variant_id
    |> Registry.fetch!()
    |> Map.get(:title, variant_id)
  rescue
    _ -> variant_id
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

  defp finalize_catalog_links(books) do
    context = %{
      books_by_slug: Map.new(books, &{&1.slug, &1}),
      chapter_lookups: Map.new(books, &{&1.slug, build_chapter_lookup(&1)}),
      anchor_index: build_anchor_index(books)
    }

    Enum.map(books, &rewrite_book_links(&1, context))
  end

  defp rewrite_book_links(book, context) do
    chapters = Enum.map(book.chapters, &rewrite_chapter_links(&1, book, context))
    %{book | chapters: chapters}
  end

  defp rewrite_chapter_links(chapter, book, context) do
    fragment =
      chapter.html
      |> Floki.parse_fragment!()
      |> rewrite_catalog_links(%{book: book, chapter: chapter, context: context})

    html =
      fragment
      |> Floki.raw_html(pretty: false)
      |> Scrubber.sanitize()

    sanitized_fragment = Floki.parse_fragment!(html)

    %{
      chapter
      | html: html,
        text: sanitized_fragment |> Floki.text(sep: " ") |> normalize_whitespace(),
        outline_entries: outline_entries(sanitized_fragment)
    }
  end

  defp build_chapter_lookup(book) do
    Enum.reduce(book.chapters, %{}, fn chapter, lookup ->
      aliases = [chapter.route_path, chapter.source_path, "#{chapter.route_path}.md"]

      Enum.reduce(aliases, lookup, fn path, acc ->
        case canonical_route_path(path) do
          "" -> acc
          key -> Map.put_new(acc, key, chapter.route_path)
        end
      end)
    end)
  end

  defp build_anchor_index(books) do
    Map.new(books, fn book ->
      chapter_anchors =
        Map.new(book.chapters, fn chapter ->
          anchors =
            chapter.html
            |> Floki.parse_fragment!()
            |> Floki.find("[id]")
            |> Enum.reduce(%{}, fn node, acc ->
              case Floki.attribute(node, "id") do
                [id | _rest] when is_binary(id) -> put_anchor_aliases(acc, id)
                _other -> acc
              end
            end)

          {chapter.route_path, anchors}
        end)

      {book.slug, chapter_anchors}
    end)
  end

  defp put_anchor_aliases(anchors, id) do
    canonical = canonical_anchor(id)

    [
      id,
      decode_uri_component(id),
      canonical,
      compact_anchor(canonical) | heading_number_aliases(canonical)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.reduce(anchors, fn alias_name, acc -> Map.put_new(acc, alias_name, id) end)
  end

  defp rewrite_catalog_links(fragment, link_context) do
    {rewritten, _state} =
      walk_nodes(fragment, %{}, fn
        {"a", attrs, children}, state ->
          attrs = rewrite_catalog_link_attrs(attrs, "href", :link, link_context)
          {{"a", attrs, children}, state}

        {"img", attrs, children}, state ->
          attrs = rewrite_catalog_link_attrs(attrs, "src", :image, link_context)
          {{"img", attrs, children}, state}

        node, state ->
          {node, state}
      end)

    rewritten
  end

  defp rewrite_catalog_link_attrs(attrs, attr_name, kind, context) do
    case attr_value(attrs, attr_name) do
      value when is_binary(value) ->
        put_attr(attrs, attr_name, rewrite_catalog_reference(value, kind, context))

      _other ->
        attrs
    end
  end

  defp rewrite_catalog_reference(value, kind, context) do
    uri = URI.parse(value)

    cond do
      external_reference?(uri, value) ->
        value

      kind == :image ->
        rewrite_image_reference(value, uri, context)

      true ->
        rewrite_document_reference(value, uri, context)
    end
  end

  defp external_reference?(uri, value) do
    is_binary(uri.scheme) or is_binary(uri.host) or String.starts_with?(value, "//") or
      (is_binary(uri.path) and String.starts_with?(uri.path, "/") and
         not String.starts_with?(uri.path, "/rules/"))
  end

  defp rewrite_image_reference(value, uri, context) do
    with {:ok, relative_path} <- relative_docs_path(uri.path, context),
         true <- is_binary(relative_path) and relative_path != "" do
      asset_path(context.book.slug, relative_path) <> query_and_fragment(uri)
    else
      _other -> value
    end
  end

  defp rewrite_document_reference(value, uri, context) do
    case document_target(uri, context) do
      {:ok, book_slug, route_path} ->
        rewrite_target_anchor(value, uri, book_slug, route_path, context)

      {:asset, relative_path} ->
        asset_path(context.book.slug, relative_path) <> query_and_fragment(uri)

      :not_internal ->
        value

      :unresolved ->
        warn_unresolved_link(value, context)
        value
    end
  end

  defp document_target(%URI{path: path}, context) when path in [nil, ""] do
    if is_binary(context.chapter.route_path) do
      {:ok, context.book.slug, context.chapter.route_path}
    else
      :not_internal
    end
  end

  defp document_target(%URI{path: "/rules/" <> _rest} = uri, context) do
    rules_path_target(uri.path, context)
  end

  defp document_target(%URI{path: path}, context) do
    case relative_docs_path(path, context) do
      {:ok, relative_path} ->
        lookup = Map.fetch!(context.context.chapter_lookups, context.book.slug)

        case chapter_route_for(relative_path, lookup) do
          nil ->
            if asset_reference?(relative_path, context.book) do
              {:asset, relative_path}
            else
              :unresolved
            end

          route_path ->
            {:ok, context.book.slug, route_path}
        end

      :outside ->
        :not_internal
    end
  end

  defp rules_path_target(path, context) do
    case path |> String.split("/", trim: true) |> Enum.map(&decode_uri_component/1) do
      ["rules", book_slug | route_segments] ->
        with {:ok, book} <- Map.fetch(context.context.books_by_slug, book_slug),
             lookup <- Map.fetch!(context.context.chapter_lookups, book.slug),
             route_path <- route_for_rules_path(route_segments, book, lookup),
             true <- is_binary(route_path) do
          {:ok, book.slug, route_path}
        else
          _other -> :unresolved
        end

      _other ->
        :not_internal
    end
  end

  defp route_for_rules_path([], book, _lookup), do: book.first_chapter_path

  defp route_for_rules_path(route_segments, _book, lookup) do
    route_segments
    |> Enum.join("/")
    |> chapter_route_for(lookup)
  end

  defp chapter_route_for(relative_path, lookup) do
    relative_path
    |> route_candidates()
    |> Enum.find_value(&Map.get(lookup, &1))
  end

  defp route_candidates(path) do
    canonical = canonical_route_path(path)

    case canonical do
      "" -> ["index"]
      value -> [value, value <> "/index"]
    end
  end

  defp rewrite_target_anchor(value, uri, book_slug, route_path, context) do
    case uri.fragment do
      fragment when is_binary(fragment) and fragment != "" ->
        case resolve_anchor(book_slug, route_path, fragment, context.context.anchor_index) do
          {:ok, resolved_route_path, id} ->
            chapter_path(book_slug, resolved_route_path) <>
              query_string(uri) <>
              "#" <>
              encode_fragment(id)

          :error ->
            warn_unresolved_link(value, context)

            chapter_path(book_slug, route_path) <>
              query_string(uri) <>
              "#" <>
              encode_fragment(decode_uri_component(fragment))
        end

      _other ->
        chapter_path(book_slug, route_path) <> query_string(uri)
    end
  end

  defp resolve_anchor(book_slug, route_path, fragment, anchor_index) do
    anchors = get_in(anchor_index, [book_slug, route_path]) || %{}
    aliases = [fragment, decode_uri_component(fragment), canonical_anchor(fragment)]

    case find_anchor(anchors, aliases) do
      {:ok, id} -> {:ok, route_path, id}
      :error -> find_catalog_anchor(book_slug, aliases, anchor_index)
    end
  end

  defp find_anchor(anchors, aliases) do
    aliases
    |> Enum.flat_map(&[&1, compact_anchor(&1)])
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
    |> Enum.find_value(:error, fn alias_name ->
      case Map.fetch(anchors, alias_name) do
        {:ok, id} -> {:ok, id}
        :error -> nil
      end
    end)
  end

  defp find_catalog_anchor(book_slug, aliases, anchor_index) do
    chapter_anchors = Map.get(anchor_index, book_slug, %{})

    exact_matches =
      for {candidate_route_path, anchors} <- chapter_anchors,
          {:ok, id} <- [find_anchor(anchors, aliases)],
          do: {candidate_route_path, id}

    case Enum.uniq(exact_matches) do
      [{route_path, id}] ->
        {:ok, route_path, id}

      _other ->
        find_similar_catalog_anchor(chapter_anchors, aliases)
    end
  end

  defp find_similar_catalog_anchor(chapter_anchors, aliases) do
    source_tokens =
      aliases
      |> Enum.find_value(fn alias_name ->
        tokens = significant_anchor_tokens(alias_name)
        if MapSet.size(tokens) > 0, do: tokens
      end)

    if is_nil(source_tokens) do
      :error
    else
      matches =
        for {route_path, anchors} <- chapter_anchors,
            id <- anchors |> Map.values() |> Enum.uniq(),
            score = token_overlap_score(source_tokens, significant_anchor_tokens(id)),
            score >= 2,
            do: {score, route_path, id}

      case matches |> Enum.sort_by(fn {score, route_path, id} -> {-score, route_path, id} end) do
        [{score, route_path, id}, {next_score, _next_route_path, _next_id} | _rest]
        when score > next_score ->
          {:ok, route_path, id}

        [{_score, route_path, id}] ->
          {:ok, route_path, id}

        _other ->
          :error
      end
    end
  end

  defp significant_anchor_tokens(value) do
    value
    |> canonical_anchor()
    |> String.split("-", trim: true)
    |> Enum.filter(&(String.length(&1) >= 4))
    |> MapSet.new()
  end

  defp token_overlap_score(left, right), do: MapSet.intersection(left, right) |> MapSet.size()

  defp relative_docs_path(path, _context) when not is_binary(path), do: :outside

  defp relative_docs_path(path, context) do
    normalized_path = path |> decode_uri_component() |> String.trim()

    if normalized_path == "" do
      {:ok, ""}
    else
      source_path = Path.join(context.book.docs_root, context.chapter.source_path)
      absolute_path = Path.expand(normalized_path, Path.dirname(source_path))

      if inside_docs_root?(absolute_path, context.book.docs_root) do
        {:ok, Path.relative_to(absolute_path, context.book.docs_root)}
      else
        :outside
      end
    end
  end

  defp asset_reference?(relative_path, book) do
    absolute_path = Path.join(book.docs_root, relative_path)
    File.regular?(absolute_path) and not String.ends_with?(String.downcase(relative_path), ".md")
  end

  defp query_and_fragment(uri), do: query_string(uri) <> fragment_string(uri)
  defp query_string(%URI{query: nil}), do: ""
  defp query_string(%URI{query: ""}), do: ""
  defp query_string(%URI{query: query}), do: "?" <> query
  defp fragment_string(%URI{fragment: nil}), do: ""
  defp fragment_string(%URI{fragment: ""}), do: ""
  defp fragment_string(%URI{fragment: fragment}), do: "#" <> encode_fragment(fragment)

  defp warn_unresolved_link(value, context) do
    Logger.warning(
      "Unresolved internal Rules Library link #{inspect(value)} in " <>
        "#{context.book.slug}/#{context.chapter.route_path}"
    )
  end

  defp prepare_document(fragment) do
    {rewritten, _state} =
      walk_nodes(fragment, %{heading_counts: %{}}, fn
        {tag, attrs, children}, state when tag in @heading_tags ->
          text = Floki.text([{tag, attrs, children}], sep: " ") |> normalize_whitespace()
          {id, next_counts} = unique_heading_id(text, state.heading_counts)
          updated = {tag, put_attr(attrs, "id", id), children}
          {updated, %{state | heading_counts: next_counts}}

        {"a", attrs, children}, state ->
          {tag, attrs, children} = normalize_named_anchor({"a", attrs, children})
          {{tag, attrs, children}, state}

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

  defp outline_entries(fragment) do
    headings =
      fragment
      |> Floki.find(Enum.join(@heading_tags, ", "))
      |> Enum.flat_map(fn {tag, _attrs, _children} = node ->
        with [id | _rest] when is_binary(id) and id != "" <- Floki.attribute(node, "id"),
             title when title != "" <- Floki.text([node], sep: " ") |> normalize_whitespace() do
          level = tag |> String.trim_leading("h") |> String.to_integer()
          [%{id: id, title: title, level: level}]
        else
          _other -> []
        end
      end)

    base_level = headings |> Enum.map(& &1.level) |> Enum.min(fn -> 1 end)

    Enum.map(headings, fn heading ->
      heading
      |> Map.delete(:level)
      |> Map.put(:depth, max(heading.level - base_level, 0))
    end)
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

  defp canonical_anchor(nil), do: ""

  defp canonical_anchor(anchor) do
    anchor
    |> decode_uri_component()
    |> normalize_anchor_name()
    |> slugify()
  end

  defp compact_anchor(nil), do: ""
  defp compact_anchor(anchor), do: String.replace(anchor, "-", "")

  defp heading_number_aliases(anchor) do
    case Regex.run(~r/^(?:[a-z]?\d+(?:-\d+)*)-(.+)$/u, anchor) do
      [_match, title] -> [title, compact_anchor(title)]
      _other -> []
    end
  end

  defp canonical_route_path(path) do
    path
    |> decode_uri_component()
    |> String.trim()
    |> String.replace("\\", "/")
    |> String.trim_leading("./")
    |> String.trim("/")
    |> String.replace(~r/\.md$/i, "")
    |> String.split("/", trim: true)
    |> Enum.map(&slugify/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("/")
  end

  defp decode_uri_component(nil), do: nil

  defp decode_uri_component(value) do
    URI.decode(to_string(value))
  rescue
    ArgumentError -> to_string(value)
  end

  defp encode_fragment(value) do
    URI.encode(to_string(value), &URI.char_unreserved?/1)
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

    params =
      case return_context do
        %{language: language} when is_binary(language) and language != "" ->
          Map.put(params, "lang", language)

        _ ->
          params
      end

    params =
      case return_context do
        %{variant_id: variant_id} when is_binary(variant_id) and variant_id != "" ->
          Map.put(params, "variant_id", variant_id)

        _ ->
          params
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
    candidates =
      [
        System.get_env("HERMES_TRICTRAC_RULES_SOURCES_DIR"),
        Path.expand("gamedocs/sources", File.cwd!()),
        Path.expand("../../../../gamedocs/sources", Application.app_dir(:hermes_trictrac)),
        "/app/gamedocs/sources"
      ]
      |> Enum.reject(&is_nil/1)

    Enum.find(candidates, &File.dir?/1) ||
      raise "Unable to find gamedocs/sources for the Trictrac rules library"
  end

  defp gamedocs_root do
    candidates =
      [
        System.get_env("HERMES_TRICTRAC_GAMEDOCS_DIR"),
        Path.expand("gamedocs", File.cwd!()),
        Path.expand("../../../../gamedocs", Application.app_dir(:hermes_trictrac)),
        "/app/gamedocs"
      ]
      |> Enum.reject(&is_nil/1)

    Enum.find(candidates, &File.dir?/1) ||
      raise "Unable to find gamedocs for the Trictrac rules library"
  end
end

defmodule HermesTrictracWeb.PageController do
  use HermesTrictracWeb, :controller

  alias HermesTrictrac.{ComputerPlayCatalog, GameServer, Identity, LobbyCatalog, RulesLibrary}
  alias HermesTrictrac.Rules.Registry

  plug :require_table_identity when action in [:game]

  # Kept as a compile-time alias so existing helpers stay simple; the values
  # themselves are server-owned by LobbyCatalog and serialized for native UIs.
  @multi_seat_formats LobbyCatalog.multi_seat_formats()
  @cash_per_jeton_variants LobbyCatalog.cash_per_jeton_variant_ids()
  @manual_name_session_key :manual_player_name

  def index(conn, params) do
    render(conn, :index,
      headline_variants: ComputerPlayCatalog.primary(),
      secondary_variants: ComputerPlayCatalog.secondary(),
      tavli: ComputerPlayCatalog.tavli(),
      computer_variant_bots: computer_variant_bots(),
      multi_seat_formats: @multi_seat_formats,
      manual_name: get_session(conn, @manual_name_session_key),
      identity_mode: conn.assigns[:identity_mode] || Identity.mode(),
      current_identity: conn.assigns[:current_identity],
      bluesky_login_url: "/auth/bluesky/login",
      bluesky_logout_url: "/auth/bluesky/logout",
      bluesky_return_to: Identity.sanitize_return_to(params["return_to"])
    )
  end

  def model_lab(conn, _params) do
    render(conn, :model_lab, models: HermesTrictrac.ModelAnalysis.models())
  end

  def game(conn, %{"game" => game} = params) do
    current_identity = conn.assigns[:current_identity]
    identity_mode = conn.assigns[:identity_mode] || Identity.mode()

    {conn, name} = resolve_player_name(conn, current_identity, params)

    variant =
      Map.get(params, "variant") ||
        existing_table_variant(game) ||
        "backgammon"

    bot = normalize_bot(Map.get(params, "bot"), variant)
    bot_margot = normalize_bot_margot(Map.get(params, "bot_margot"), bot)
    queue_size = Map.get(params, "queue_size")
    ante = Map.get(params, "ante")
    stake = Map.get(params, "stake")
    hole_value = Map.get(params, "hole_value")
    margot_enabled = normalize_margot_enabled(Map.get(params, "margot_enabled"))
    a_ecrire_partie_length = normalize_a_ecrire_partie_length(variant, params)

    cash_per_jeton_minor =
      normalize_cash_per_jeton_minor(variant, Map.get(params, "cash_per_jeton"))

    client_id_scope = Application.get_env(:hermes_trictrac, :client_id_scope, :tab)

    render(conn, :game,
      name: name,
      game: game,
      variant: variant,
      bot: bot,
      bot_margot: bot_margot,
      queue_size: queue_size,
      ante: ante,
      stake: stake,
      hole_value: hole_value,
      margot_enabled: margot_enabled,
      a_ecrire_partie_length: a_ecrire_partie_length,
      cash_per_jeton_minor: cash_per_jeton_minor,
      rules_url: rules_url_for_variant(conn, game, variant),
      client_id_scope: Atom.to_string(client_id_scope),
      identity_mode: identity_mode,
      current_identity: current_identity
    )
  end

  defp require_table_identity(conn, _opts) do
    identity_mode = conn.assigns[:identity_mode] || Identity.mode()

    if Identity.bluesky_oauth?(identity_mode) and is_nil(conn.assigns[:current_identity]) do
      return_to =
        if conn.method == "GET" do
          conn.request_path <> if(conn.query_string == "", do: "", else: "?#{conn.query_string}")
        else
          "/"
        end

      conn
      |> put_flash(:error, "Sign in with Bluesky to open or join a table.")
      |> redirect(
        to: "/?return_to=#{URI.encode_www_form(Identity.sanitize_return_to(return_to))}"
      )
      |> halt()
    else
      conn
    end
  end

  defp normalize_bot(bot, variant) do
    bot = ComputerPlayCatalog.canonical_bot_kind(bot)

    if ComputerPlayCatalog.accepts_bot?(variant, bot) and ComputerPlayCatalog.available?(variant),
      do: bot,
      else: nil
  end

  defp computer_variant_bots do
    (ComputerPlayCatalog.primary() ++ [ComputerPlayCatalog.tavli()])
    |> Enum.reduce(%{}, fn entry, bots ->
      if ComputerPlayCatalog.available?(entry.id),
        do: Map.put(bots, entry.id, entry.bot_kind),
        else: bots
    end)
  end

  defp normalize_bot_margot(_value, nil), do: nil
  defp normalize_bot_margot("yes", _bot), do: "yes"
  defp normalize_bot_margot("true", _bot), do: "yes"
  defp normalize_bot_margot("on", _bot), do: "yes"
  defp normalize_bot_margot(true, _bot), do: "yes"
  defp normalize_bot_margot(_, _bot), do: "no"

  defp normalize_margot_enabled(value) when value in ["yes", "true", "on", true], do: "true"
  defp normalize_margot_enabled(_value), do: "false"

  defp normalize_cash_per_jeton_minor(variant, value) when variant in @cash_per_jeton_variants do
    value
    |> to_string_or_nil()
    |> parse_cash_minor()
  end

  defp normalize_cash_per_jeton_minor(_variant, _value), do: nil

  defp normalize_a_ecrire_partie_length(variant, _params)
       when variant in @cash_per_jeton_variants,
       do: nil

  defp normalize_a_ecrire_partie_length(_variant, params),
    do: Map.get(params, "aEcrirePartieLength")

  defp resolve_player_name(conn, %{handle: handle}, _params)
       when is_binary(handle) and handle != "" do
    {conn, handle}
  end

  defp resolve_player_name(conn, _current_identity, params) do
    case normalize_manual_name(Map.get(params, "name")) do
      nil ->
        {conn, get_session(conn, @manual_name_session_key) || "Player"}

      name ->
        {put_session(conn, @manual_name_session_key, name), name}
    end
  end

  defp rules_url_for_variant(conn, game, variant) when is_binary(variant) do
    RulesLibrary.library_path(%{
      return_to: game_return_to(conn, game),
      return_label: "Back to game",
      query: "",
      variant_id: effective_rules_variant_id(variant)
    })
  end

  defp rules_url_for_variant(conn, game, _variant) do
    RulesLibrary.library_path(%{
      return_to: game_return_to(conn, game),
      return_label: "Back to game",
      query: ""
    })
  end

  defp effective_rules_variant_id(variant_id) do
    variant_id
    |> Registry.fetch!()
    |> Map.get(:base_variant_id, variant_id)
  rescue
    _ -> variant_id
  end

  defp game_return_to(
         %Plug.Conn{method: "GET", request_path: request_path, query_string: query},
         _game
       ) do
    request_path <> if(query in [nil, ""], do: "", else: "?#{query}")
  end

  defp game_return_to(_conn, game), do: "/game/#{game}"

  defp existing_table_variant(game) do
    case GenServer.whereis(GameServer.reg(game)) do
      nil ->
        nil

      _pid ->
        game
        |> GameServer.peek()
        |> get_in(["variant", "id"])
    end
  rescue
    _ -> nil
  end

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(value) when is_binary(value), do: value
  defp to_string_or_nil(value), do: to_string(value)

  defp normalize_manual_name(value) do
    value
    |> to_string_or_nil()
    |> case do
      nil ->
        nil

      name ->
        name = String.trim(name)
        if name == "", do: nil, else: name
    end
  end

  defp parse_cash_minor(nil), do: nil

  defp parse_cash_minor(value) do
    normalized = value |> String.trim() |> String.replace(",", ".")

    case Regex.run(~r/\A(\d+)(?:\.(\d{1,2}))?\z/, normalized) do
      [_, whole, cents] ->
        whole_minor = String.to_integer(whole) * 100
        cents_minor = (cents || "") |> String.pad_trailing(2, "0") |> String.to_integer()
        cash_minor = whole_minor + cents_minor

        if cash_minor >= 1, do: cash_minor, else: nil

      _ ->
        nil
    end
  end
end

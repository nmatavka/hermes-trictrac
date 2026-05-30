defmodule HermesTrictracWeb.PageController do
  use HermesTrictracWeb, :controller

  alias HermesTrictrac.{GameServer, Identity, RulesLibrary}

  plug :require_table_identity when action in [:game]

  @trictrac_zero_variants [
    "trictrac_classique",
    "trictrac_aecrire",
    "trictrac_combine",
    "toc",
    "toccategli"
  ]
  @computer_variant_bots %{
    "backgammon" => "backgammon_ai",
    "trictrac_classique" => "trictrac_zero",
    "trictrac_aecrire" => "trictrac_zero",
    "trictrac_combine" => "trictrac_zero",
    "toc" => "trictrac_zero",
    "toccategli" => "trictrac_zero"
  }
  @headline_variants [
    %{id: "backgammon", label: "Backgammon"},
    %{id: "trictrac_classique", label: "Trictrac classique"},
    %{id: "trictrac_aecrire", label: "Trictrac &agrave; &eacute;crire"},
    %{id: "trictrac_combine", label: "Trictrac combin&eacute;"},
    %{id: "toc", label: "Toc"},
    %{id: "toccategli", label: "Toccategli"}
  ]
  @secondary_variants [
    %{id: "tapa", label: "Tapa / Plakoto"},
    %{id: "jacquet", label: "Jacquet / Pheuga"},
    %{id: "tavli", label: "Tavli"},
    %{id: "brade", label: "Bräde"},
    %{id: "garanguet", label: "Garanguet"},
    %{id: "sbaraglio", label: "Sbaraglio"},
    %{id: "sbaraglino", label: "Sbaraglino"},
    %{id: "plein", label: "Plein"},
    %{id: "tourne_case", label: "Tourne-Case"},
    %{id: "dames_rabattues", label: "Dames Rabattues"}
  ]
  @multi_seat_formats [
    %{
      id: "trictrac_en_poule",
      session_kind: "poule",
      style: "growing_pot",
      title: "Trictrac en poule",
      title_key: "lobby.multiSeatTrictracPouleTitle",
      meta: "2 active seats · rotating queue",
      meta_key: "lobby.multiSeatTrictracPouleMeta"
    },
    %{
      id: "toccategli_en_poule",
      session_kind: "poule",
      style: "growing_pot",
      title: "Toccategli en poule",
      title_key: "lobby.multiSeatToccategliPouleTitle",
      meta: "2 active seats · rotating queue",
      meta_key: "lobby.multiSeatToccategliPouleMeta"
    },
    %{
      id: "trictrac_en_poule_plumee",
      session_kind: "poule",
      style: "plucked_pot",
      title: "Trictrac en poule (plumée)",
      title_key: "lobby.multiSeatTrictracPoulePlumeeTitle",
      meta: "fixed ring · common fund",
      meta_key: "lobby.multiSeatTrictracPoulePlumeeMeta"
    },
    %{
      id: "toccategli_en_poule_plumee",
      session_kind: "poule",
      style: "plucked_pot",
      title: "Toccategli en poule (plumée)",
      title_key: "lobby.multiSeatToccategliPoulePlumeeTitle",
      meta: "fixed ring · common fund",
      meta_key: "lobby.multiSeatToccategliPoulePlumeeMeta"
    },
    %{
      id: "trictrac_aecrire_a_tourner",
      session_kind: "multiplayer",
      multiplayer_mode: "a_tourner",
      title: "Trictrac à écrire à tourner",
      title_key: "lobby.multiSeatAecrireTournerTitle",
      meta: "3 players · round robin",
      meta_key: "lobby.multiSeatAecrireTournerMeta"
    },
    %{
      id: "trictrac_aecrire_chouette",
      session_kind: "multiplayer",
      multiplayer_mode: "chouette",
      title: "Trictrac à écrire chouette",
      title_key: "lobby.multiSeatAecrireChouetteTitle",
      meta: "3 players · chouette",
      meta_key: "lobby.multiSeatAecrireChouetteMeta"
    },
    %{
      id: "trictrac_aecrire_deux_contre_deux",
      session_kind: "multiplayer",
      multiplayer_mode: "deux_contre_deux",
      title: "Trictrac à écrire deux contre deux",
      title_key: "lobby.multiSeatAecrireTeamsTitle",
      meta: "4 players · two sides",
      meta_key: "lobby.multiSeatAecrireTeamsMeta"
    },
    %{
      id: "trictrac_combine_chouette",
      session_kind: "multiplayer",
      multiplayer_mode: "combine_chouette",
      title: "Trictrac combiné chouette",
      title_key: "lobby.multiSeatCombineChouetteTitle",
      meta: "3 players · combined chouette",
      meta_key: "lobby.multiSeatCombineChouetteMeta"
    },
    %{
      id: "trictrac_combine_deux_contre_deux",
      session_kind: "multiplayer",
      multiplayer_mode: "combine_deux_contre_deux",
      title: "Trictrac combiné deux contre deux",
      title_key: "lobby.multiSeatCombineTeamsTitle",
      meta: "4 players · combined teams",
      meta_key: "lobby.multiSeatCombineTeamsMeta"
    }
  ]
  @cash_per_jeton_variants for format <- @multi_seat_formats,
                               format.session_kind == "multiplayer",
                               do: format.id

  def index(conn, params) do
    render(conn, :index,
      headline_variants: @headline_variants,
      secondary_variants: @secondary_variants,
      computer_variant_bots: @computer_variant_bots,
      multi_seat_formats: @multi_seat_formats,
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

    name =
      case current_identity do
        %{handle: handle} when is_binary(handle) and handle != "" -> handle
        _ -> Map.get(params, "name", "Player")
      end

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
      rules_url: rules_url_for_variant(game, variant),
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

  defp normalize_bot("trictrac_zero", variant) when variant in @trictrac_zero_variants,
    do: "trictrac_zero"

  defp normalize_bot("backgammon_ai", "backgammon"), do: "backgammon_ai"

  defp normalize_bot(_, _), do: nil

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

  defp rules_url_for_variant(game, variant) when is_binary(variant) do
    if String.starts_with?(variant, "trictrac_") do
      RulesLibrary.library_path(%{
        return_to: "/game/#{game}",
        return_label: "Back to game",
        query: ""
      })
    end
  end

  defp rules_url_for_variant(_game, _variant), do: nil

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

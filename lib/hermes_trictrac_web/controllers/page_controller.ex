defmodule HermesTrictracWeb.PageController do
  use HermesTrictracWeb, :controller

  @trictrac_zero_variants [
    "trictrac_classique",
    "trictrac_aecrire",
    "trictrac_combine",
    "toc",
    "toccategli"
  ]
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
    %{id: "garanguet", label: "Garanguet"},
    %{id: "tavli", label: "Tavli"},
    %{id: "sbaraglio", label: "Sbaraglio"},
    %{id: "sbaraglino", label: "Sbaraglino"},
    %{id: "tourne_case", label: "Tourne-Case"},
    %{id: "dames_rabattues", label: "Dames Rabattues"},
    %{id: "plein", label: "Jeu du Plein"},
    %{id: "brade", label: "Brade Suedois"}
  ]

  def index(conn, _params) do
    render(conn, :index,
      headline_variants: @headline_variants,
      secondary_variants: @secondary_variants
    )
  end

  def game(conn, %{"game" => game} = params) do
    name = Map.get(params, "name", "Player")
    variant = Map.get(params, "variant", "backgammon")
    bot = normalize_bot(Map.get(params, "bot"), variant)
    bot_margot = normalize_bot_margot(Map.get(params, "bot_margot"), bot)
    client_id_scope = Application.get_env(:hermes_trictrac, :client_id_scope, :tab)

    render(conn, :game,
      name: name,
      game: game,
      variant: variant,
      bot: bot,
      bot_margot: bot_margot,
      client_id_scope: Atom.to_string(client_id_scope)
    )
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
end

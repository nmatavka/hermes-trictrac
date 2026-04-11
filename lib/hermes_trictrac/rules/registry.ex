defmodule HermesTrictrac.Rules.Registry do
  @variants %{
    "backgammon" => %{
      id: "backgammon",
      title: "Backgammon",
      family: :race,
      orientation: :ascending,
      start_points: %{
        white: [{0, 2}, {11, 5}, {16, 3}, {18, 5}],
        black: [{23, 2}, {12, 5}, {7, 3}, {5, 5}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: true,
      doubles_mode: :repeat_four,
      score_mode: :single_game
    },
    "tapa" => %{
      id: "tapa",
      title: "Tapa / Plakoto",
      family: :race,
      orientation: :split_home,
      start_points: %{
        white: [{23, 15}],
        black: [{0, 15}]
      },
      total_pieces: 15,
      can_hit: false,
      can_bear_off: true,
      doubles_mode: :repeat_four,
      score_mode: :single_game
    },
    "jacquet" => %{
      id: "jacquet",
      title: "Jacquet / Pheuga",
      family: :race,
      orientation: :jacquet_parallel,
      start_points: %{
        white: [{23, 15}],
        black: [{0, 15}]
      },
      total_pieces: 15,
      can_hit: false,
      can_bear_off: true,
      doubles_mode: :repeat_four,
      opening_roll_mode: :highest,
      score_mode: :single_game
    },
    "garanguet" => %{
      id: "garanguet",
      title: "Garanguet",
      family: :race,
      orientation: :split_home,
      start_points: %{
        white: [{23, 15}],
        black: [{0, 15}]
      },
      total_pieces: 15,
      can_hit: false,
      can_bear_off: true,
      doubles_mode: :garanguet_three,
      turn_dice_mode: :garanguet_three,
      opening_roll_mode: :highest,
      opening_setup: :garanguet_seed_turn,
      score_mode: :garanguet
    },
    "tavli" => %{
      id: "tavli",
      title: "Tavli",
      family: :race,
      orientation: :ascending,
      start_points: %{
        white: [{0, 2}, {11, 5}, {16, 3}, {18, 5}],
        black: [{23, 2}, {12, 5}, {7, 3}, {5, 5}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: true,
      doubles_mode: :repeat_four,
      score_mode: :tavli
    },
    "sbaraglio" => %{
      id: "sbaraglio",
      title: "Sbaraglio",
      family: :race,
      orientation: :ascending,
      start_points: %{
        white: [{11, 15}],
        black: [{12, 15}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: true,
      doubles_mode: :two_dice,
      turn_dice_mode: :three_dice,
      opening_roll_mode: :highest,
      opening_setup: :sbaraglino_strict,
      score_mode: :sbaraglio
    },
    "sbaraglino" => %{
      id: "sbaraglino",
      title: "Sbaraglino",
      family: :race,
      orientation: :ascending,
      start_points: %{
        white: [{11, 15}],
        black: [{12, 15}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: true,
      doubles_mode: :two_dice,
      turn_dice_mode: :two_plus_virtual_six,
      opening_roll_mode: :highest,
      opening_setup: :sbaraglino_strict,
      score_mode: :sbaraglio
    },
    "trictrac_classique" => %{
      id: "trictrac_classique",
      title: "Trictrac Classique",
      family: :trictrac,
      orientation: :split_home,
      start_points: %{
        white: [{23, 15}],
        black: [{0, 15}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: true,
      doubles_mode: :two_dice,
      score_mode: :single_game,
      trictrac_variant: "classique"
    },
    "trictrac_aecrire" => %{
      id: "trictrac_aecrire",
      title: "Trictrac A Ecrire",
      family: :trictrac,
      orientation: :split_home,
      start_points: %{
        white: [{23, 15}],
        black: [{0, 15}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: true,
      doubles_mode: :two_dice,
      score_mode: :single_game,
      trictrac_variant: "a_ecrire"
    },
    "trictrac_combine" => %{
      id: "trictrac_combine",
      title: "Trictrac Combine",
      family: :trictrac,
      orientation: :split_home,
      start_points: %{
        white: [{23, 15}],
        black: [{0, 15}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: true,
      doubles_mode: :two_dice,
      score_mode: :single_game,
      trictrac_variant: "combine"
    },
    "toccategli" => %{
      id: "toccategli",
      title: "Toccategli",
      family: :trictrac,
      orientation: :split_home,
      start_points: %{
        white: [{23, 15}],
        black: [{0, 15}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: true,
      doubles_mode: :two_dice,
      score_mode: :single_game,
      trictrac_variant: "toccategli"
    },
    "tourne_case" => %{
      id: "tourne_case",
      title: "Tourne-Case",
      family: :tourne_case
    },
    "dames_rabattues" => %{
      id: "dames_rabattues",
      title: "Dames Rabattues",
      family: :rabattues
    },
    "plein" => %{
      id: "plein",
      title: "Jeu du Plein",
      family: :trictrac,
      orientation: :split_home,
      start_points: %{
        white: [{23, 15}],
        black: [{0, 15}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: false,
      doubles_mode: :repeat_four,
      score_mode: :plein
    },
    "toc" => %{
      id: "toc",
      title: "Jeu du Toc",
      family: :trictrac,
      orientation: :split_home,
      start_points: %{
        white: [{23, 15}],
        black: [{0, 15}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: true,
      doubles_mode: :two_dice,
      score_mode: :toc
    },
    "brade" => %{
      id: "brade",
      title: "Brade Suedois",
      family: :race,
      orientation: :split_home,
      start_points: %{
        white: [{23, 15}],
        black: [{0, 15}]
      },
      total_pieces: 15,
      can_hit: true,
      can_bear_off: true,
      doubles_mode: :repeat_four,
      score_mode: :brade
    }
  }

  @default_variant "backgammon"

  def all, do: Map.values(@variants)

  def fetch!(id), do: Map.fetch!(@variants, id)
  def get(id), do: Map.get(@variants, id, fetch!(@default_variant))
  def default_id, do: @default_variant
end

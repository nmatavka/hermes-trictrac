defmodule HermesTrictrac.Rules.Registry do
  @variants %{
    "backgammon" => %{
      id: "backgammon",
      title: "Backgammon",
      family: :race,
      movement_mode: :contrary,
      uses_bar: true,
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
      movement_mode: :parallel,
      uses_bar: false,
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
      movement_mode: :parallel,
      uses_bar: false,
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
      movement_mode: :contrary,
      uses_bar: false,
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
      uses_bar: true,
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
      uses_bar: true,
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
      uses_bar: true,
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
      movement_mode: :contrary,
      uses_bar: false,
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
      movement_mode: :contrary,
      uses_bar: false,
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
      movement_mode: :contrary,
      uses_bar: false,
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
      movement_mode: :contrary,
      uses_bar: false,
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
    "trictrac_en_poule" => %{
      id: "trictrac_en_poule",
      title: "Trictrac en poule",
      family: :trictrac,
      session_mode: :poule,
      session_style: :growing_pot,
      base_variant_id: "trictrac_classique",
      hole_target: 6,
      movement_mode: :contrary,
      uses_bar: false,
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
    "toccategli_en_poule" => %{
      id: "toccategli_en_poule",
      title: "Toccategli en poule",
      family: :trictrac,
      session_mode: :poule,
      session_style: :growing_pot,
      base_variant_id: "toccategli",
      hole_target: 6,
      movement_mode: :contrary,
      uses_bar: false,
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
    "trictrac_en_poule_plumee" => %{
      id: "trictrac_en_poule_plumee",
      title: "Trictrac en poule (plumee)",
      family: :trictrac,
      session_mode: :poule,
      session_style: :plucked_pot,
      base_variant_id: "trictrac_classique",
      movement_mode: :contrary,
      uses_bar: false,
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
    "trictrac_aecrire_a_tourner" => %{
      id: "trictrac_aecrire_a_tourner",
      title: "Trictrac a ecrire a tourner",
      family: :trictrac,
      session_mode: :multiplayer,
      session_family: :aecrire,
      session_style: :a_tourner,
      competitor_target: 3,
      base_variant_id: "trictrac_aecrire",
      movement_mode: :contrary,
      uses_bar: false,
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
    "trictrac_aecrire_chouette" => %{
      id: "trictrac_aecrire_chouette",
      title: "Trictrac a ecrire chouette",
      family: :trictrac,
      session_mode: :multiplayer,
      session_family: :aecrire,
      session_style: :chouette,
      competitor_target: 3,
      base_variant_id: "trictrac_aecrire",
      movement_mode: :contrary,
      uses_bar: false,
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
    "trictrac_aecrire_deux_contre_deux" => %{
      id: "trictrac_aecrire_deux_contre_deux",
      title: "Trictrac a ecrire deux contre deux",
      family: :trictrac,
      session_mode: :multiplayer,
      session_family: :aecrire,
      session_style: :deux_contre_deux,
      competitor_target: 4,
      base_variant_id: "trictrac_aecrire",
      movement_mode: :contrary,
      uses_bar: false,
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
    "trictrac_combine_chouette" => %{
      id: "trictrac_combine_chouette",
      title: "Trictrac combine chouette",
      family: :trictrac,
      session_mode: :multiplayer,
      session_family: :combine,
      session_style: :chouette,
      competitor_target: 3,
      base_variant_id: "trictrac_combine",
      movement_mode: :contrary,
      uses_bar: false,
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
    "trictrac_combine_deux_contre_deux" => %{
      id: "trictrac_combine_deux_contre_deux",
      title: "Trictrac combine deux contre deux",
      family: :trictrac,
      session_mode: :multiplayer,
      session_family: :combine,
      session_style: :deux_contre_deux,
      competitor_target: 4,
      base_variant_id: "trictrac_combine",
      movement_mode: :contrary,
      uses_bar: false,
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
    "toccategli_en_poule_plumee" => %{
      id: "toccategli_en_poule_plumee",
      title: "Toccategli en poule (plumee)",
      family: :trictrac,
      session_mode: :poule,
      session_style: :plucked_pot,
      base_variant_id: "toccategli",
      movement_mode: :contrary,
      uses_bar: false,
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
      movement_mode: :contrary,
      uses_bar: false,
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
      movement_mode: :contrary,
      uses_bar: false,
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
      movement_mode: :parallel,
      uses_bar: true,
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
  def session_mode(id), do: Map.get(get(id), :session_mode)
  def session_variant?(id), do: not is_nil(session_mode(id))
  def poule_variant?(id), do: Map.get(get(id), :session_mode) == :poule
  def multiplayer_variant?(id), do: Map.get(get(id), :session_mode) == :multiplayer
end

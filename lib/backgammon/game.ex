defmodule Backgammon.Game do
  alias Backgammon.MoveGenerator

  def new do
    %{
      slots: init_slots(),
      knocked: %{
        red: 0,
        white: 0,
      },
      home: %{
        red: 0,
        white: 0,
      },
      whose_turn: :white,
      current_dice: [],
      players: %{}
    }
  end

  def init_slots() do
    [
      %{idx: 0, owner: :white, num: 2},
      %{idx: 1},
      %{idx: 2},
      %{idx: 3},
      %{idx: 4},
      %{idx: 5, owner: :red, num: 5},
      %{idx: 6},
      %{idx: 7, owner: :red, num: 3},
      %{idx: 8},
      %{idx: 9},
      %{idx: 10},
      %{idx: 11, owner: :white, num: 5},
      %{idx: 12, owner: :red, num: 5},
      %{idx: 13},
      %{idx: 14},
      %{idx: 15},
      %{idx: 16, owner: :white, num: 3},
      %{idx: 17},
      %{idx: 18, owner: :white, num: 5},
      %{idx: 19},
      %{idx: 20},
      %{idx: 21},
      %{idx: 22},
      %{idx: 23, owner: :red, num: 2},
    ]
  end

  def winner(game) do
    if has_won?(game, :red) do
      :red
    else
      if has_won?(game, :white) do
        :white
      else
        ""
      end
    end
  end

  def has_won?(game, color) do
    game.home[color] == 15
  end


  def client_view(game, user) do
    game
    |> Map.put(:possible_moves, MoveGenerator.possible_moves(game))
    |> Map.put(:color, game.players[user])
    |> Map.put(:winner, winner(game))
    |> Map.delete(:players)
  end


  # Functions from Game -> Game (taking actions on a game)

  def validate_player(g, player) do
    Map.has_key?(g.players, player) and
    g.players[player] == g.whose_turn
  end


  # roll two die and set them as the current dice, doubling them
  # if they are the same
  def roll(g, player) do
    if !validate_player(g, player) or length(g.current_dice) > 0 do
      {:error, "Not your turn, or not valid to roll"}
    else
      new_dice = random_dice()
      updated = Map.put(g, :current_dice, new_dice)
      check_no_moves(updated)
    end
  end

  # randomly generates the new dice for the
  def random_dice() do
    d1 = :rand.uniform(6)
    d2 = :rand.uniform(6)
    # if the dice are the same, they get "doubled"
    if d1 == d2 do
      [d1, d2, d1, d2]
    else
      [d1, d2]
    end
  end

  # checks if the current player has no moves (but still has dice),
  # and switches the turn if so
  def check_no_moves(game) do
    poss_moves = MoveGenerator.possible_moves(game)
    if length(poss_moves) == 0 and length(game.current_dice) != 0 do
      updated = game
      |> Map.update(:whose_turn, :white, &(opposite_player(&1)))
      |> Map.update(:current_dice, [], fn _ -> [] end)
      {:ok, updated}
    else
      {:ok, game}
    end
  end


  # returns the game state after enacting the given move
  def move(g, move = %{from: from, to: to, die: die}, player) do
    if !validate_player(g, player) do
      {:error, "Not your turn to move."}
    else
      if valid_move?(g, move) do
        new_slots = update_slots(g.slots, move, g.whose_turn)
        new_dice = remove_die(g.current_dice, die)
        new_player = next_player(g.whose_turn, new_dice)
        to_slot = Enum.find(g.slots, &(&1.idx == to))
        new_knocked = g.knocked
                      |> decrement_knocked(from, g.whose_turn)
                      |> increment_knocked(to_slot, g.whose_turn)
        new_home = next_home(g.home, to, g.whose_turn)

        g = %{
          slots: new_slots,
          knocked: new_knocked,
          home: new_home,
          whose_turn: new_player,
          current_dice: new_dice,
          players: g.players
        }

        check_no_moves(g)
      else
        {:error, "Invalid move."}
      end
    end
  end

  def opposite_player(:red), do: :white
  def opposite_player(:white), do: :red

  # checks if the given move is valid under the current game state
  def valid_move?(g, move) do
    move in MoveGenerator.possible_moves(g)
  end

  # returns the new slots after the given move by the given player
  def update_slots([slot | rest], move = %{from: from, to: to}, player) do
    updated_rest = update_slots(rest, move, player)
    if slot.idx == from or slot.idx == to do
      [update_slot(slot, move, player) | updated_rest]
    else
      [slot | updated_rest]
    end
  end

  def update_slots([], _move, _player) do
    []
  end

  # updates the given slot under the given move
  def update_slot(slot, %{from: from}, player) do
    cur_num = Map.get(slot, :num) || 0
    if slot.idx == from do
      if cur_num == 1 do
        %{idx: slot.idx}
      else
        Map.put(slot, :num, cur_num - 1)
      end
    else
      new_owner = Map.put(slot, :owner, player)
      if Map.has_key?(slot, :owner) and slot.owner != player do
        new_owner
        |> Map.put(:num, 1)
      else
        new_owner
        |> Map.put(:num, cur_num + 1)
      end
    end
  end

  # removes the first occurence of the given die from the dice
  def remove_die([first | rest], die) do
    if first == die do
      rest
    else
      [first | remove_die(rest, die)]
    end
  end

  def remove_die([], _die) do
    []
  end

  # says whose turn is next - changes the turn if both dice have
  # been used
  def next_player(player, dice) do
    if length(dice) == 0 do
      if player == :white do
        :red
      else
        :white
      end
    else
      player
    end
  end

  # returns the current number of knocked players after the move
  # from the given index
  def decrement_knocked(knocked, from, player) do
    if from == :knocked do
      Map.update(knocked, player, 0, &(&1 - 1))
    else
      knocked
    end
  end

  # increments the knocked count for the player who got knocked
  def increment_knocked(knocked, to_slot, player) do
    if to_slot != nil and Map.has_key?(to_slot, :owner) and to_slot.owner != player do
      opponent = to_slot.owner
      Map.update(knocked, opponent, 0, &(&1 + 1))
    else
      knocked
    end
  end

  # returns the current number of home players after the move to the given idx
  def next_home(home, to, player) do
    if to == :home do
      Map.update(home, player, 1, &(&1 + 1))
    else
      home
    end
  end

  # Has the player join the game, if there is a space. First to join is white.
  def join(game, name) do
    players = game.players
    if Map.has_key?(players, name) do
      {:ok, game}
    else
      keys = map_size(players)
      case keys do
         0 -> {:ok, Map.put(game, :players, Map.put(players, name, :white))}
         1 -> {:ok, Map.put(game, :players, Map.put(players, name, :red))}
         _ -> {:error, "game is full"}
      end
    end
  end

end

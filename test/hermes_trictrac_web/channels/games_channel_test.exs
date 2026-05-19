defmodule HermesTrictracWeb.GamesChannelTest do
  use HermesTrictracWeb.ChannelCase, async: true

  alias HermesTrictrac.GameServer
  alias HermesTrictrac.Rules.{Registry, TrictracCore}
  alias HermesTrictracWeb.UserSocket

  setup do
    lobby = "lobby-#{System.unique_integer([:positive])}"

    {:ok, host_reply, host_socket} =
      UserSocket
      |> socket("user:1", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "backgammon",
        "client_id" => "client-1"
      })

    {:ok, guest_reply, guest_socket} =
      UserSocket
      |> socket("user:2", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "backgammon",
        "client_id" => "client-2"
      })

    %{
      host_socket: host_socket,
      host_reply: host_reply,
      guest_socket: guest_socket,
      guest_reply: guest_reply,
      lobby: lobby
    }
  end

  test "join returns the initial engine snapshot", %{
    host_reply: host_reply,
    guest_reply: guest_reply,
    host_socket: socket,
    lobby: lobby
  } do
    assert host_reply.player["color"] == "white"
    assert guest_reply.player["color"] == "black"
    assert host_reply.game["variant"]["id"] == "backgammon"
    assert host_reply.game["status"] == "waiting_for_opponent"
    assert guest_reply.game["status"] == "playing"
    assert guest_reply.game["turn"] == nil
    assert guest_reply.game["opening_roll"]["order"] == "highest"
    assert guest_reply.game["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}
    assert socket.assigns.name == lobby
    assert socket.assigns.user == "nick"
  end

  test "joining an existing lobby with a different variant returns an error and preserves the lobby" do
    lobby = "variant-lock-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      UserSocket
      |> socket("user:61", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "tapa",
        "client_id" => "variant-lock-host"
      })

    assert host_reply.game["variant"]["id"] == "tapa"

    assert {:error, %{msg: msg, code: "variant_mismatch"}} =
             UserSocket
             |> socket("user:62", %{})
             |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
               "user" => "jane",
               "variant" => "backgammon",
               "client_id" => "variant-lock-guest"
             })

    assert msg == ~s(Lobby "#{lobby}" is already a Tapa / Plakoto table.)

    snapshot = GameServer.peek(lobby)
    assert snapshot["variant"]["id"] == "tapa"
    assert snapshot["players"]["host"]["name"] == "nick"
    assert snapshot["players"]["guest"] == nil
  end

  test "channel action errors preserve msg and include a stable code", %{guest_socket: socket} do
    ref = push(socket, "confirm", %{})
    assert_reply ref, :error, %{msg: "Not your turn.", code: "not_your_turn"}
  end

  test "rejoining with the same submitted client id reuses the same seat" do
    lobby = "rejoin-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      UserSocket
      |> socket("user:63", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "backgammon",
        "client_id" => "stable-client"
      })

    assert host_reply.player["color"] == "white"
    assert host_reply.game["players"]["guest"] == nil

    {:ok, rejoin_reply, _rejoin_socket} =
      UserSocket
      |> socket("user:64", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "backgammon",
        "client_id" => "stable-client"
      })

    assert rejoin_reply.player["color"] == "white"
    assert rejoin_reply.game["players"]["host"]["name"] == "nick"
    assert rejoin_reply.game["players"]["guest"] == nil
    assert rejoin_reply.game["status"] == "waiting_for_opponent"
  end

  test "same-name rejoin on a full lobby starts a reclaim warning that the seated browser can cancel",
       %{
         lobby: lobby,
         host_socket: host_socket
       } do
    original = Application.get_env(:hermes_trictrac, :seat_reclaim_window_ms)
    Application.put_env(:hermes_trictrac, :seat_reclaim_window_ms, 50)

    on_exit(fn ->
      if is_nil(original) do
        Application.delete_env(:hermes_trictrac, :seat_reclaim_window_ms)
      else
        Application.put_env(:hermes_trictrac, :seat_reclaim_window_ms, original)
      end
    end)

    assert {:error, %{code: "seat_reclaim_pending", retry_after_ms: retry_after_ms}} =
             UserSocket
             |> socket("user:65", %{})
             |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
               "user" => "nick",
               "variant" => "backgammon",
               "client_id" => "nick-reclaim-client"
             })

    assert retry_after_ms > 0

    assert_broadcast "update", %{
      game: %{
        "seat_reclaim" => %{
          "seat_color" => "white",
          "claimant_name" => "nick",
          "defender_name" => "nick"
        }
      }
    }

    push(host_socket, "remain_seated", %{})

    assert_broadcast "update", %{game: %{"seat_reclaim" => nil}}

    assert {:error, "Player not found in lobby."} =
             GameServer.roll(lobby, "nick", "nick-reclaim-client")
  end

  test "same-name reclaim transfers the seat after the grace window", %{lobby: lobby} do
    original = Application.get_env(:hermes_trictrac, :seat_reclaim_window_ms)
    Application.put_env(:hermes_trictrac, :seat_reclaim_window_ms, 25)

    on_exit(fn ->
      if is_nil(original) do
        Application.delete_env(:hermes_trictrac, :seat_reclaim_window_ms)
      else
        Application.put_env(:hermes_trictrac, :seat_reclaim_window_ms, original)
      end
    end)

    assert {:error, %{code: "seat_reclaim_pending"}} =
             UserSocket
             |> socket("user:66", %{})
             |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
               "user" => "nick",
               "variant" => "backgammon",
               "client_id" => "nick-new-browser"
             })

    assert_broadcast "update", %{game: %{"seat_reclaim" => %{"seat_color" => "white"}}}
    Process.sleep(60)
    assert_broadcast "update", %{game: %{"seat_reclaim" => nil}}

    {:ok, rejoin_reply, _rejoin_socket} =
      UserSocket
      |> socket("user:67", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "backgammon",
        "client_id" => "nick-new-browser"
      })

    assert rejoin_reply.player["color"] == "white"
    assert {:error, "Player not found in lobby."} = GameServer.roll(lobby, "nick", "client-1")
  end

  test "same-name rejoin challenges an occupied seat even when the opponent seat is empty" do
    original = Application.get_env(:hermes_trictrac, :seat_reclaim_window_ms)
    Application.put_env(:hermes_trictrac, :seat_reclaim_window_ms, 25)

    on_exit(fn ->
      if is_nil(original) do
        Application.delete_env(:hermes_trictrac, :seat_reclaim_window_ms)
      else
        Application.put_env(:hermes_trictrac, :seat_reclaim_window_ms, original)
      end
    end)

    lobby = "single-seat-reclaim-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      UserSocket
      |> socket("user:single-seat-host", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "backgammon",
        "client_id" => "single-seat-old-client"
      })

    assert host_reply.player["color"] == "white"
    assert host_reply.game["players"]["guest"] == nil

    assert {:error, %{code: "seat_reclaim_pending"}} =
             UserSocket
             |> socket("user:single-seat-reclaim", %{})
             |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
               "user" => "nick",
               "variant" => "backgammon",
               "client_id" => "single-seat-new-client"
             })

    assert_broadcast "update", %{game: %{"seat_reclaim" => %{"seat_color" => "white"}}}
    Process.sleep(60)
    assert_broadcast "update", %{game: %{"seat_reclaim" => nil}}

    snapshot = GameServer.peek(lobby)
    assert snapshot["players"]["host"]["name"] == "nick"
    assert snapshot["players"]["guest"] == nil

    pid = GenServer.whereis(GameServer.reg(lobby))
    state = :sys.get_state(pid)
    assert state.engine.players.host.client_id == "single-seat-new-client"

    assert {:error, "Player not found in lobby."} =
             GameServer.roll(lobby, "nick", "single-seat-old-client")
  end

  test "first backgammon roll updates the opening roll state", %{
    host_socket: socket
  } do
    assert_broadcast "update", %{game: %{"opening_roll" => %{"rolls" => %{"white" => nil}}}}
    ref = push(socket, "roll", %{})
    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{game: _game}
  end

  test "chat broadcasts the updated chat log", %{host_socket: socket} do
    payload = %{
      "chat" => %{
        "author" => "white",
        "type" => "text",
        "data" => %{"text" => "hello"}
      }
    }

    push(socket, "chat", payload)
    assert_broadcast "update", %{game: %{"chat" => [%{"data" => %{"text" => "hello"}}]}}
  end

  test "toc join exposes required pre-game options" do
    lobby = "toc-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      UserSocket
      |> socket("user:3", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "toc",
        "client_id" => "toc-host"
      })

    {:ok, guest_reply, _guest_socket} =
      UserSocket
      |> socket("user:4", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "toc",
        "client_id" => "toc-guest"
      })

    assert guest_reply.game["status"] == "awaiting_match_options"
    assert guest_reply.game["pending_match_options"]["rule"] == "Toc"
  end

  test "tavli join exposes bilateral target consent" do
    lobby = "tavli-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      UserSocket
      |> socket("user:43", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "tavli",
        "client_id" => "tavli-host"
      })

    {:ok, guest_reply, _guest_socket} =
      UserSocket
      |> socket("user:44", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "tavli",
        "client_id" => "tavli-guest"
      })

    assert guest_reply.game["status"] == "awaiting_match_options"
    assert guest_reply.game["pending_match_options"]["kind"] == "tavli_target_consent"
    assert guest_reply.game["pending_match_options"]["choices"] == ["3", "5", "7", "9"]
  end

  test "tapa join snapshot exposes the opening roll state" do
    lobby = "tapa-opening-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      UserSocket
      |> socket("user:31", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "tapa",
        "client_id" => "tapa-host"
      })

    {:ok, guest_reply, _guest_socket} =
      UserSocket
      |> socket("user:32", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "tapa",
        "client_id" => "tapa-guest"
      })

    assert guest_reply.game["status"] == "playing"
    assert guest_reply.game["turn"] == nil
    assert guest_reply.game["opening_roll"]["order"] == "highest"
    assert guest_reply.game["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}
  end

  test "jacquet join snapshot exposes the opening roll state" do
    lobby = "jacquet-opening-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      UserSocket
      |> socket("user:41", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "jacquet",
        "client_id" => "jacquet-host"
      })

    {:ok, guest_reply, _guest_socket} =
      UserSocket
      |> socket("user:42", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "jacquet",
        "client_id" => "jacquet-guest"
      })

    assert guest_reply.game["variant"]["id"] == "jacquet"
    assert guest_reply.game["status"] == "playing"
    assert guest_reply.game["turn"] == nil
    assert guest_reply.game["opening_roll"]["order"] == "highest"
    assert guest_reply.game["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}
  end

  test "garanguet join snapshot exposes the opening roll state" do
    lobby = "garanguet-opening-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      UserSocket
      |> socket("user:45", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "garanguet",
        "client_id" => "garanguet-host"
      })

    {:ok, guest_reply, _guest_socket} =
      UserSocket
      |> socket("user:46", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "garanguet",
        "client_id" => "garanguet-guest"
      })

    assert guest_reply.game["variant"]["id"] == "garanguet"
    assert guest_reply.game["status"] == "playing"
    assert guest_reply.game["turn"] == nil
    assert guest_reply.game["opening_roll"]["order"] == "highest"
    assert guest_reply.game["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}
  end

  test "dames rabattues join snapshot exposes the opening roll state" do
    lobby = "rab-opening-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      UserSocket
      |> socket("user:13", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "dames_rabattues",
        "client_id" => "rab-host"
      })

    {:ok, guest_reply, _guest_socket} =
      UserSocket
      |> socket("user:14", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "dames_rabattues",
        "client_id" => "rab-guest"
      })

    assert guest_reply.game["status"] == "playing"
    assert guest_reply.game["turn"] == nil
    assert guest_reply.game["opening_roll"]["order"] == "highest"
    assert guest_reply.game["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}
  end

  test "trictrac join snapshot includes rich trictrac payload" do
    lobby = "tt-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      UserSocket
      |> socket("user:5", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "trictrac_aecrire",
        "client_id" => "tt-host"
      })

    {:ok, guest_reply, _guest_socket} =
      UserSocket
      |> socket("user:6", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "trictrac_aecrire",
        "client_id" => "tt-guest"
      })

    assert guest_reply.game["trictrac"]["turn_event_queue"] == []
    assert guest_reply.game["trictrac"]["score_history"] == []
    assert get_in(guest_reply.game, ["trictrac", "turn", "obligations", "must_fill"]) == []
  end

  test "trictrac classique join exposes bilateral Margot consent" do
    lobby = "tt-margot-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      UserSocket
      |> socket("user:11", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "trictrac_classique",
        "client_id" => "tt-margot-host"
      })

    {:ok, guest_reply, guest_socket} =
      UserSocket
      |> socket("user:12", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "trictrac_classique",
        "client_id" => "tt-margot-guest"
      })

    assert guest_reply.game["status"] == "awaiting_match_options"
    assert guest_reply.game["pending_match_options"]["kind"] == "trictrac_margot_consent"

    drain_updates()
    push(guest_socket, "submit_match_options", %{"options" => %{"margotConsent" => "yes"}})

    assert_broadcast "update", %{game: %{"pending_match_options" => pending}}
    assert pending["responses"]["black"] == "yes"
  end

  test "channel update serializes trictrac classique reprise decisions" do
    lobby = "tt-reprise-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, host_socket} =
      UserSocket
      |> socket("user:9", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "trictrac_classique",
        "client_id" => "tt-reprise-host"
      })

    {:ok, _guest_reply, _guest_socket} =
      UserSocket
      |> socket("user:10", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "trictrac_classique",
        "client_id" => "tt-reprise-guest"
      })

    drain_updates()

    variant = Registry.get("trictrac_classique")
    runtime = TrictracCore.new(variant)

    pending = %{
      "key" => "reprise",
      "prompt" => "Choose whether to continue the game or take a reprise.",
      "choices" => ["tenir", "s'en aller"]
    }

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      trictrac =
        HermesTrictrac.Rules.Trictrac.Classique.set_turn_event_queue(runtime.trictrac, [pending])

      updated_engine = %{
        engine
        | variant: variant,
          status: :playing,
          turn_color: :white,
          turn_number: 1,
          pending_turn_decision: pending,
          trictrac: trictrac,
          runtime:
            runtime
            |> Map.put(:trictrac, trictrac)
            |> Map.put(:turn_color, :white)
            |> Map.put(:turn_number, 1)
            |> Map.put(:pending_turn_decision, pending)
      }

      %{state | engine: updated_engine}
    end)

    push(host_socket, "chat", %{
      "chat" => %{
        "author" => "white",
        "type" => "text",
        "data" => %{"text" => "ping"}
      }
    })

    assert_broadcast "update", %{
      game: %{"pending_turn_decision" => pending_turn_decision, "trictrac" => trictrac}
    }

    assert pending_turn_decision["key"] == "reprise"

    assert pending_turn_decision["prompt"] ==
             "Choose whether to continue the game or take a reprise."

    assert get_in(trictrac, ["turn_event_queue", Access.at(0), "key"]) == "reprise"
  end

  test "resign ends the active match through the channel", %{host_socket: socket} do
    push(socket, "resign", %{})

    assert_broadcast "update", %{
      game: %{"match" => %{"is_over" => true, "winner" => "black", "winner_kind" => "resign"}}
    }
  end

  test "channel update serializes trictrac legal move sequence metadata" do
    lobby = "tt-seq-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, host_socket} =
      UserSocket
      |> socket("user:7", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "trictrac_classique",
        "client_id" => "tt-seq-host"
      })

    {:ok, _guest_reply, _guest_socket} =
      UserSocket
      |> socket("user:8", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "jane",
        "variant" => "trictrac_classique",
        "client_id" => "tt-seq-guest"
      })

    drain_updates()

    variant = Registry.get("trictrac_classique")
    runtime = TrictracCore.new(variant)

    board =
      runtime.board
      |> put_in([:points, Access.at(23), :white], 14)
      |> put_in([:points, Access.at(17), :white], 1)

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      updated_engine = %{
        engine
        | variant: variant,
          status: :playing,
          turn_color: :white,
          turn_number: 1,
          board: board,
          dice: %{values: [6, 2], moves: [6, 2], moves_left: [6, 2], moves_played: []},
          legal_moves: [
            %{
              from: 17,
              to: 9,
              die: 8,
              count: 1,
              coin_mode: :intermediate_coin,
              dice_used: [6, 2],
              via: 11,
              sequence: [6, 2]
            }
          ],
          runtime: %{runtime | board: board}
      }

      %{state | engine: updated_engine}
    end)

    push(host_socket, "chat", %{
      "chat" => %{
        "author" => "white",
        "type" => "text",
        "data" => %{"text" => "ping"}
      }
    })

    assert_broadcast "update", %{game: %{"legal_moves" => legal_moves}}

    assert Enum.any?(legal_moves, fn move ->
             move["from"] == 17 and move["to"] == 9 and move["sequence"] == [6, 2] and
               move["via"] == 11
           end)
  end

  test "poule tables wait for the configured competitors, then start a seeded six-hole round" do
    lobby = "poule-lobby-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      join_poule(lobby, "user:poule-host", "nick", "poule-host", %{
        "queue_size" => "1",
        "ante" => "7",
        "margot_enabled" => "true"
      })

    assert host_reply.player == nil
    assert host_reply.viewer["role"] == "queued"
    assert host_reply.game["status"] == "waiting_for_competitors"
    assert host_reply.game["poule"]["config"]["queue_size"] == 1
    assert host_reply.game["poule"]["config"]["competitor_target"] == 3
    assert host_reply.game["poule"]["config"]["ante"] == 7
    assert host_reply.game["poule"]["config"]["margot_enabled"] == true

    {:ok, second_reply, _second_socket} =
      join_poule(lobby, "user:poule-guest", "jane", "poule-guest", %{
        "queue_size" => "9",
        "ante" => "99",
        "margot_enabled" => "false"
      })

    assert second_reply.player == nil
    assert second_reply.viewer["role"] == "queued"
    assert second_reply.game["status"] == "waiting_for_competitors"

    {:ok, third_reply, _third_socket} =
      join_poule(lobby, "user:poule-queue", "bob", "poule-queue", %{
        "queue_size" => "4",
        "ante" => "13",
        "margot_enabled" => "false"
      })

    assert third_reply.viewer["role"] in ["active", "queued"]

    if third_reply.viewer["role"] == "active" do
      assert third_reply.player["name"] == "bob"
    else
      assert third_reply.player == nil
    end

    assert third_reply.game["status"] == "playing"
    assert third_reply.game["variant"]["id"] == "trictrac_en_poule"
    assert third_reply.game["variant"]["active_variant_id"] == "trictrac_classique"

    draw_order_names = Enum.map(third_reply.game["poule"]["draw_order"], & &1["name"])

    assert Enum.sort(draw_order_names) == ["bob", "jane", "nick"]
    assert Enum.take(draw_order_names, 2) == [
             third_reply.game["players"]["host"]["name"],
             third_reply.game["players"]["guest"]["name"]
           ]

    assert Enum.map(third_reply.game["poule"]["queue"], & &1["name"]) == Enum.drop(draw_order_names, 2)
    assert third_reply.game["poule"]["config"]["queue_size"] == 1
    assert third_reply.game["poule"]["config"]["ante"] == 7
    assert third_reply.game["poule"]["config"]["margot_enabled"] == true

    pid = GenServer.whereis(GameServer.reg(lobby))
    state = :sys.get_state(pid)

    assert state.engine.variant.id == "trictrac_classique"
    assert state.engine.match.options["classiqueHoleTarget"] == 6
    assert state.engine.match.options["margotEnabled"] == true
    assert state.engine.pending_match_options == nil
  end

  test "poule spectators cannot act on the board and can claim open queue slots" do
    lobby = "poule-spectators-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      join_poule(lobby, "user:poule-a", "nick", "poule-a")

    {:ok, _guest_reply, _guest_socket} =
      join_poule(lobby, "user:poule-b", "jane", "poule-b")

    {:ok, _queued_reply, _queued_socket} =
      join_poule(lobby, "user:poule-c", "bob", "poule-c")

    {:ok, spectator_reply, spectator_socket} =
      join_poule(lobby, "user:poule-d", "dana", "poule-d")

    assert spectator_reply.player == nil
    assert spectator_reply.viewer["role"] == "spectator"
    assert spectator_reply.viewer["can_claim_queue_spot"] == false

    ref = push(spectator_socket, "roll", %{})

    assert_reply ref, :error, %{
      code: "inactive_viewer",
      msg: "Only an active player can do that."
    }

    pid = GenServer.whereis(GameServer.reg(lobby))
    state = :sys.get_state(pid)
    queued_member_id = List.first(state.session.queue)
    queued_member = state.session.members[queued_member_id]

    drain_updates()
    :ok = GameServer.leave(lobby, queued_member.name, queued_member.client_id)

    assert_broadcast "update", %{game: %{"poule" => %{"open_queue_slots" => 1}}}
    assert GameServer.viewer(lobby, "dana", "poule-d")["can_claim_queue_spot"] == true

    ref = push(spectator_socket, "claim_queue_spot", %{})
    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{game: %{"poule" => %{"open_queue_slots" => 0}}}

    assert GameServer.viewer(lobby, "dana", "poule-d")["role"] == "queued"
    snapshot = GameServer.peek(lobby)
    assert Enum.map(snapshot["poule"]["queue"], & &1["name"]) == ["dana"]
  end

  test "poule variants reject bot opponents" do
    lobby = "poule-bot-#{System.unique_integer([:positive])}"

    assert {:error,
            %{
              code: "bot_unavailable",
              msg: "Bot opponents are not available for multi-seat tables."
            }} =
             UserSocket
             |> socket("user:poule-bot", %{})
             |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
               "user" => "nick",
               "variant" => "trictrac_en_poule",
               "client_id" => "poule-bot",
               "queue_size" => "1",
               "ante" => "5",
               "margot_enabled" => "false",
               "bot" => "trictrac_zero"
             })
  end

  test "plucked poule tables start with fixed-fund config and no six-hole auto-target" do
    lobby = "plucked-poule-lobby-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      join_plucked_poule(lobby, "user:plucked-host", "nick", "plucked-host", %{
        "queue_size" => "1",
        "stake" => "100",
        "hole_value" => "5",
        "margot_enabled" => "true"
      })

    assert host_reply.viewer["role"] == "queued"
    assert host_reply.game["status"] == "waiting_for_competitors"

    {:ok, _second_reply, _second_socket} =
      join_plucked_poule(lobby, "user:plucked-guest", "jane", "plucked-guest")

    {:ok, third_reply, _third_socket} =
      join_plucked_poule(lobby, "user:plucked-queue", "bob", "plucked-queue")

    assert third_reply.game["variant"]["id"] == "trictrac_en_poule_plumee"
    assert third_reply.game["variant"]["active_variant_id"] == "trictrac_classique"
    assert third_reply.game["poule"]["style"] == "plucked_pot"
    assert third_reply.game["poule"]["config"]["stake"] == 100
    assert third_reply.game["poule"]["config"]["hole_value"] == 5
    assert third_reply.game["poule"]["config"]["competitor_target"] == 3
    assert third_reply.game["poule"]["pool"] == 300

    pid = GenServer.whereis(GameServer.reg(lobby))
    state = :sys.get_state(pid)

    assert state.engine.variant.id == "trictrac_classique"
    assert state.engine.match.options["pluckedPouleMode"] == true
    refute Map.has_key?(state.engine.match.options, "classiqueHoleTarget")
  end

  test "plucked poule tables reject resign" do
    lobby = "plucked-poule-resign-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, host_socket} =
      join_plucked_poule(lobby, "user:plucked-resign-host", "nick", "plucked-resign-host")

    {:ok, _guest_reply, guest_socket} =
      join_plucked_poule(lobby, "user:plucked-resign-guest", "jane", "plucked-resign-guest")

    {:ok, _queued_reply, queued_socket} =
      join_plucked_poule(lobby, "user:plucked-resign-queue", "bob", "plucked-resign-queue")

    acting_socket =
      [
        {GameServer.viewer(lobby, "nick", "plucked-resign-host")["role"], host_socket},
        {GameServer.viewer(lobby, "jane", "plucked-resign-guest")["role"], guest_socket},
        {GameServer.viewer(lobby, "bob", "plucked-resign-queue")["role"], queued_socket}
      ]
      |> Enum.find_value(fn
        {"active", socket} -> socket
        _ -> nil
      end)

    ref = push(acting_socket, "resign", %{})

    assert_reply ref, :error, %{
      code: "resign_unavailable",
      msg: "Resign is unavailable for plucked-pool tables."
    }
  end

  test "a tourner tables wait for in-game longueur consent before starting play" do
    lobby = "a-tourner-lobby-#{System.unique_integer([:positive])}"

    {:ok, host_reply, host_socket} =
      join_multiplayer(lobby, "user:tourner-host", "nick", "tourner-host", %{
        "variant" => "trictrac_aecrire_a_tourner"
      })

    assert host_reply.player == nil
    assert host_reply.viewer["role"] == "bench"
    assert host_reply.game["status"] == "waiting_for_players"

    {:ok, guest_reply, guest_socket} =
      join_multiplayer(lobby, "user:tourner-guest", "jane", "tourner-guest", %{
        "variant" => "trictrac_aecrire_a_tourner"
      })

    assert guest_reply.viewer["role"] == "bench"
    assert guest_reply.game["status"] == "waiting_for_players"

    {:ok, third_reply, third_socket} =
      join_multiplayer(lobby, "user:tourner-rest", "bob", "tourner-rest", %{
        "variant" => "trictrac_aecrire_a_tourner"
      })

    assert third_reply.player == nil
    assert third_reply.viewer["role"] == "bench"
    assert third_reply.game["status"] == "awaiting_order_draw"
    assert third_reply.game["variant"]["id"] == "trictrac_aecrire_a_tourner"
    assert third_reply.game["variant"]["active_variant_id"] == "trictrac_aecrire"
    assert third_reply.game["players"]["host"]["name"] == nil
    assert third_reply.game["players"]["guest"]["name"] == nil
    assert third_reply.game["multiplayer"]["mode"] == "a_tourner"
    assert third_reply.game["multiplayer"]["partie_length"] == 12
    assert third_reply.game["pending_match_options"] == nil
    assert third_reply.game["multiplayer"]["order_draw"]["step"] == "table"
    assert third_reply.game["multiplayer"]["order_draw"]["current_roller"]["name"] == "nick"

    assert third_reply.game["multiplayer"]["accounting"] == %{
             "cash_per_jeton_minor" => 125,
             "cash_per_fiche_minor" => 1250,
             "cash_minor_scale" => 100
           }

    assert Enum.map(third_reply.game["multiplayer"]["participants"], & &1["name"]) == [
             "nick",
             "jane",
             "bob"
           ]

    drain_updates()

    resolve_multiplayer_order_draw!(lobby, %{
      "nick" => host_socket,
      "jane" => guest_socket,
      "bob" => third_socket
    })

    drain_updates()

    assert GameServer.peek(lobby)["status"] == "awaiting_match_options"

    assert GameServer.peek(lobby)["pending_match_options"]["kind"] ==
             "multiplayer_partie_length_consent"

    ref =
      push(host_socket, "submit_match_options", %{
        "options" => %{"aEcrirePartieLengthConsent" => "9"}
      })

    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{game: %{"pending_match_options" => %{"responses" => %{"1" => "9"}}}}

    ref =
      push(guest_socket, "submit_match_options", %{
        "options" => %{"aEcrirePartieLengthConsent" => "9"}
      })

    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{game: %{"pending_match_options" => %{"responses" => %{"2" => "9"}}}}

    ref =
      push(third_socket, "submit_match_options", %{
        "options" => %{"aEcrirePartieLengthConsent" => "9"}
      })

    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{game: %{"status" => "playing", "multiplayer" => %{"partie_length" => 9}}}

    pid = GenServer.whereis(GameServer.reg(lobby))
    state = :sys.get_state(pid)

    assert state.engine.variant.id == "trictrac_aecrire"
    assert state.session.partie_length == 9
    assert state.session.pending_match_options == nil
  end

  test "multiplayer spectators cannot act and can claim open roster slots" do
    lobby = "multiplayer-spectators-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      join_multiplayer(lobby, "user:multi-a", "nick", "multi-a", %{
        "variant" => "trictrac_aecrire_chouette"
      })

    {:ok, _guest_reply, _guest_socket} =
      join_multiplayer(lobby, "user:multi-b", "jane", "multi-b", %{
        "variant" => "trictrac_aecrire_chouette"
      })

    {:ok, _bench_reply, _bench_socket} =
      join_multiplayer(lobby, "user:multi-c", "bob", "multi-c", %{
        "variant" => "trictrac_aecrire_chouette"
      })

    {:ok, spectator_reply, spectator_socket} =
      join_multiplayer(lobby, "user:multi-d", "dana", "multi-d", %{
        "variant" => "trictrac_aecrire_chouette"
      })

    assert spectator_reply.player == nil
    assert spectator_reply.viewer["role"] == "spectator"
    assert spectator_reply.viewer["can_claim_roster_slot"] == false

    ref =
      push(spectator_socket, "submit_match_options", %{
        "options" => %{"aEcrirePartieLengthConsent" => "12"}
      })

    assert_reply ref, :error, %{
      code: "inactive_viewer",
      msg: "Only an active player can do that."
    }

    ref = push(spectator_socket, "roll", %{})

    assert_reply ref, :error, %{
      code: "inactive_viewer",
      msg: "Only a rostered competitor can participate in the order draw."
    }

    drain_updates()
    :ok = GameServer.leave(lobby, "bob", "multi-c")

    assert_broadcast "update", %{game: %{"multiplayer" => %{"waiting_slots" => 1}}}
    assert GameServer.viewer(lobby, "dana", "multi-d")["can_claim_roster_slot"] == true

    ref = push(spectator_socket, "claim_roster_slot", %{})
    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{game: %{"status" => "awaiting_order_draw", "multiplayer" => %{"waiting_slots" => 0}}}

    assert GameServer.viewer(lobby, "dana", "multi-d")["role"] == "bench"
    snapshot = GameServer.peek(lobby)

    assert Enum.map(snapshot["multiplayer"]["participants"], & &1["name"]) == [
             "nick",
             "jane",
             "dana"
           ]
    assert snapshot["status"] == "awaiting_order_draw"
  end

  test "multiplayer variants reject bot opponents" do
    lobby = "multiplayer-bot-#{System.unique_integer([:positive])}"

    assert {:error,
            %{
              code: "bot_unavailable",
              msg: "Bot opponents are not available for multi-seat tables."
            }} =
             UserSocket
             |> socket("user:multi-bot", %{})
             |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
               "user" => "nick",
               "variant" => "trictrac_aecrire_chouette",
               "client_id" => "multi-bot",
               "cash_per_jeton_minor" => "125",
               "bot" => "trictrac_zero"
             })
  end

  defp drain_updates do
    receive do
      %Phoenix.Socket.Broadcast{event: "update"} -> drain_updates()
    after
      0 -> :ok
    end
  end

  defp join_poule(lobby, socket_id, user, client_id, overrides \\ %{}) do
    payload =
      Map.merge(
        %{
          "user" => user,
          "variant" => "trictrac_en_poule",
          "client_id" => client_id,
          "queue_size" => "1",
          "ante" => "3",
          "margot_enabled" => "false"
        },
        overrides
      )

    UserSocket
    |> socket(socket_id, %{})
    |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", payload)
  end

  defp join_plucked_poule(lobby, socket_id, user, client_id, overrides \\ %{}) do
    payload =
      Map.merge(
        %{
          "user" => user,
          "variant" => "trictrac_en_poule_plumee",
          "client_id" => client_id,
          "queue_size" => "1",
          "stake" => "50",
          "hole_value" => "5",
          "margot_enabled" => "false"
        },
        overrides
      )

    UserSocket
    |> socket(socket_id, %{})
    |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", payload)
  end

  defp join_multiplayer(lobby, socket_id, user, client_id, overrides) do
    payload =
      Map.merge(
        %{
          "user" => user,
          "variant" => "trictrac_aecrire_a_tourner",
          "client_id" => client_id,
          "cash_per_jeton_minor" => "125"
        },
        overrides
      )

    UserSocket
    |> socket(socket_id, %{})
    |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", payload)
  end

  defp resolve_multiplayer_order_draw!(lobby, sockets_by_name) do
    case GameServer.peek(lobby) do
      %{
        "status" => "awaiting_order_draw",
        "multiplayer" => %{"order_draw" => %{"current_roller" => %{"name" => name}}}
      } ->
        ref = push(Map.fetch!(sockets_by_name, name), "roll", %{})
        assert_reply ref, :ok, %{}
        resolve_multiplayer_order_draw!(lobby, sockets_by_name)

      %{"status" => "awaiting_match_options"} ->
        :ok

      snapshot ->
        flunk("expected order draw to resolve into awaiting_match_options, got: #{inspect(snapshot)}")
    end
  end
end

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

    assert {:error, %{msg: msg}} =
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

  test "first backgammon roll updates the opening roll state", %{
    host_socket: socket
  } do
    assert_broadcast "update", %{game: %{"opening_roll" => %{"rolls" => %{"white" => nil}}}}
    push(socket, "roll", %{})
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

  defp drain_updates do
    receive do
      %Phoenix.Socket.Broadcast{event: "update"} -> drain_updates()
    after
      0 -> :ok
    end
  end
end

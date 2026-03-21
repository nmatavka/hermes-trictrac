defmodule Backgammon.GameServer do
  use GenServer

  alias Backgammon.GameSnapshot
  alias Backgammon.Rules.Engine

  def reg(name) do
    {:via, Registry, {Backgammon.GameReg, name}}
  end

  def start(name, variant \\ "backgammon") do
    spec = %{
      id: {__MODULE__, name},
      start: {__MODULE__, :start_link, [name, variant]},
      restart: :permanent,
      type: :worker
    }

    Backgammon.GameSup.start_child(spec)
  end

  def start_link(name, variant) do
    GenServer.start_link(__MODULE__, {name, variant}, name: reg(name))
  end

  def join(name, user, client_id, variant \\ "backgammon"), do: GenServer.call(reg(name), {:join, user, client_id, variant})
  def move(name, move, user, client_id), do: GenServer.call(reg(name), {:move, move, user, client_id})
  def roll(name, user, client_id), do: GenServer.call(reg(name), {:roll, user, client_id})
  def undo(name, user, client_id), do: GenServer.call(reg(name), {:undo, user, client_id})
  def confirm(name, user, client_id), do: GenServer.call(reg(name), {:confirm, user, client_id})
  def submit_match_options(name, options, user, client_id), do: GenServer.call(reg(name), {:submit_match_options, options, user, client_id})
  def submit_turn_decision(name, decision, user, client_id), do: GenServer.call(reg(name), {:submit_turn_decision, decision, user, client_id})
  def resign(name, user, client_id), do: GenServer.call(reg(name), {:resign, user, client_id})
  def chat(name, chat, user), do: GenServer.call(reg(name), {:chat, chat, user})
  def peek(name), do: GenServer.call(reg(name), :peek)
  def reset(name, _user, _client_id), do: GenServer.call(reg(name), :reset)

  def init({name, variant}) do
    engine = Engine.new(name, variant)
    {:ok, %{name: name, chat: [], engine: engine}}
  end

  def handle_call({:join, user, client_id, _variant}, _from, state) do
    case Engine.join(state.engine, user, client_id) do
      {:ok, engine, player} ->
        updated = %{state | engine: engine}
        Backgammon.BackupAgent.put(state.name, updated)
        {:reply, {:ok, %{game: attach_chat(engine, updated.chat), player: player}}, updated}

      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:move, move, user, client_id}, _from, state), do: proxy(state, Engine.move(state.engine, move, user, client_id))
  def handle_call({:roll, user, client_id}, _from, state), do: proxy(state, Engine.roll(state.engine, user, client_id))
  def handle_call({:undo, user, client_id}, _from, state), do: proxy(state, Engine.undo(state.engine, user, client_id))
  def handle_call({:confirm, user, client_id}, _from, state), do: proxy(state, Engine.confirm(state.engine, user, client_id))

  def handle_call({:submit_match_options, options, user, client_id}, _from, state),
    do: proxy(state, Engine.submit_match_options(state.engine, options, user, client_id))

  def handle_call({:submit_turn_decision, decision, user, client_id}, _from, state),
    do: proxy(state, Engine.submit_turn_decision(state.engine, decision, user, client_id))

  def handle_call({:resign, user, client_id}, _from, state),
    do: proxy(state, Engine.resign(state.engine, user, client_id))

  def handle_call({:chat, chat, _user}, _from, state) do
    updated = %{state | chat: state.chat ++ [chat]}
    Backgammon.BackupAgent.put(state.name, updated)
    {:reply, {:ok, attach_chat(updated.engine, updated.chat)}, updated}
  end

  def handle_call(:peek, _from, state) do
    {:reply, attach_chat(state.engine, state.chat), state}
  end

  def handle_call(:reset, _from, state) do
    if state.engine.match.is_over do
      engine = Engine.reset(state.engine)
      updated = %{state | engine: engine, chat: []}
      Backgammon.BackupAgent.put(state.name, updated)
      {:reply, {:ok, attach_chat(engine, [])}, updated}
    else
      {:reply, {:error, "Reset is only available after the match is over."}, state}
    end
  end

  defp proxy(state, {:ok, engine}) do
    updated = %{state | engine: engine}
    Backgammon.BackupAgent.put(state.name, updated)
    {:reply, {:ok, attach_chat(engine, updated.chat)}, updated}
  end

  defp proxy(state, {:error, msg}), do: {:reply, {:error, msg}, state}

  defp attach_chat(engine, chat) do
    engine
    |> Engine.snapshot()
    |> GameSnapshot.with_chat(chat)
  end
end

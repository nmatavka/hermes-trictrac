defmodule Backgammon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Backgammon.PubSub},
      {Registry, keys: :unique, name: Backgammon.GameReg},
      BackgammonWeb.Endpoint,
      Backgammon.BackupAgent,
      Backgammon.GameSup
    ]

    opts = [strategy: :one_for_one, name: Backgammon.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    BackgammonWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

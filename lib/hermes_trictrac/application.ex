defmodule HermesTrictrac.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: HermesTrictrac.PubSub},
      {Registry, keys: :unique, name: HermesTrictrac.GameReg},
      HermesTrictracWeb.Endpoint,
      HermesTrictrac.BackupAgent,
      HermesTrictrac.TrictracModelBot,
      HermesTrictrac.GameSup
    ]

    opts = [strategy: :one_for_one, name: HermesTrictrac.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    HermesTrictracWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

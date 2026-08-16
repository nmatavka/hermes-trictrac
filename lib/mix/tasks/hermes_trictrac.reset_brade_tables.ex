defmodule Mix.Tasks.HermesTrictrac.ResetBradeTables do
  use Mix.Task

  @shortdoc "Resets running Bräde tables after the parallel-play rule correction"

  alias HermesTrictrac.Maintenance

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    names = Maintenance.reset_brade_tables()

    message =
      case names do
        [] -> "Reset 0 Bräde table(s)."
        _ -> "Reset #{length(names)} Bräde table(s): #{Enum.join(names, ", ")}"
      end

    Mix.shell().info(message)
  end
end

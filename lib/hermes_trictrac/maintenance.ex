defmodule HermesTrictrac.Maintenance do
  @moduledoc false

  alias HermesTrictrac.GameServer

  def reset_brade_tables do
    HermesTrictrac.GameReg
    |> Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.flat_map(&reset_brade_table/1)
  end

  defp reset_brade_table(name) do
    case GameServer.peek(name) do
      %{"variant" => %{"id" => "brade"}} ->
        case GameServer.reset_for_rule_correction(name) do
          :ok -> [name]
          _ -> []
        end

      _ ->
        []
    end
  catch
    :exit, _reason -> []
  end
end

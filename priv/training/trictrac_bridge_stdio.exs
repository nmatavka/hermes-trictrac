alias HermesTrictrac.Training.TrictracBridge

defmodule HermesTrictrac.Training.TrictracBridgeStdio do
  def run do
    IO.binstream(:stdio, :line)
    |> Enum.each(&handle_line/1)
  end

  defp handle_line(line) do
    line = String.trim(line)

    if line != "" do
      line
      |> Jason.decode()
      |> handle_request()
      |> then(fn response ->
        response
        |> Jason.encode!()
        |> Kernel.<>("\n")
        |> IO.write()
      end)
    end
  end

  defp handle_request({:ok, %{"id" => id, "cmd" => "ping"}}) do
    result(TrictracBridge.ping(), id)
  end

  defp handle_request({:ok, %{"id" => id, "cmd" => "new_game"} = request}) do
    result(TrictracBridge.new_game(Map.get(request, "config", %{})), id)
  end

  defp handle_request(
         {:ok, %{"id" => id, "cmd" => "step", "state" => state, "action" => action} = request}
       ) do
    result(TrictracBridge.step(state, action, Map.get(request, "config", %{})), id)
  end

  defp handle_request({:ok, %{"id" => id}}) do
    %{"id" => id, "ok" => false, "error" => "Unknown command."}
  end

  defp handle_request({:error, error}) do
    %{"id" => nil, "ok" => false, "error" => Exception.message(error)}
  end

  defp result({:ok, payload}, id), do: %{"id" => id, "ok" => true, "result" => payload}
  defp result({:error, message}, id), do: %{"id" => id, "ok" => false, "error" => message}
end

HermesTrictrac.Training.TrictracBridgeStdio.run()

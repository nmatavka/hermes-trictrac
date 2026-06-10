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
      |> case do
        {:ok, request} ->
          TrictracBridge.rpc(request)

        {:error, error} ->
          %{"id" => nil, "ok" => false, "error" => Exception.message(error)}
      end
      |> then(fn response ->
        response
        |> Jason.encode!()
        |> Kernel.<>("\n")
        |> IO.write()
      end)
    end
  end
end

HermesTrictrac.Training.TrictracBridgeStdio.run()

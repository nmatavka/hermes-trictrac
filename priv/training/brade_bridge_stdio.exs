alias HermesTrictrac.Training.RaceTrainingBridge

IO.binstream(:stdio, :line)
|> Enum.each(fn line ->
  line = String.trim(line)

  if line != "" do
    response =
      case Jason.decode(line) do
        {:ok, request} -> RaceTrainingBridge.rpc(request)
        {:error, error} -> %{"id" => nil, "ok" => false, "error" => Exception.message(error)}
      end

    IO.write(Jason.encode!(response) <> "\n")
  end
end)

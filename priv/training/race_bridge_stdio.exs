alias HermesTrictrac.Training.RaceTrainingBridge

for line <- IO.stream(:stdio, :line) do
  case Jason.decode(line) do
    {:ok, request} -> IO.puts(Jason.encode!(RaceTrainingBridge.rpc(request)))
    _ -> IO.puts(Jason.encode!(%{"id" => nil, "ok" => false, "error" => "Invalid JSON request."}))
  end
end

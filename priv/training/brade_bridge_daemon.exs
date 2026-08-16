alias HermesTrictrac.Training.RaceTrainingBridge

defmodule HermesTrictrac.Training.RaceTrainingBridgeDaemon do
  def run(socket_path, ready_path, pid_path) do
    File.mkdir_p!(Path.dirname(socket_path))
    cleanup([socket_path, ready_path, pid_path])
    {:ok, socket} = :socket.open(:local, :stream, :default)
    acceptor = nil

    try do
      :ok = :socket.bind(socket, %{family: :local, path: String.to_charlist(socket_path)})
      :ok = :socket.listen(socket, 128)
      File.write!(pid_path, :os.getpid() |> List.to_string())
      File.write!(ready_path, "ready\n")
      acceptor = Task.async(fn -> accept_loop(socket, self()) end)

      receive do
        :shutdown -> :ok
      end
    after
      :socket.close(socket)
      if acceptor, do: Task.shutdown(acceptor, :brutal_kill)
      cleanup([socket_path, ready_path, pid_path])
    end
  end

  defp accept_loop(socket, parent) do
    case :socket.accept(socket, :infinity) do
      {:ok, client} ->
        Task.start(fn -> client_loop(client, "", parent) end)
        accept_loop(socket, parent)

      {:error, _} ->
        :ok
    end
  end

  defp client_loop(socket, buffer, parent) do
    case :socket.recv(socket, 0, :infinity) do
      {:ok, chunk} ->
        {lines, rest} = split_lines(buffer <> chunk)

        if Enum.any?(lines, &handle_line(socket, &1, parent)) do
          :ok
        else
          client_loop(socket, rest, parent)
        end

      {:error, _} ->
        :ok
    end
  after
    :socket.close(socket)
  end

  defp handle_line(_socket, "", _parent), do: false

  defp handle_line(socket, line, parent) do
    response =
      case Jason.decode(line) do
        {:ok, request} -> RaceTrainingBridge.rpc(request)
        {:error, error} -> %{"id" => nil, "ok" => false, "error" => Exception.message(error)}
      end

    :ok = :socket.send(socket, Jason.encode!(response) <> "\n")

    if get_in(response, ["result", "shutdown"]) == true do
      send(parent, :shutdown)
      true
    else
      false
    end
  end

  defp split_lines(buffer) do
    parts = :binary.split(buffer, "\n", [:global])
    {Enum.drop(parts, -1) |> Enum.map(&String.trim_trailing(&1, "\r")), List.last(parts) || ""}
  end

  defp cleanup(paths) do
    Enum.each(paths, fn path ->
      try do
        File.rm(path)
      rescue
        _ -> :ok
      end
    end)
  end
end

[socket_path, ready_path, pid_path] =
  System.argv()
  |> case do
    ["--" | rest] -> rest
    rest -> rest
  end

HermesTrictrac.Training.RaceTrainingBridgeDaemon.run(socket_path, ready_path, pid_path)

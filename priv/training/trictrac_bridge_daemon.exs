alias HermesTrictrac.Training.TrictracBridge

defmodule HermesTrictrac.Training.TrictracBridgeDaemon do
  def run(socket_path, ready_path, pid_path) do
    TrictracBridge.ensure_daemon_tables()
    File.mkdir_p!(Path.dirname(socket_path))
    cleanup_paths(socket_path, ready_path, pid_path)

    {:ok, listen_socket} = :socket.open(:local, :stream, :default)
    :ok = :socket.bind(listen_socket, %{family: :local, path: String.to_charlist(socket_path)})
    :ok = :socket.listen(listen_socket, 128)

    File.write!(pid_path, os_pid())
    File.write!(ready_path, "ready\n")

    acceptor = Task.async(fn -> accept_loop(listen_socket, self()) end)

    receive do
      :shutdown ->
        :ok
    after
      :infinity ->
        :ok
    end

    :socket.close(listen_socket)
    Task.shutdown(acceptor, :brutal_kill)
  after
    cleanup_paths(socket_path, ready_path, pid_path)
  end

  defp accept_loop(listen_socket, parent) do
    case :socket.accept(listen_socket, :infinity) do
      {:ok, socket} ->
        Task.start(fn -> handle_client(socket, parent) end)
        accept_loop(listen_socket, parent)

      {:error, {:closed, _reason}} ->
        :ok

      {:error, :closed} ->
        :ok

      {:error, _reason} ->
        :ok
    end
  end

  defp handle_client(socket, parent) do
    read_loop(socket, "", parent)
  after
    :socket.close(socket)
  end

  defp read_loop(socket, buffer, parent) do
    case :socket.recv(socket, 0, :infinity) do
      {:ok, chunk} ->
        {lines, tail} = split_lines(buffer <> chunk)

        stop? =
          Enum.reduce_while(lines, false, fn line, _acc ->
            case handle_line(socket, line) do
              :continue -> {:cont, false}
              :shutdown ->
                send(parent, :shutdown)
                {:halt, true}
            end
          end)

        if stop? do
          :ok
        else
          read_loop(socket, tail, parent)
        end

      {:error, {:closed, _reason}} ->
        :ok

      {:error, :closed} ->
        :ok

      {:error, _reason} ->
        :ok
    end
  end

  defp handle_line(_socket, ""), do: :continue

  defp handle_line(socket, line) do
    response =
      line
      |> Jason.decode()
      |> case do
        {:ok, request} ->
          TrictracBridge.rpc(request)

        {:error, error} ->
          %{"id" => nil, "ok" => false, "error" => Exception.message(error)}
      end

    payload = Jason.encode!(response) <> "\n"

    case :socket.send(socket, payload) do
      :ok ->
        case response do
          %{"ok" => true, "result" => %{"shutdown" => true}} -> :shutdown
          _ -> :continue
        end

      {:error, _reason} ->
        :continue
    end
  end

  defp split_lines(buffer) do
    parts = :binary.split(buffer, "\n", [:global])

    case parts do
      [] ->
        {[], ""}

      [_single] when buffer == "" ->
        {[], ""}

      _ ->
        tail = List.last(parts)
        lines = parts |> Enum.drop(-1) |> Enum.map(&String.trim_trailing(&1, "\r"))
        {lines, tail}
    end
  end

  defp cleanup_paths(socket_path, ready_path, pid_path) do
    Enum.each([socket_path, ready_path, pid_path], fn path ->
      try do
        File.rm(path)
      rescue
        _ -> :ok
      end
    end)
  end

  defp os_pid do
    :os.getpid() |> List.to_string()
  end
end

[socket_path, ready_path, pid_path] =
  System.argv()
  |> case do
    ["--" | rest] -> rest
    rest -> rest
  end
HermesTrictrac.Training.TrictracBridgeDaemon.run(socket_path, ready_path, pid_path)

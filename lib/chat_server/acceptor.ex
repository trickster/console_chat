defmodule ChatServer.Acceptor do
  use Task, restart: :transient

  require Logger

  def start_link([] = _opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    case :gen_tcp.listen(8080, [
           :binary,
           ifaddr: {0, 0, 0, 0},
           active: true,
           packet: :line,
           reuseaddr: true
         ]) do
      {:ok, listen_sock} ->
        Logger.info("Listening on port 8080")
        accept_loop(listen_sock)

      {:error, reason} ->
        raise "Fail to listen on port 5006: #{inspect(reason)}"
    end
  end

  defp accept_loop(listen_sock) do
    case :gen_tcp.accept(listen_sock) do
      {:ok, socket} ->
        :gen_tcp.controlling_process(socket, Process.whereis(ChatServer.ConnectionSupervisor))
        ChatServer.ConnectionSupervisor.register(ChatServer.ConnectionSupervisor, socket)
        accept_loop(listen_sock)

      {:error, reason} ->
        raise "Failed to accept connection: #{inspect(reason)}"
    end
  end
end

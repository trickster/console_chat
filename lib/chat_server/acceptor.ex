defmodule ChatServer.Acceptor do
  # if the task is not stopped gracefully, it will restart, if we stop it, it won't
  use Task, restart: :transient

  require Logger

  def start_link([] = _opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  # when you start with active - true
  # data from the socket is sent to controlling process as messages
  # data, sock errors, sock closed

  # active: :true is for continuously waiting to listen to messages on the socket
  # active: :once is better, it listens to one message and goes to sleep
  # only to be waken up by controlling process with :inet.setopts()
  # this is good for backpressure, as we will only setopts when we are done with current message
  def run do
    case :gen_tcp.listen(8080, [
           :binary,
           ifaddr: {0, 0, 0, 0},
           #  active: :once,
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

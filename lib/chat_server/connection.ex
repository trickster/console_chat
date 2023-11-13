defmodule ChatServer.Connection do
  use GenServer

  require Logger

  defstruct [:socket]

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    Logger.debug("Started connection handler")
    {:ok, %__MODULE__{socket: socket}}
  end

  @impl true
  def handle_info({:tcp, socket, data}, %__MODULE__{socket: socket} = state) do
    # data is data
    Logger.debug("Received data #{inspect(data)}")

    ChatServer.ConnectionSupervisor.broadcast(
      ChatServer.ConnectionSupervisor,
      self(),
      data
    )

    {:noreply, state}
  end

  def handle_info({:tcp_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    Logger.error("Received TCP error: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    Logger.debug("TCP conn closed")
    {:stop, :normal, state}
  end

  def push({pid, _}, packet) do
    Logger.info("I AM IN CONNECTION")
    GenServer.cast(pid, {:push, packet})
  end

  @impl true
  def handle_cast({:push, packet}, %__MODULE__{socket: socket}) do
    # IO.inspect(socket)

    case :gen_tcp.send(socket, packet) do
      :ok -> {:noreply, %__MODULE__{socket: socket}}
      {:error, :closed} -> {:stop, :normal, %__MODULE__{socket: socket}}
    end
  end
end

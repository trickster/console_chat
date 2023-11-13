defmodule ChatServer.ConnectionSupervisor do
  @moduledoc """

  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :no_args, opts)
  end

  @impl true
  def init(:no_args) do
    # DynamicSupervisor.init(strategy: :one_for_one, max_children: 50)
    {:ok, {%{}, %{}}}
  end

  def register(server, socket) do
    GenServer.cast(server, {:register, socket})
  end

  def broadcast(server, pid, msg) do
    # connection name
    name = client_name(server, pid)
    GenServer.call(server, {:broadcast, {name, pid, msg}})
  end

  def client_name(server, pid), do: GenServer.call(server, {:client_name, pid})

  @impl true
  def handle_call({:broadcast, {name, pid, msg}}, _from, state) do
    IO.inspect(pid)
    outgoing_msg = construct_msg({name, msg})

    {names, pids} = state

    Logger.info(
      "PIDS #{inspect(pids)}, names #{inspect(names)}, current name: #{name}, calling pid: #{inspect(pid)}"
    )

    # pids |> Enum.each(&ChatServer.Connection.push(&1, outgoing_msg))

    Logger.info("Broadcasting message #{inspect(msg)}")
    mentioned = List.flatten(Regex.scan(~r/@(\w+)/, msg, capture: :all_but_first))
    mentioned_tuples = transform(names, mentioned)

    if length(mentioned_tuples) > 0 do
      Logger.info("Mentioned: #{inspect(mentioned_tuples)}")
      talker_pid = Map.get(names, name)

      (mentioned_tuples ++ [{talker_pid, name}])
      |> Enum.each(&ChatServer.Connection.push(&1, outgoing_msg))
    else
      Logger.info("sent to all")
      pids |> Enum.each(&ChatServer.Connection.push(&1, outgoing_msg))
    end

    {:reply, :ok, state}

    # mentioned_tuples
    # |> Enum.each(&ChatServer.Connection.push(&1, "\a\r\n"))
    # {:reply, :ok, state}
  end

  @impl true
  def handle_call({:client_name, pid}, _from, {_, pids} = state) do
    %{^pid => name} = pids
    {:reply, name, state}
  end

  @impl true
  def handle_cast({:register, socket}, state) do
    Logger.info("#{inspect(socket)}")

    case req_register(socket) do
      :ok ->
        {:noreply, state}

      {:error, :closed} ->
        {:noreply, state}

      err ->
        Logger.error("There was an error registering client: #{socket}, #{err}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:tcp, socket, data}, {names, pids} = state) do
    [name | _] = String.split(data)

    case names do
      %{^name => _} ->
        request_new_name(socket, name)
        {:noreply, state}

      _ ->
        {:ok, pid} =
          DynamicSupervisor.start_child(
            ChatServer.ChatDynamicSup,
            {ChatServer.Connection, socket}
          )

        send_welcome_msg(name, names, socket)
        send_most_recent_msgs(socket)
        hand_over_control(socket, pid)
        broadcast_join(state, name)
        {:noreply, {Map.put(names, name, pid), Map.put(pids, pid, name)}}
    end
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _, :process, pid, _reason}, {names, pids}) do
    %{^pid => name} = pids

    # Broadcast to everyone user has left
    broadcast_left(name)
    {:noreply, {Map.delete(names, name), Map.delete(pids, pid)}}
  end

  defp construct_msg({name, msg}) do
    ts() <> "<" <> name <> "> " <> msg
  end

  defp request_new_name(socket, name) do
    :gen_tcp.send(
      socket,
      "The nickname #{name} already exists. " <> "Please choose a new nickname." <> "\r\n"
    )
  end

  defp send_welcome_msg(name, names, socket) do
    users = for {other, _} <- names, other != name, do: other

    :gen_tcp.send(
      socket,
      "You are connected with #{length(users)} other user(s): [#{user_string(users)}]" <> "\r\n"
    )
  end

  # TODO: Send the most recent messages to the user.
  defp send_most_recent_msgs(_socket) do
    # :ok = :gen_tcp.send(socket, "Getting stuff\r\n")
  end

  defp hand_over_control(socket, pid) do
    Process.monitor(pid)
    IO.inspect(socket)
    IO.inspect(pid)
    :gen_tcp.controlling_process(socket, pid)
  end

  defp broadcast_join(state, name) do
    {_, pids} = state
    pids |> Enum.each(&ChatServer.Connection.push(&1, ts() <> "#{name} has joined" <> "\r\n"))
  end

  defp broadcast_left(name) do
    Logger.info("TODO - broadcast event: #{name} has left")
  end

  defp req_register(socket) do
    request_name(socket)
  end

  defp request_name(socket) do
    :gen_tcp.send(
      socket,
      "Welcome to The Chat! Please enter your name." <> "\r\n"
    )
  end

  defp user_string(users, str \\ "")

  defp user_string([user], str) do
    user_string([], str <> "#{user}")
  end

  defp user_string([], str) do
    str
  end

  defp user_string([h | t], str) do
    user_string(t, str <> h <> ", ")
  end

  defp ts() do
    "[#{Time.truncate(Time.utc_now(), :second)}] "
  end

  def transform(map, list) do
    for key <- list, Map.has_key?(map, key), do: {map[key], key}
  end
end

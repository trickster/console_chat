defmodule ChatServer.Supervisor do
  @moduledoc """
  This is a supervisor that supervises dynamic supervisor (that handles each connection)
  and a socket acceptor
  """
  use Supervisor

  def start_link([] = _opts) do
    Supervisor.start_link(__MODULE__, :no_args)
  end

  @impl true
  def init(:no_args) do
    children = [
      {ChatServer.ConnectionSupervisor, name: ChatServer.ConnectionSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: ChatServer.ChatDynamicSup},
      ChatServer.Acceptor
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end

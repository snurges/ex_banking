defmodule ExBanking.Supervisor do
  @moduledoc """
  This supervisor is responsible for:
  - A supervisor monitoring user processes.
  - A Registry providing a key-value store for user processes.
  """
  use Supervisor

  @registry :user_registry

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {ExBanking.UserSupervisor, []},
      {Registry, [keys: :unique, name: @registry]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

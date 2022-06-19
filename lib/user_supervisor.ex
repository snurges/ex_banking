defmodule ExBanking.UserSupervisor do
  @moduledoc """
  This supervisor is responsible for user processes.
  """
  use DynamicSupervisor
  alias ExBanking.User

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_child(name) do
    child_specification = {User, name}

    DynamicSupervisor.start_child(__MODULE__, child_specification)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

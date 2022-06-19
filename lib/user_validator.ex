defmodule ExBanking.UserValidator do
  @moduledoc """
  Module that handles validation requests regarding User logic
  """

  def user_exists?(user) do
    !(lookup(user) == [])
  end

  defp lookup(user) do
    Registry.lookup(:user_registry, user)
  end
end

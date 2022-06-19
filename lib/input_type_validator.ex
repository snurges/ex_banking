defmodule ExBanking.InputTypeValidator do
  def is_valid?({:create, user}) when is_bitstring(user), do: true

  def is_valid?({:deposit, user, amount, currency})
      when is_bitstring(user) and is_number(amount) and is_bitstring(currency) and amount > 0,
      do: true

  def is_valid?({:withdraw, user, amount, currency})
      when is_bitstring(user) and is_number(amount) and is_bitstring(currency) and amount > 0,
      do: true

  def is_valid?({:get_balance, user, currency})
      when is_bitstring(user) and is_bitstring(currency),
      do: true

  def is_valid?({:send, from_user, to_user, amount, currency})
      when is_bitstring(from_user) and is_bitstring(to_user) and is_number(amount) and
             is_bitstring(currency) and amount > 0,
      do: true

  # When input arguments are not valid
  def is_valid?(_) do
    false
  end
end

defmodule ExBanking.User do
  use GenServer

  @registry :user_registry
  @max_process_count 10

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def deposit(user, amount, currency) do
    user |> via_tuple() |> GenServer.call({:deposit, amount, currency})
  end

  def withdraw(user, amount, currency) do
    user |> via_tuple() |> GenServer.call({:withdraw, amount, currency})
  end

  def get_balance(user, currency) do
    user |> via_tuple() |> GenServer.call({:get_balance, currency})
  end

  @impl true
  def init(name) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:deposit, amount, currency}, _from, state) do
    case process_count_too_high? do
      false ->
        balance = get_updated_balance(state, currency, amount, &(&1 + &2))

        {:reply, {:ok, balance}, balance}

      true ->
        {:reply, {:error, :too_many_requests_to_user}, state}
    end
  end

  @impl true
  def handle_call({:withdraw, amount, currency}, _from, state) do
    with false <- process_count_too_high?,
         true <- Map.get(state, currency) >= amount do
      balance = get_updated_balance(state, currency, amount, &(&1 - &2))

      {:reply, {:ok, balance}, balance}
    else
      true -> {:reply, {:error, :too_many_requests_to_user}, state}
      false -> {:reply, {:error, :not_enough_money}, state}
    end
  end

  @impl true
  def handle_call({:get_balance, currency}, _from, state) do
    case process_count_too_high? do
      true ->
        {:reply, {:error, :too_many_requests_to_user}, state}

      false ->
        balance = Map.get(state, currency) || 0
        {:reply, {:ok, balance}, state}
    end
  end

  ## Private Functions
  defp via_tuple(name),
    do: {:via, Registry, {@registry, name}}

  defp get_updated_balance(state, currency, amount, calculate_balance) do
    {_value, updated_balance} =
      Map.get_and_update(state, currency, fn balance ->
        {balance, calculate_balance.(balance || 0, amount) |> round(2)}
      end)

    updated_balance
  end

  defp round(amount, decimal_points) when is_float(amount),
    do: Float.round(amount, decimal_points)

  defp round(amount, _) do
    amount
  end

  defp process_count_too_high?() do
    {:message_queue_len, count} = Process.info(self(), :message_queue_len)
    count > @max_process_count
  end
end

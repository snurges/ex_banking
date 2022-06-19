defmodule ExBanking do
  use Application

  alias ExBanking.{UserSupervisor, InputValidator, UserValidator, User}

  def start(_type, _args) do
    ExBanking.Supervisor.start_link([])
  end

  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) do
    with true <- InputValidator.is_valid?({:create, user}) do
      with false <- UserValidator.user_exists?(user) do
        UserSupervisor.start_child(user)
        {:ok}
      else
        true -> {:error, :user_already_exists}
      end
    else
      false -> {:error, :wrong_arguments}
    end
  end

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency) do
    with true <- InputValidator.is_valid?({:deposit, user, amount, currency}) do
      with true <- UserValidator.user_exists?(user) do
        User.deposit(user, amount, currency)
      else
        false -> {:error, :user_does_not_exist}
      end
    else
      false -> {:error, :wrong_arguments}
    end
  end

  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency) do
    with true <- InputValidator.is_valid?({:withdraw, user, amount, currency}) do
      with true <- UserValidator.user_exists?(user) do
        User.withdraw(user, amount, currency)
      else
        false -> {:error, :user_does_not_exist}
      end
    else
      false -> {:error, :wrong_arguments}
    end
  end

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency) do
    with true <- InputValidator.is_valid?({:get_balance, user, currency}) do
      with true <- UserValidator.user_exists?(user) do
        User.get_balance(user, currency)
      else
        false -> {:error, :user_does_not_exist}
      end
    else
      false -> {:error, :wrong_arguments}
    end
  end

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number, to_user_balance :: number}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency) do
    with true <- InputValidator.is_valid?({:send, from_user, to_user, amount, currency}) do
      cond do
        UserValidator.user_exists?(from_user) == false ->
          {:error, :sender_does_not_exist}

        UserValidator.user_exists?(to_user) == false ->
          {:error, :receiver_does_not_exist}

        true ->
          case User.withdraw(from_user, amount, currency) do
            {:ok, %{^currency => from_user_balance}} ->
              case User.deposit(to_user, amount, currency) do
                {:ok, %{^currency => to_user_balance}} ->
                  {:ok, from_user_balance, to_user_balance}

                {:error, error} ->
                  # Since deposit failed, we now need to revert the original withdrawal as well
                  revert_withdrawal(from_user, amount, currency)

                  if error == :too_many_requests_to_user do
                    {:error, :too_many_requests_to_receiver}
                  else
                    {:error, error}
                  end
              end

            {:error, :too_many_requests_to_user} ->
              {:error, :too_many_requests_to_sender}

            err ->
              err
          end
      end
    else
      err ->
        {:error, :wrong_arguments}
    end
  end

  defp revert_withdrawal(user, amount, currency) do
    case User.deposit(user, amount, currency) do
      {:ok, _} ->
        :ok

      err ->
        # If reversal was unsuccessful, wait a bit and try again
        :timer.sleep(100)
        revert_withdrawal(user, amount, currency)
    end
  end
end

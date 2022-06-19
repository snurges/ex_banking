defmodule ExBankingTest do
  use ExUnit.Case, async: true

  setup context do
    Application.stop(:ex_banking)
    :ok = Application.start(:ex_banking)
  end

  # Create user
  test "creates user" do
    assert {:ok} == ExBanking.create_user("user")
    assert 1 == Registry.count(:user_registry)
  end

  test "wrong argument error when user name is not string" do
    {:error, error} = ExBanking.create_user(1)

    assert :wrong_arguments == error
  end

  test "does not allow to create another user with the same name" do
    ExBanking.create_user("user")

    {:error, error} = ExBanking.create_user("user")

    assert :user_already_exists == error
  end

  # Deposit
  test "deposits money to user when no currency exists" do
    ExBanking.create_user("user")
    ExBanking.deposit("user", 100, "EUR")

    {:ok, balance} = ExBanking.get_balance("user", "EUR")
    assert 100 == balance
  end

  test "does not allow to deposit negative amount" do
    ExBanking.create_user("user")

    {:error, error} = ExBanking.deposit("user", -100, "EUR")

    assert :wrong_arguments == error
  end

  test "does not allow to deposit when no user exists" do
    {:error, error} = ExBanking.deposit("user", 100, "EUR")

    assert :user_does_not_exist == error
  end

  test "rounds money to 2 decimal places" do
    ExBanking.create_user("user")
    ExBanking.deposit("user", 100.1234, "EUR")

    {:ok, balance} = ExBanking.get_balance("user", "EUR")

    assert balance == 100.12
  end

  test "depositing money to different currencies affect different balances" do
    ExBanking.create_user("user")

    ExBanking.deposit("user", 100, "EUR")
    ExBanking.deposit("user", 50, "eUr")

    {:ok, balanceA} = ExBanking.get_balance("user", "EUR")
    {:ok, balanceB} = ExBanking.get_balance("user", "eUr")

    assert 100 == balanceA
    assert 50 == balanceB
  end

  # Withdraw
  test "it withdraws money from user balance" do
    ExBanking.create_user("user")
    ExBanking.deposit("user", 100, "EUR")

    ExBanking.withdraw("user", 50, "EUR")

    {:ok, balance} = ExBanking.get_balance("user", "EUR")
    assert 50 == balance
  end

  test "does not allow to withdraw more than is available" do
    ExBanking.create_user("user")
    ExBanking.deposit("user", 100, "EUR")

    {:error, error} = ExBanking.withdraw("user", 150, "EUR")

    assert :not_enough_money == error
  end

  # Get balance
  test "user has 0 balance when money has not been deposited yet" do
    ExBanking.create_user("user")

    {:ok, balance} = ExBanking.get_balance("user", "EUR")

    assert 0 == balance
  end

  # Send
  test "sends money from one user to another" do
    ExBanking.create_user("from_user")
    ExBanking.create_user("to_user")
    ExBanking.deposit("from_user", 100, "EUR")

    {:ok, from_user_balance, to_user_balance} = ExBanking.send("from_user", "to_user", 70, "EUR")

    assert from_user_balance == 30
    assert to_user_balance == 70
  end

  test "does not allow to send money to user that does not exist" do
    ExBanking.create_user("from_user")
    ExBanking.deposit("from_user", 100, "EUR")

    {:error, error} = ExBanking.send("from_user", "to_user", 70, "EUR")

    assert :receiver_does_not_exist == error
  end

  test "does not allow to send money from user that does not exist" do
    ExBanking.create_user("to_user")

    {:error, error} = ExBanking.send("from_user", "to_user", 70, "EUR")

    assert :sender_does_not_exist == error
  end

  test "does not allow to send money from user that does not have enough to withdraw" do
    ExBanking.create_user("from_user")
    ExBanking.create_user("to_user")
    ExBanking.deposit("from_user", 100, "EUR")

    {:error, error} = ExBanking.send("from_user", "to_user", 101, "EUR")

    assert :not_enough_money == error
  end

  # Performance
  test "does not allow to make too many requests to user" do
    ExBanking.create_user("user")

    # Spawn many processes at once and collect their responses
    deposits =
      1..50
      |> Enum.map(fn _ -> Task.async(fn -> ExBanking.deposit("user", 100, "EUR") end) end)
      |> Enum.map(&Task.await/1)

    # Make sure that there was a process that could not be completed because there were too many requests
    assert true == Enum.member?(deposits, {:error, :too_many_requests_to_user})
  end

  test "system should handle requests for different users in the same moment of time" do
    ExBanking.create_user("user_A")
    ExBanking.create_user("user_B")
    ExBanking.create_user("user_C")

    # Spawn different requests
    tasks = [
      Task.async(fn -> ExBanking.deposit("user_A", 100, "EUR") end),
      Task.async(fn -> ExBanking.deposit("user_B", 70, "USD") end),
      Task.async(fn -> ExBanking.deposit("user_C", 50, "BTC") end)
    ]

    # Make sure tasks have completed
    Task.await_many(tasks)

    # Make sure all users have correct balances
    {:ok, user_A_balance} = ExBanking.get_balance("user_A", "EUR")
    assert 100 == user_A_balance
    {:ok, user_B_balance} = ExBanking.get_balance("user_B", "USD")
    assert 70 == user_B_balance
    {:ok, user_C_balance} = ExBanking.get_balance("user_C", "BTC")
    assert 50 == user_C_balance
  end

  test "amount of money incoming to the system should be equal to amount of money inside the system + amount of withdraws" do
      ExBanking.create_user("user_A")
      ExBanking.create_user("user_B")
      ExBanking.create_user("user_C")

      ExBanking.deposit("user_A", 10000, "EUR")
      ExBanking.deposit("user_B", 10000, "EUR")

      transfers =
        Enum.map(1..200, fn i ->
          cond do
            rem(i, 2) == 0 -> Task.async(fn -> ExBanking.send("user_A", "user_C", 100, "EUR") end)
            rem(i, 2) == 1 -> Task.async(fn -> ExBanking.send("user_B", "user_C", 100, "EUR") end)
          end
        end)
        |> Enum.map(&Task.await/1)

      {:ok, user_A_balance} = ExBanking.get_balance("user_A", "EUR")
      {:ok, user_B_balance} = ExBanking.get_balance("user_B", "EUR")
      {:ok, user_C_balance} = ExBanking.get_balance("user_C", "EUR")

      assert true == Enum.member?(transfers, {:error, :too_many_requests_to_receiver})
      assert user_A_balance + user_B_balance + user_C_balance == 20000
  end
end

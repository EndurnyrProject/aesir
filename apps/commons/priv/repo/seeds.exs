# Script for populating the database. You can run it as:
#
#     mix run apps/commons/priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Aesir.Repo.insert!(%Aesir.Commons.Models.Account{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Aesir.Commons.Auth

# Create test accounts for development
test_accounts = [
  %{
    userid: "test",
    user_pass: "test123",
    email: "test@example.com",
    sex: "M",
    group_id: 0
  },
  %{
    userid: "admin",
    user_pass: "admin123",
    email: "admin@example.com",
    sex: "M",
    group_id: 99
  },
  %{
    userid: "player1",
    user_pass: "password123",
    email: "player1@example.com",
    sex: "F",
    group_id: 0
  },
  %{
    userid: "gamemaster",
    user_pass: "gmpassword",
    email: "gm@example.com",
    sex: "M",
    group_id: 10
  }
]

IO.puts("Creating test accounts...")

Enum.each(test_accounts, fn attrs ->
  case Auth.get_account_by_userid(attrs.userid) do
    nil ->
      case Auth.create_account(attrs) do
        {:ok, account} ->
          IO.puts("✓ Created account: #{account.userid}")
        {:error, changeset} ->
          IO.puts("✗ Failed to create account #{attrs.userid}: #{inspect(changeset.errors)}")
      end

    _account ->
      IO.puts("- Account #{attrs.userid} already exists")
  end
end)

IO.puts("Seeding complete!")

defmodule Aesir.Repo.Migrations.CreateAccountsTable do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :userid, :string, null: false
      add :user_pass, :string, null: false
      add :sex, :string, size: 1, default: "M"
      add :email, :string, null: false
      add :group_id, :integer, default: 0
      add :state, :integer, default: 0
      add :unban_time, :naive_datetime
      add :expiration_time, :naive_datetime
      add :logincount, :integer, default: 0
      add :lastlogin, :naive_datetime
      add :last_ip, :string
      add :birthdate, :date
      add :character_slots, :integer, default: 9
      add :pincode, :string, size: 4
      add :pincode_change, :naive_datetime
      add :vip_time, :naive_datetime
      add :old_group, :integer, default: 0
      add :web_auth_token, :string
      add :web_auth_token_enabled, :integer, default: 0
      
      timestamps()
    end

    create unique_index(:accounts, [:userid])
    create index(:accounts, [:email])
    create index(:accounts, [:group_id])
    create index(:accounts, [:state])
  end
end

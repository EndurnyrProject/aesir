defmodule Aesir.Repo.Migrations.AddGmLevelToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :gm_level, :integer, default: 0
    end
  end
end

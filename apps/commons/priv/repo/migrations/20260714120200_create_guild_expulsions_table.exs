defmodule Aesir.Repo.Migrations.CreateGuildExpulsionsTable do
  use Ecto.Migration

  def change do
    create table(:guild_expulsions) do
      add :guild_id, :bigint, null: false
      add :char_id, :bigint, null: false
      add :name, :string, null: false
      add :account_id, :bigint, null: false
      add :reason, :string

      timestamps(updated_at: false)
    end

    create index(:guild_expulsions, [:guild_id])
  end
end

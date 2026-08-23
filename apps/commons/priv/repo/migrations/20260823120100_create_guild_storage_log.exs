defmodule Aesir.Repo.Migrations.CreateGuildStorageLog do
  use Ecto.Migration

  def change do
    create table(:guild_storage_log) do
      add :guild_id, :bigint, null: false
      add :char_id, :bigint, null: false
      add :nameid, :integer, null: false, default: 0
      add :amount, :integer, null: false
      add :refine, :smallint, null: false, default: 0
      add :card0, :integer, null: false, default: 0
      add :card1, :integer, null: false, default: 0
      add :card2, :integer, null: false, default: 0
      add :card3, :integer, null: false, default: 0
      add :unique_id, :bigint, null: false, default: 0

      timestamps(updated_at: false)
    end

    create index(:guild_storage_log, [:guild_id])
  end
end

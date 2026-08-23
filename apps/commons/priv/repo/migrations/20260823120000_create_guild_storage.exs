defmodule Aesir.Repo.Migrations.CreateGuildStorage do
  use Ecto.Migration

  def change do
    create table(:guild_storage) do
      add :guild_id, references(:guilds, on_delete: :delete_all), null: false
      add :nameid, :integer, null: false, default: 0
      add :amount, :integer, null: false, default: 0
      add :identify, :smallint, null: false, default: 0
      add :refine, :smallint, null: false, default: 0
      add :attribute, :smallint, null: false, default: 0
      add :card0, :integer, null: false, default: 0
      add :card1, :integer, null: false, default: 0
      add :card2, :integer, null: false, default: 0
      add :card3, :integer, null: false, default: 0
      add :random_options, :map, default: %{}
      add :craft, :map
      add :expire_time, :naive_datetime
      add :bound, :smallint, null: false, default: 0
      add :unique_id, :bigint, null: false, default: 0
      add :enchant_grade, :smallint, null: false, default: 0

      timestamps()
    end

    create index(:guild_storage, [:guild_id])
  end
end

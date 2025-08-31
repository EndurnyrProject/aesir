defmodule Aesir.Repo.Migrations.CreateInventoryTable do
  use Ecto.Migration

  def change do
    create table(:inventory) do
      add :char_id, references(:characters, on_delete: :delete_all), null: false
      add :nameid, :integer, null: false, default: 0
      add :amount, :integer, null: false, default: 0
      add :equip, :integer, null: false, default: 0
      add :identify, :smallint, null: false, default: 0
      add :refine, :smallint, null: false, default: 0
      add :attribute, :smallint, null: false, default: 0
      add :card0, :integer, null: false, default: 0
      add :card1, :integer, null: false, default: 0
      add :card2, :integer, null: false, default: 0
      add :card3, :integer, null: false, default: 0

      # Random options - using JSON for cleaner schema
      add :random_options, :map, default: %{}

      add :expire_time, :naive_datetime
      add :favorite, :smallint, null: false, default: 0
      add :bound, :smallint, null: false, default: 0
      add :unique_id, :bigint, null: false, default: 0
      add :equip_switch, :integer, null: false, default: 0
      add :enchant_grade, :smallint, null: false, default: 0

      timestamps()
    end

    create index(:inventory, [:char_id])
    create index(:inventory, [:unique_id])
    create index(:inventory, [:nameid])
  end
end

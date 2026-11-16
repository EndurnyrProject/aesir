defmodule Aesir.Repo.Migrations.CreatePets do
  use Ecto.Migration

  def change do
    create table(:pets) do
      add :class, :integer, null: false
      add :name, :string, size: 24, null: false
      add :account_id, :integer, null: false
      add :char_id, :integer, null: false
      add :level, :integer, null: false
      add :egg_id, :integer, null: false
      add :equip, :integer, default: 0, null: false
      add :intimate, :integer, null: false
      add :hungry, :integer, null: false
      add :rename_flag, :integer, default: 0, null: false
      add :incubate, :integer, default: 1, null: false
      add :autofeed, :boolean, default: false, null: false
      timestamps()
    end

    create index(:pets, [:char_id])
  end
end

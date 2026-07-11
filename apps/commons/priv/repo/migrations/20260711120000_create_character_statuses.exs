defmodule Aesir.Repo.Migrations.CreateCharacterStatuses do
  use Ecto.Migration

  def change do
    create table(:character_statuses) do
      add :char_id, references(:characters, on_delete: :delete_all), null: false
      add :status_type, :string, null: false
      add :val1, :integer, null: false, default: 0
      add :val2, :integer, null: false, default: 0
      add :val3, :integer, null: false, default: 0
      add :val4, :integer, null: false, default: 0
      add :tick, :integer, null: false, default: 0
      add :flag, :integer, null: false, default: 0
      add :source_id, :bigint
      add :remaining_ms, :bigint

      timestamps()
    end

    create unique_index(:character_statuses, [:char_id, :status_type])
  end
end

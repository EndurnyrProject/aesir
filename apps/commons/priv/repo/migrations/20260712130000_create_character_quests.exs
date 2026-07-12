defmodule Aesir.Repo.Migrations.CreateCharacterQuests do
  use Ecto.Migration

  def change do
    create table(:character_quests) do
      add :char_id, references(:characters, on_delete: :delete_all), null: false
      add :quest_id, :integer, null: false
      add :state, :string, null: false, default: "active"
      add :count1, :integer, null: false, default: 0
      add :count2, :integer, null: false, default: 0
      add :count3, :integer, null: false, default: 0
      add :deadline, :utc_datetime

      timestamps()
    end

    create unique_index(:character_quests, [:char_id, :quest_id])
  end
end

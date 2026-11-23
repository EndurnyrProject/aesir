defmodule Aesir.Repo.Migrations.AddGiverToCharacterQuests do
  use Ecto.Migration

  def change do
    alter table(:character_quests) do
      add :giver_name, :string
      add :giver_map, :string
      add :giver_x, :integer
      add :giver_y, :integer
    end
  end
end

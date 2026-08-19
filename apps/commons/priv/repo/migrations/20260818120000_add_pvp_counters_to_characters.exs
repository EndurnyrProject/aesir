defmodule Aesir.Repo.Migrations.AddPvpCountersToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :pvp_point, :integer, null: false, default: 0
      add :pvp_won, :integer, null: false, default: 0
      add :pvp_lost, :integer, null: false, default: 0
    end
  end
end

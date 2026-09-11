defmodule Aesir.Repo.Migrations.AddGuildCastleInvestments do
  use Ecto.Migration

  def change do
    alter table(:guild_castles) do
      add :invested_economy, :integer, null: false, default: 0
      add :invested_defense, :integer, null: false, default: 0
    end
  end
end

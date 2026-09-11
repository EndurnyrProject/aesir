defmodule Aesir.Repo.Migrations.AddGuildCastleGuardians do
  use Ecto.Migration

  def change do
    alter table(:guild_castles) do
      add :guardians, {:array, :integer}, null: false, default: []
    end
  end
end

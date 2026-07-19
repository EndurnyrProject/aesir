defmodule Aesir.Repo.Migrations.CreateBossRespawns do
  use Ecto.Migration

  def change do
    create table(:boss_respawns) do
      add :map_name, :string, null: false
      add :mob_id, :integer, null: false
      add :respawn_at, :utc_datetime, null: false

      timestamps(updated_at: false)
    end

    create index(:boss_respawns, [:map_name])
  end
end

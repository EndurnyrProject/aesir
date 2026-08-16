defmodule Aesir.Repo.Migrations.CreateGuildCastles do
  use Ecto.Migration

  def change do
    create table(:guild_castles) do
      add :castle_id, :integer, null: false
      add :guild_id, :integer
      add :economy, :integer, null: false, default: 0
      add :defense, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:guild_castles, [:castle_id])

    execute(
      """
      INSERT INTO guild_castles (castle_id, guild_id, economy, defense, inserted_at, updated_at)
      SELECT g, NULL, 0, 0, localtimestamp, localtimestamp
      FROM generate_series(0, 19) AS g
      """,
      "DELETE FROM guild_castles WHERE castle_id BETWEEN 0 AND 19"
    )
  end
end

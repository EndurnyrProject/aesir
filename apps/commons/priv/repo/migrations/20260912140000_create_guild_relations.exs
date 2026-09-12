defmodule Aesir.Repo.Migrations.CreateGuildRelations do
  use Ecto.Migration

  def change do
    create table(:guild_relations) do
      add :guild_id, references(:guilds, on_delete: :delete_all), null: false
      add :other_guild_id, references(:guilds, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :other_name, :string, null: false

      timestamps(updated_at: false)
    end

    create unique_index(:guild_relations, [:guild_id, :other_guild_id])
    create index(:guild_relations, [:other_guild_id])
  end
end

defmodule Aesir.Repo.Migrations.CreateGuildActivityLog do
  use Ecto.Migration

  def change do
    create table(:guild_activity_log) do
      add :guild_id, references(:guilds, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :subject, :string, null: false, default: ""
      add :actor, :string, null: false, default: ""
      add :detail, :string, null: false, default: ""
      add :skill_id, :integer, null: false, default: 0
      add :level, :integer, null: false, default: 0

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:guild_activity_log, [:guild_id])
  end
end

defmodule Aesir.Repo.Migrations.AddGuildProgression do
  use Ecto.Migration

  def change do
    alter table(:guilds) do
      add :level, :integer, null: false, default: 1
      add :exp, :bigint, null: false, default: 0
      add :skill_points, :integer, null: false, default: 0
      add :learned_skills, :map, null: false, default: %{}
    end
  end
end

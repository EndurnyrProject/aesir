defmodule Aesir.Repo.Migrations.AddLearnedSkillsToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :learned_skills, :map, default: %{}
    end
  end
end

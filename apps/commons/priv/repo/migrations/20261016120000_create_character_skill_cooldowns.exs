defmodule Aesir.Repo.Migrations.CreateCharacterSkillCooldowns do
  use Ecto.Migration

  def change do
    create table(:character_skill_cooldowns, primary_key: false) do
      add :char_id, references(:characters, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :skill_id, :integer, null: false, primary_key: true
      add :remaining_ms, :bigint, null: false
    end
  end
end

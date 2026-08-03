defmodule Aesir.Repo.Migrations.CreateHomunculi do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      remove :homun_id, :integer, default: 0
    end

    create table(:homunculi) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :class_id, :integer, null: false
      add :name, :string, null: false
      add :rename_available, :boolean, default: true, null: false
      add :lifecycle, :string, default: "active", null: false
      add :level, :integer, default: 1, null: false
      add :exp, :bigint, default: 0, null: false
      add :skill_points, :integer, default: 0, null: false
      add :hp, :bigint, default: 0, null: false
      add :max_hp, :bigint, default: 0, null: false
      add :sp, :bigint, default: 0, null: false
      add :max_sp, :bigint, default: 0, null: false
      add :str, :integer, default: 0, null: false
      add :agi, :integer, default: 0, null: false
      add :vit, :integer, default: 0, null: false
      add :int, :integer, default: 0, null: false
      add :dex, :integer, default: 0, null: false
      add :luk, :integer, default: 0, null: false
      add :hunger, :integer, default: 32, null: false
      add :intimacy_hundredths, :integer, default: 2100, null: false
      add :active_remaining_ms, :bigint, default: 1_800_000, null: false
      add :learned_skills, :map, default: %{}, null: false
      add :cooldowns, :map, default: %{}, null: false
      add :ai_config, :map, default: %{}, null: false

      timestamps()
    end

    create unique_index(:homunculi, [:character_id])

    create constraint(:homunculi, :homunculi_lifecycle_check,
             check: "lifecycle IN ('active', 'rested', 'dead')"
           )

    create constraint(:homunculi, :homunculi_level_check, check: "level BETWEEN 1 AND 99")
    create constraint(:homunculi, :homunculi_hunger_check, check: "hunger BETWEEN 0 AND 100")

    create constraint(:homunculi, :homunculi_intimacy_hundredths_check,
             check: "intimacy_hundredths BETWEEN 0 AND 100000"
           )

    create constraint(:homunculi, :homunculi_resources_non_negative,
             check:
               "exp >= 0 AND skill_points >= 0 AND hp >= 0 AND max_hp >= 0 AND sp >= 0 AND max_sp >= 0 AND active_remaining_ms >= 0"
           )

    create constraint(:homunculi, :homunculi_learned_skills_is_object,
             check:
               "jsonb_typeof(learned_skills) = 'object' AND jsonb_array_length(jsonb_path_query_array(learned_skills, '$.*')) <= 64"
           )

    create constraint(:homunculi, :homunculi_cooldowns_is_object,
             check:
               "jsonb_typeof(cooldowns) = 'object' AND jsonb_array_length(jsonb_path_query_array(cooldowns, '$.*')) <= 64"
           )

    create constraint(:homunculi, :homunculi_ai_config_is_object,
             check:
               "jsonb_typeof(ai_config) = 'object' AND jsonb_array_length(jsonb_path_query_array(ai_config, '$.*')) <= 64"
           )
  end
end

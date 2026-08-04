defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HfliSbr44 do
  @moduledoc "S.B.R.44, Filir's intimacy-powered evolved physical attack."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8012,
    name: :hfli_sbr44,
    display_name: "S.B.R.44",
    max_level: 3,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 15,
    sp_cost: List.duplicate(1, 3),
    cooldown: List.duplicate(1_000, 3)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active
  @minimum_intimacy 400

  @impl Active
  def validate(%{intimacy_hundredths: intimacy}, _target, _level, _definition)
      when intimacy >= @minimum_intimacy,
      do: :ok

  def validate(_caster, _target, _level, _definition), do: {:error, :insufficient_intimacy}

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    intimacy = caster.intimacy_hundredths

    case Combat.prepare_staged_skill_attack(caster, target,
           skill_id: definition.id,
           skill_level: level,
           base_damage: intimacy,
           skill_ratio: 100 * level,
           skip_range: true,
           skip_crit: true
         ) do
      {:ok, :miss} ->
        {:ok, caster}

      {:ok, prepared_hit} ->
        {:local_effects, %{caster | intimacy_hundredths: 100},
         [
           {:prepared_external_hit, prepared_hit}
         ]}

      {:error, _reason} = error ->
        error
    end
  end
end

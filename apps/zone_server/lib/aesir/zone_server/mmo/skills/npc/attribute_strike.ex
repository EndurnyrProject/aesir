defmodule Aesir.ZoneServer.Mmo.Skills.Npc.AttributeStrike do
  @moduledoc """
  Shared `cast/4` body for the monster attribute attacks (`NPC_FIREATTACK`,
  `NPC_WATERATTACK`, `NPC_WINDATTACK`, `NPC_GROUNDATTACK`, `NPC_POISONATTACK`,
  `NPC_HOLYATTACK`, `NPC_DARKNESSATTACK`, `NPC_TELEKINESISATTACK`,
  `NPC_UNDEADATTACK`): a single weapon
  hit in the skill's element at `100 * level` percent ATK with a 20% hit-rate
  bonus. Identical in both modes.

  Many mob rows select these from `chase`/`angry` state while the target is
  still outside the mob's melee `attack_range` (only within `skill_range`), so a
  monster caster's attack range is widened to `max(attack_range, skill_range)`.
  """

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Ref

  @spec cast(struct(), integer() | Ref.t(), pos_integer(), struct()) ::
          {:ok, struct()} | {:error, atom()}
  def cast(caster, target_id, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 * level,
      element: definition.element,
      hit_rate_bonus_pct: 20
    ]

    case Combat.execute_skill_attack(widen_range(caster), target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp widen_range(%MobState{mob_data: mob_data} = caster) do
    %{
      caster
      | mob_data: %{mob_data | attack_range: max(mob_data.attack_range, mob_data.skill_range)}
    }
  end

  defp widen_range(caster), do: caster
end

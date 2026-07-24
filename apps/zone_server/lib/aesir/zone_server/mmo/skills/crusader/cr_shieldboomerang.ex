defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldboomerang do
  @moduledoc """
  Shield Boomerang (CR_SHIELDBOOMERANG). Single-target shield throw that
  reaches well past melee range, dealing damage on the shield base
  (`batk + 4 * refine + shield_weight / 10`) instead of the weapon.

  Single-hit shield damage at `80 * level`%. The skill's own reach grows with
  level (3/5/7/9/11 cells), declared as a per-level `range` list so the
  interpreter's own built-in range gate enforces the correct cell count for
  the cast level directly; `skip_range: true` is passed to the attack so the
  combat layer's own distance check - which gates on the caster's *melee*
  weapon range - does not reject a throw beyond it, mirroring Spear Boomerang.
  `ranged: true` forces the renewal ranged-physical classification (`is_short:
  false`) on the delivered hit, so long-range reductions such as Defender
  apply to it.

  A player must have a shield equipped to cast it at all; a mob casting it has
  no equipment, so it falls back to the plain weapon/batk damage base.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 251,
    name: :cr_shieldboomerang,
    display_name: "Shield Boomerang",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_base: :shield,
    range: [3, 5, 7, 9, 11],
    sp_cost: List.duplicate(12, 5),
    after_cast_delay: List.duplicate(700, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(caster, _target, _level, _definition), do: check_shield(caster)

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 80 * level,
      damage_base: :shield,
      skip_crit: true,
      skip_range: true,
      ranged: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  @spec check_shield(Active.caster()) :: :ok | {:error, :requires_shield}
  defp check_shield(%PlayerState{stats: %{equipment: equipment}}) do
    PlayerStats.validate_shield(equipment)
  end

  defp check_shield(_caster), do: :ok
end

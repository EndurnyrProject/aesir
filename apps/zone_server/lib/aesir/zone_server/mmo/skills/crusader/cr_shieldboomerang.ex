defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldboomerang do
  @moduledoc """
  Shield Boomerang (CR_SHIELDBOOMERANG). Throws the shield at 3 to 11 cells by
  level for 12 SP with a 0.7 s delay, dealing neutral ranged damage on the shield
  base (attack plus 4 per refine plus the shield's weight) instead of the weapon.
  A player needs a shield; a mob caster falls back to the plain attack base. The
  interpreter enforces the per-level reach and the attack skips the melee range
  check; the hit counts as ranged so Defending Aura reduces it.

  Renewal: 80% per level. Pre-renewal: 100% plus 30% per level, with the target's
  DEF applied before the ratio in the source (not modelled here).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 251,
    name: :cr_shieldboomerang,
    requires: [],
    display_name: "Shield Boomerang",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_base: :shield,
    range: [3, 5, 7, 9, 11],
    sp_cost: List.duplicate(12, 5),
    after_cast_delay: List.duplicate(700, 5)

  alias Aesir.Commons.GameMode
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
      skill_ratio: skill_ratio(level),
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

  @doc "Renewal throws at 80% per level; pre-renewal at 100% plus 30% per level."
  @spec skill_ratio(pos_integer()) :: pos_integer()
  def skill_ratio(level) do
    case GameMode.mode() do
      :renewal -> 80 * level
      :pre_renewal -> 100 + 30 * level
    end
  end

  @spec check_shield(Active.caster()) :: :ok | {:error, :requires_shield}
  defp check_shield(%PlayerState{stats: %{equipment: equipment}}) do
    PlayerStats.validate_shield(equipment)
  end

  defp check_shield(_caster), do: :ok
end

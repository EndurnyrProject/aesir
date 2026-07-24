defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrSpearquicken do
  @moduledoc """
  Spear Quicken (CR_SPEARQUICKEN). Self-casts SC_SPEARQUICKEN, the flat
  ASPD/FLEE/CRIT buff that only holds while a spear is wielded (see
  `StatusEffect.Effects.SpearQuicken`'s `require_weapon` list).

  A player caster must have a one-handed or two-handed spear equipped; a mob
  caster skips the check entirely, mirroring `kn_twohandquicken.ex`'s
  weapon-gated self-buff pattern.

  Always buffs the caster: a stray mob-skill row records this self-buff as
  `target: target` rather than `target: self`, which resolves to a `{:unit,
  id}` target instead of `:self` - `cast/4` treats both target shapes the
  same rather than buffing whatever that id happens to be.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 258,
    name: :cr_spearquicken,
    status: :sc_spearquicken,
    display_name: "Spear Quicken",
    max_level: 10,
    target_type: :self,
    sp_cost: [24, 28, 32, 36, 40, 44, 48, 52, 56, 60],
    duration: [
      30_000,
      60_000,
      90_000,
      120_000,
      150_000,
      180_000,
      210_000,
      240_000,
      270_000,
      300_000
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @fixed_aspd 7
  @spear_weapon_types [:one_handed_spear, :two_handed_spear]

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :requires_spear}
  def validate(%PlayerState{} = caster, _target, _level, _definition) do
    if PlayerStats.weapon_type(caster.stats.equipment) in @spear_weapon_types do
      :ok
    else
      {:error, :requires_spear}
    end
  end

  def validate(%MobState{}, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, :self, level, definition), do: apply_buff(caster, level, definition)
  def cast(caster, {:unit, _id}, level, definition), do: apply_buff(caster, level, definition)

  @spec apply_buff(Active.caster(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  defp apply_buff(caster, level, definition) do
    unit_type = caster.__struct__.get_unit_type(caster)
    unit_id = caster.__struct__.get_unit_id(caster)
    duration = Enum.at(definition.duration, level - 1)
    params = [val1: level, val2: @fixed_aspd, caster_id: unit_id, duration: duration]

    case StatusInterpreter.apply_status(unit_type, unit_id, :sc_spearquicken, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end

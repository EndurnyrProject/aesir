defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnTwohandquicken do
  @moduledoc """
  Two-Hand Quicken (KN_TWOHANDQUICKEN). Self-casts SC_TWOHANDQUICKEN, the flat
  ASPD/HIT/CRIT buff that only holds while a two-handed sword is wielded (see
  `StatusEffect.Effects.TwoHandQuicken`'s `require_weapon` list).

  A player caster must have a two-handed sword equipped; a mob caster skips
  the check entirely, mirroring the other weapon-gated skills that keep the
  gate on the player validation path only.

  Always buffs the caster: a stray mob-skill row records this self-buff as
  `target: target` rather than `target: self`, which resolves to a `{:unit,
  id}` target instead of `:self` - `cast/4` treats both target shapes the
  same rather than buffing whatever that id happens to be.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 60,
    name: :kn_twohandquicken,
    status: :sc_twohandquicken,
    display_name: "Two-Hand Quicken",
    max_level: 10,
    target_type: :self,
    sp_cost: [14, 18, 22, 26, 30, 34, 38, 42, 46, 50],
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

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :wrong_weapon}
  def validate(%PlayerState{} = caster, _target, _level, _definition) do
    if PlayerStats.weapon_type(caster.stats.equipment) == :two_handed_sword do
      :ok
    else
      {:error, :wrong_weapon}
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

    case StatusInterpreter.apply_status(unit_type, unit_id, :sc_twohandquicken, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end

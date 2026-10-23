defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrSpearquicken do
  @moduledoc """
  Spear Quicken (CR_SPEARQUICKEN). A self buff for 24 to 60 SP lasting 30 s per
  level that only holds while a spear is wielded; a mob caster skips the weapon
  check. A mob-skill row may target the caster by id; either shape buffs the caster.

  Renewal: any spear; a flat +7 attack speed, +2 FLEE and +3 CRIT per level.
  Pre-renewal: two-handed spears only; a 20 plus 1 per level percent attack speed
  rate and nothing else.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 258,
    name: :cr_spearquicken,
    status: :sc_spearquicken,
    display_name: "Spear Quicken",
    max_level: 10,
    target_type: :self,
    require_weapon: [
      renewal: [:one_handed_spear, :two_handed_spear],
      pre_renewal: [:two_handed_spear]
    ],
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

  @behaviour Active

  @fixed_aspd 7

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

    StatusInterpreter.apply_status(unit_type, unit_id, :sc_spearquicken, params)
    {:ok, caster}
  end
end

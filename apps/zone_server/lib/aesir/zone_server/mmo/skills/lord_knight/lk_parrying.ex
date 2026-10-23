defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkParrying do
  @moduledoc """
  Parrying (LK_PARRYING) grants a two-handed-sword weapon-block stance.

  Both Renewal and pre-renewal grant the same per-level block chance and
  15–60 second duration. The status ends when the sword is removed.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 356,
    name: :lk_parrying,
    display_name: "Parrying",
    max_level: 10,
    target_type: :self,
    status: :sc_parrying,
    require_weapon: [:two_handed_sword],
    sp_cost: List.duplicate(50, 10),
    duration: [
      15_000,
      20_000,
      25_000,
      30_000,
      35_000,
      40_000,
      45_000,
      50_000,
      55_000,
      60_000
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, :self, level, definition), do: apply_buff(caster, level, definition)
  def cast(caster, {:unit, _id}, level, definition), do: apply_buff(caster, level, definition)

  defp apply_buff(caster, level, definition) do
    type = caster.__struct__.get_unit_type(caster)
    id = caster.__struct__.get_unit_id(caster)

    Interpreter.apply_status(type, id, :sc_parrying,
      val1: level,
      duration: Enum.at(definition.duration, level - 1),
      caster_id: id
    )

    {:ok, caster}
  end
end

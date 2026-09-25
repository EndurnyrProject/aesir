defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkConcentration do
  @moduledoc """
  Concentration (LK_CONCENTRATION) grants an ATK/HIT buff with reduced DEF.

  Renewal level five lasts 60 seconds, while pre-renewal level five lasts
  45 seconds; lower levels share the same duration table in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 357,
    name: :lk_concentration,
    display_name: "Concentration",
    max_level: 5,
    target_type: :self,
    status: :sc_concentration,
    sp_cost: [14, 18, 22, 26, 30],
    duration: [
      renewal: [25_000, 30_000, 35_000, 40_000, 60_000],
      pre_renewal: [25_000, 30_000, 35_000, 40_000, 45_000]
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

    case Interpreter.apply_status(type, id, :sc_concentration,
           val1: level,
           duration: Enum.at(definition.duration, level - 1),
           caster_id: id
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end

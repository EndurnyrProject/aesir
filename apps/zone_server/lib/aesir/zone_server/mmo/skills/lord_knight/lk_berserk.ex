defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkBerserk do
  @moduledoc """
  Berserk (LK_BERSERK) applies the five-minute self-buff in both Renewal and
  pre-renewal. The status handles the mode-specific ATK and ASPD bonuses,
  healing, action restrictions, HP drain and expiry penalty.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 359,
    name: :lk_berserk,
    display_name: "Berserk",
    max_level: 1,
    target_type: :self,
    status: :sc_berserk,
    sp_cost: [200],
    duration: [300_000]

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

    case Interpreter.apply_status(type, id, :sc_berserk,
           val1: level,
           duration: Enum.at(definition.duration, level - 1),
           caster_id: id
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end

defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkTensionrelax do
  @moduledoc """
  Tension Relax (LK_TENSIONRELAX) applies a 180-second healing stance and
  seats the player in their owning session. Renewal and pre-renewal share the
  same SP cost and duration; no mode-specific behaviour is omitted.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 358,
    name: :lk_tensionrelax,
    display_name: "Tension Relax",
    max_level: 1,
    target_type: :self,
    status: :sc_tensionrelax,
    sp_cost: [15],
    duration: [180_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, :self, level, definition), do: apply_buff(caster, level, definition)
  def cast(caster, {:unit, _id}, level, definition), do: apply_buff(caster, level, definition)

  defp apply_buff(caster, level, definition) do
    type = caster.__struct__.get_unit_type(caster)
    id = caster.__struct__.get_unit_id(caster)

    case Interpreter.apply_status(type, id, :sc_tensionrelax,
           val1: level,
           duration: Enum.at(definition.duration, level - 1),
           caster_id: id
         ) do
      :ok ->
        if match?(%PlayerState{}, caster), do: PlayerSession.sit(self())
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end
end

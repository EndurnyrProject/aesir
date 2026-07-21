defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoExplosionspirits do
  @moduledoc """
  Fury (MO_EXPLOSIONSPIRITS), a self-buff that grants critical rate for 180 seconds.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 270,
    name: :mo_explosionspirits,
    status: :sc_explosionspirits,
    display_name: "Fury",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(15, 5),
    sphere_cost: List.duplicate(5, 5),
    duration: List.duplicate(180_000, 5)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = [
      val1: level,
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    ]

    with :ok <- StatusInterpreter.apply_status(:player, caster_id, :sc_explosionspirits, params) do
      {:ok, caster}
    end
  end
end

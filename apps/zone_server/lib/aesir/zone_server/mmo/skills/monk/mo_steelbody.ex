defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoSteelbody do
  @moduledoc """
  Mental Strength (MO_STEELBODY), a self-buff that greatly reduces incoming damage.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 268,
    name: :mo_steelbody,
    status: :sc_steelbody,
    display_name: "Mental Strength",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(200, 5),
    sphere_cost: List.duplicate(5, 5),
    cast_time: List.duplicate(2_500, 5),
    fixed_cast_time: List.duplicate(2_500, 5),
    duration: [30_000, 60_000, 90_000, 120_000, 150_000]

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

    with :ok <- StatusInterpreter.apply_status(:player, caster_id, :sc_steelbody, params) do
      {:ok, caster}
    end
  end
end

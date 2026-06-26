defmodule Aesir.ZoneServer.Mmo.Skills.AlDecagi do
  @moduledoc """
  Decrease AGI (AL_DECAGI). Applies SC_DECREASEAGI to an enemy on a successful landing roll.

  rAthena renewal: magic, single target enemy, range 9, no damage. SP is consumed whether
  the landing roll succeeds or not (deducted by the cast interpreter after `cast/4` returns).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 30,
    name: :al_decagi,
    display_name: "Decrease AGI",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 9,
    sp_cost: [15, 17, 19, 21, 23, 25, 27, 29, 31, 33],
    cast_time: List.duplicate(750, 10),
    fixed_cast_time: List.duplicate(250, 10),
    after_cast_delay: List.duplicate(1_000, 10),
    duration: [
      40_000,
      50_000,
      60_000,
      70_000,
      80_000,
      90_000,
      100_000,
      110_000,
      120_000,
      130_000
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    %{base_level: base_level, int: caster_int} = PlayerState.get_stats(caster)
    rate = 50 + 3 * level + div(base_level + caster_int, 5)

    if :rand.uniform(100) <= rate do
      unit_type = target_unit_type(target_id)
      duration = Enum.at(definition.duration, level - 1)

      StatusInterpreter.apply_status(unit_type, target_id, :sc_decreaseagi,
        val1: level,
        caster_id: caster_id,
        duration: duration
      )
    end

    {:ok, caster}
  end

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end

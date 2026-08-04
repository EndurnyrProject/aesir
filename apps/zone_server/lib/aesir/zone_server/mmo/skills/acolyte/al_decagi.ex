defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDecagi do
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
  def cast(caster, {:unit, target}, level, definition) do
    %{base_level: base_level, int: caster_int} = caster_stats(caster)
    {source_type, source_id} = source_ref(caster)
    rate = 50 + 3 * level + div(base_level + caster_int, 5)

    if :rand.uniform(100) <= rate do
      {unit_type, unit_id} = target_ref(target)
      duration = Enum.at(definition.duration, min(level, length(definition.duration)) - 1)

      StatusInterpreter.apply_status(unit_type, unit_id, :sc_decreaseagi,
        val1: level,
        caster_id: source_id,
        source_type: source_type,
        duration: duration
      )
    end

    {:ok, caster}
  end

  defp caster_stats(%{character_id: _} = caster), do: PlayerState.get_stats(caster)

  defp caster_stats(caster) do
    combatant = caster.__struct__.to_combatant(caster)
    %{base_level: combatant.progression.base_level, int: combatant.base_stats.int}
  end

  defp source_ref(%{character_id: unit_id}), do: {:player, unit_id}
  defp source_ref(%{instance_id: unit_id}), do: {:mob, unit_id}

  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end

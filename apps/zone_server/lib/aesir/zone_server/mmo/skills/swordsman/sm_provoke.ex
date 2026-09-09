defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmProvoke do
  @moduledoc """
  Provoke (SM_PROVOKE). Taunts a single enemy for 30 seconds at range 9.

  Renewal: the taunt raises the victim's physical attack by `2 + 3 * level`
  percent and lowers its defense by `5 + 5 * level` percent, and the caster may
  re-cast it as fast as the aftercast delay allows - renewal carries no
  cooldown on it.

  Pre-renewal: the same attack and defense percentages and the same 30 second
  duration, but the skill is on a one second cooldown, so a caster cannot chain
  it faster than once per second.

  In both modes the taunt is refused outright against undead and status-immune
  targets (declared on the status itself), and otherwise has to pass a roll of
  `70 + 3 * level + caster base level - target base level` percent. A failed
  roll still completes the cast and still costs the caster SP; it simply leaves
  the target untaunted.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 6,
    name: :sm_provoke,
    requires: [],
    display_name: "Provoke",
    max_level: 10,
    target_type: :target_enemy,
    range: 9,
    sp_cost: [4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    cooldown: [renewal: [], pre_renewal: List.duplicate(1_000, 10)],
    duration: List.duplicate(30_000, 10)

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    caster_id = Caster.for(caster).id(caster)
    duration = Enum.at(definition.duration, level - 1)

    params = [
      val1: level,
      val2: 2 + 3 * level,
      val3: 5 + 5 * level,
      caster_id: caster_id,
      duration: duration
    ]

    with {:ok, _pid, target, unit_type} <- TargetResolver.resolve(target_id),
         true <- lands?(caster, target, level),
         :ok <- StatusInterpreter.apply_status(unit_type, target_id, :sc_provoke, params) do
      {:ok, caster}
    else
      false -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  # The taunt has to out-roll the level gap between caster and victim: a caster
  # far above its target effectively never misses, one far below effectively
  # never lands. A unit carrying no readable level skips the roll rather than
  # silently losing the taunt.
  defp lands?(caster, target, level) do
    case {base_level(caster), base_level(target)} do
      {caster_level, target_level}
      when is_integer(caster_level) and is_integer(target_level) ->
        :rand.uniform(100) <= 70 + 3 * level + caster_level - target_level

      _level_unknown ->
        true
    end
  end

  defp base_level(%PlayerState{stats: %{progression: %{base_level: level}}}), do: level
  defp base_level(%MobState{mob_data: %{level: level}}), do: level
  defp base_level(_unit), do: nil
end

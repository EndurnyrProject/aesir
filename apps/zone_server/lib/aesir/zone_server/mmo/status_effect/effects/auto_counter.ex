defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AutoCounter do
  @moduledoc """
  Auto Counter (SC_AUTOCOUNTER).

  A single-use counter stance armed on a Knight by KN_AUTOCOUNTER, carrying the
  skill level in `val1`. The next basic melee weapon attack that lands from the
  holder's front or side arc, within the holder's own weapon range, is caught by
  `before_weapon_hit/4`: the incoming swing is intercepted (deals nothing), the
  stance is consumed, and the holder answers with a guaranteed critical weapon
  strike at `100 + 10 * level` percent against the attacker.

  Trigger conditions, matching the Renewal source:

  - The incoming attack must be a basic **melee** weapon swing. Ranged basic
    attacks never trigger it, and skill attacks never reach this hook (only the
    basic-attack path dispatches `before_weapon_hit`).
  - The attacker must be at the same cell (distance `<= 0`), or in the holder's
    front/side arc (its direction from the holder differs from the holder's
    facing by at most two 45-degree steps) and no farther than the holder's
    weapon range plus one cell.

  The interception runs inside the attacker's own combat pipeline, so the counter
  strike's damage write (onto that same attacker) stays in-process. Consuming the
  stance is a synchronous atomic `StatusStorage.take_status/3` on the holder's
  row, the same sanctioned single-use claim Blade Stop and Lex Aeterna use; a
  lost race leaves the stance intact and the swing resolves normally. There is no
  cross-session handshake.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_auto_counter,
    no_dispel: false,
    no_save: true,
    properties: [:buff]

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit

  # KN_AUTOCOUNTER skill id, used only to tag the counter strike's damage packet.
  @skill_id 61
  # The attacker counts as "in front" when its direction from the holder is no
  # more than this many 45-degree dir-steps off the holder's facing (a spread of
  # up to 90 degrees to either side); a wider spread is a rear-arc hit.
  @front_arc_dir_steps 2

  @impl true
  @spec before_weapon_hit(
          {Unit.unit_type(), integer()},
          StatusEntry.t(),
          map(),
          map()
        ) :: :continue | {:intercept, :auto_counter}
  def before_weapon_hit({unit_type, unit_id}, _instance, attack_info, _context) do
    with true <- melee_basic_attack?(attack_info),
         {:ok, defender_state} <- resolve_defender(unit_id),
         true <- within_counter_arc?(defender_state, attack_info),
         %StatusEntry{val1: level} <-
           StatusStorage.take_status(unit_type, unit_id, :sc_auto_counter) do
      counter(defender_state, attack_info, level)
    else
      _ -> :continue
    end
  end

  defp melee_basic_attack?(%{attacker_short?: true}), do: true
  defp melee_basic_attack?(_attack_info), do: false

  defp resolve_defender(unit_id) do
    case TargetResolver.resolve(unit_id) do
      {:ok, _pid, state, _type} -> {:ok, state}
      _ -> :error
    end
  end

  defp within_counter_arc?(defender_state, attack_info) do
    distance = Map.get(attack_info, :distance, 0)

    distance <= 0 or
      (in_front_arc?(defender_state, attack_info) and
         distance <= defender_weapon_range(defender_state) + 1)
  end

  defp in_front_arc?(%{x: dx, y: dy, dir: dir}, %{attacker_position: {ax, ay}})
       when dir in 0..7 do
    dir_to_attacker = Geometry.calculate_direction(dx, dy, ax, ay)
    Geometry.direction_difference(dir_to_attacker, dir) <= @front_arc_dir_steps
  end

  defp in_front_arc?(_defender_state, _attack_info), do: false

  defp defender_weapon_range(defender_state) do
    defender_state.__struct__.to_combatant(defender_state).attack_range
  end

  defp counter(defender_state, %{attacker: {_type, attacker_id}}, level) do
    Combat.execute_skill_attack(defender_state, attacker_id,
      skill_id: @skill_id,
      skill_level: level,
      skill_ratio: 100 + 10 * level,
      force_crit: true,
      skip_range: true
    )

    {:intercept, :auto_counter}
  end
end

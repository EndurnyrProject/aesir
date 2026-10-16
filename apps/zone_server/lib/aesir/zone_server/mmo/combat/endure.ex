defmodule Aesir.ZoneServer.Mmo.Combat.Endure do
  @moduledoc """
  Whether damage can stop a unit walking.

  A hit that deals damage stops a walking unit (`Aesir.ZoneServer.Unit.HitStop`)
  unless the unit endures it. A unit endures while any of these holds:

    * it is a player with the no-walk-delay bonus (equipment or Spark Candy), on
      a map where Endure is allowed;
    * its own endure time (`put_tick/3`) has not passed yet;
    * it holds the Endure status.

  The damage packet reads the shown form (`shown?/2`); stopping reads the full
  form, which in renewal also lets a boss-class monster keep walking without
  showing endure. A hit reads the endure time where it is dealt
  (`tick_active?/3`), before the attack's own effects may set it, and the rest
  (`holds?/4`) in the target's own process, after the hit reached its statuses.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Whether the unit `{unit_type, unit_id}`, whose current state is `unit_state`,
  endures damage at `now` (monotonic milliseconds). `visible?` asks for the form
  the damage packet shows, which leaves out the renewal boss rule.
  """
  @spec endure?(atom(), integer(), struct() | nil, boolean(), integer()) :: boolean()
  def endure?(unit_type, unit_id, unit_state, visible?, now \\ now()) do
    tick_active?(unit_type, unit_id, now) or holds?(unit_type, unit_id, unit_state, visible?)
  end

  @doc """
  The part of `endure?/5` the unit holds itself: the no-walk-delay bonus, the
  Endure status and, in the unshown form, the renewal boss rule.
  """
  @spec holds?(atom(), integer(), struct() | nil, boolean()) :: boolean()
  def holds?(unit_type, unit_id, unit_state, visible?) do
    no_walk_delay?(unit_state) or StatusStorage.has_status?(unit_type, unit_id, :sc_endure) or
      (not visible? and renewal_boss?(unit_state))
  end

  @doc "Whether the unit's own endure time (`put_tick/4`) is still running at `now`."
  @spec tick_active?(atom(), integer(), integer()) :: boolean()
  def tick_active?(unit_type, unit_id, now \\ now()) do
    case StatusStorage.endure_tick(unit_type, unit_id) do
      until when is_integer(until) -> until - now > 0
      nil -> false
    end
  end

  @doc """
  The shown form of `endure?/5` for a unit known by reference, read from its
  registered state, as the damage packet built in the attacker's process sees it.
  """
  @spec shown?(atom() | nil, integer()) :: boolean()
  def shown?(unit_type, unit_id) when unit_type in [:player, :mob, :homunculus] do
    state =
      case UnitRegistry.get_unit(unit_type, unit_id) do
        {:ok, {_module, state, _pid}} -> state
        {:error, :not_found} -> nil
      end

    endure?(unit_type, unit_id, state, true)
  end

  def shown?(_unit_type, _unit_id), do: false

  @doc """
  Sets the unit's own endure time to `duration_ms` from `now`, replacing what it
  held. The writer may be any process, so a later hit read in the same pass
  already sees it.
  """
  @spec put_tick(atom(), integer(), non_neg_integer(), integer()) :: :ok
  def put_tick(unit_type, unit_id, duration_ms, now \\ now()),
    do: StatusStorage.put_endure_tick(unit_type, unit_id, now + duration_ms)

  @doc "The clock endure times are kept on."
  @spec now() :: integer()
  def now, do: System.monotonic_time(:millisecond)

  defp no_walk_delay?(%PlayerState{stats: %Stats{} = stats, map_name: map_name})
       when is_binary(map_name) do
    (Stats.get_equipment_modifier(stats, :no_walk_delay) > 0 or
       Stats.get_status_flag(stats, :no_walk_delay)) and
      Rules.status_allowed?(:sc_endure, map_name)
  end

  defp no_walk_delay?(_unit_state), do: false

  defp renewal_boss?(%MobState{} = mob),
    do: GameMode.mode() == :renewal and MobState.is_boss?(mob)

  defp renewal_boss?(_unit_state), do: false
end

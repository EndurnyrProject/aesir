defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ChaseWalk do
  @moduledoc """
  Chase Walk (SC_CHASEWALK).

  In renewal and pre-renewal, conceals its holder (the Cloak and Chase Walk
  sprite bits) and slows its movement by `35 - 5 * level` percent, the strongest
  slow winning. The holder cannot attack, pick up items or use any skill but
  Chase Walk. Every 10 s it drains `10 + 2 * level` SP, five times as much when
  it started on a GvG or battleground map; a drain the holder cannot pay ends
  it, and after a paid drain the holder gains Chase Walk's STR bonus
  (`sc_chasewalk2`) unless it already holds it. A monster has no SP to drain,
  so every drain counts as paid. Active damage, a map change, logout and death end
  it; ending it re-checks a warp under the player.

  Soul Link hook points (Rogue Spirit is not implemented): in `modifiers/2` the
  slow drops by 40 to a haste that replaces every other slow, and in
  `on_tick/3` the STR bonus lasts ten times as long.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_chasewalk,
    permanent: true,
    remove_on_death: true,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff, :conceals, :prevents_attack],
    calc_flags: [:speed],
    flags: [:no_pick_item, :stop_attacking, :remove_on_damaged, :on_touch],
    remove_on_map_change: true,
    tick_interval: 10_000,
    icon: :chasewalk,
    option: [:cloak, :chasewalk]

  import Bitwise

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @str_duration 30_000

  @doc "Stores the drain (`val4`) for the map the holder is on as it starts."
  @impl true
  @spec on_apply(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()}
  def on_apply({unit_type, unit_id}, %StatusEntry{val1: level} = instance, _context) do
    cost = 10 + 2 * level
    {:ok, %{instance | val4: if(costly_map?(unit_type, unit_id), do: cost * 5, else: cost)}}
  end

  defp costly_map?(unit_type, unit_id) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {_x, _y, map}} -> MapFlags.gvg2?(map) or MapFlags.get(map, :battleground)
      {:error, :not_found} -> false
    end
  end

  @impl true
  @spec modifiers(StatusEntry.t(), map()) :: %{movement_speed: integer()}
  def modifiers(%StatusEntry{val1: level}, _context), do: %{movement_speed: 35 - 5 * level}

  @impl true
  @spec on_tick(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()} | :remove
  def on_tick({:player, unit_id}, %StatusEntry{val1: level, val4: cost} = instance, _context) do
    with {:ok, {_module, _state, pid}} when is_pid(pid) <- UnitRegistry.get_unit(:player, unit_id),
         :ok <- PlayerSession.try_consume_sp(pid, cost) do
      grant_str(:player, unit_id, level)
      {:ok, instance}
    else
      _unpaid -> :remove
    end
  end

  def on_tick({:mob, unit_id}, %StatusEntry{val1: level} = instance, _context) do
    grant_str(:mob, unit_id, level)
    {:ok, instance}
  end

  defp grant_str(unit_type, unit_id, level) do
    unless StatusStorage.has_status?(unit_type, unit_id, :sc_chasewalk2) do
      Interpreter.apply_status(unit_type, unit_id, :sc_chasewalk2,
        val1: 1 <<< (level - 1),
        duration: @str_duration,
        caster_id: unit_id,
        source_type: unit_type
      )
    end

    :ok
  end
end

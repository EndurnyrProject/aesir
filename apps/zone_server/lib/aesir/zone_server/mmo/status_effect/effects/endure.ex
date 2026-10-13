defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Endure do
  @moduledoc """
  Endure (SC_ENDURE).

  Grants uninterrupted movement while taking hits and, unless `val3` is set,
  MDEF: `val1`, or 1 for an infinite Endure (`val4`). A finite Endure wears off
  after 7 connected hits from a non-player on a map outside siege ground;
  player hits never use it up. It survives its holder's death, and a
  player's Endure starts and ends its devotees' copies (`DevotionMirror`).

  The no-flinch half of the status has no modifier: Aesir has no hit-stun
  mechanic yet, so there is nothing for an `endure` flag to disable. Wire a
  flag through `modifiers/2` when hit-stun lands.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_endure,
    no_dispel: false,
    no_clear_buff: false,
    remove_on_death: false,
    properties: [:buff],
    calc_flags: [:mdef],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :endure

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @max_hits 7

  @impl true
  def modifiers(%{val3: 0, val4: 0} = instance, _context), do: %{mdef: instance.val1}
  def modifiers(%{val3: 0}, _context), do: %{mdef: 1}
  def modifiers(_instance, _context), do: %{}

  @impl true
  def on_apply(target, instance, context) do
    instance = put_state(instance, :hits_remaining, @max_hits)
    DevotionMirror.started(target, instance, instance.state, context.duration)
    {:ok, instance}
  end

  @impl true
  def on_expire(target, instance, _context), do: DevotionMirror.ended(target, instance)

  @impl true
  def on_damage(_target, %{val4: val4} = instance, _damage_info, _context) when val4 != 0 do
    {:ok, instance}
  end

  def on_damage({unit_type, unit_id}, instance, damage_info, _context) do
    if wears?(unit_type, unit_id, damage_info),
      do: count_hit(instance),
      else: {:ok, instance}
  end

  defp count_hit(instance) do
    case instance.state.hits_remaining - 1 do
      hits when hits <= 0 -> :remove
      hits -> {:ok, put_state(instance, :hits_remaining, hits)}
    end
  end

  defp wears?(unit_type, unit_id, %{attacker: {attacker_type, _id}} = damage_info)
       when attacker_type != :player do
    with true <- connected?(damage_info),
         {:ok, {_x, _y, map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id) do
      not Rules.ground?(map_name)
    else
      false -> false
      _unplaced -> true
    end
  end

  defp wears?(_unit_type, _unit_id, _damage_info), do: false

  # An attack counts when it connected (even for nothing, as a reflected spell
  # can); any other active damage counts even when it took no HP.
  defp connected?(%{proc_event: %{hit_class: class}}), do: class == :hit
  defp connected?(_damage_info), do: true

  # An infinite Endure is never replaced by a finite one.
  @impl true
  def overlap(_target, %{val4: held}, %{val4: 0}) when held != 0, do: :keep
  def overlap(_target, %{val1: held}, %{val1: incoming}) when held > incoming, do: :keep
  def overlap(_target, _held, _incoming), do: :replace
end

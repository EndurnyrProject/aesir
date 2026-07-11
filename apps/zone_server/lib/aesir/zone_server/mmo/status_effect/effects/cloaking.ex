defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Cloaking do
  @moduledoc """
  Cloaking (SC_CLOAKING).

  Conceals the character while allowing movement. Doubles CRIT and adjusts
  movement speed by skill level (val1). Broken by taking damage.

  ## Movement speed and the wall-adjacency gap

  rAthena's `status_calc_speed` makes Cloaking bidirectional based on a
  wall-adjacency bit (`val4 & 1`):

    - not adjacent to a wall (`val4 & 1 == 0`): SLOW,
      `max(val, val1 < 3 ? 300 : 30 - 3 * val1)`
    - adjacent to a wall (`val4 & 1 == 1`): HASTE,
      `max(val, val1 >= 10 ? 25 : 3 * val1 - 3)`

  Aesir does not track wall adjacency, so the haste branch cannot be modelled.
  We implement the conservative not-against-wall SLOW for every level
  (`val1 < 3 -> 300`, otherwise `30 - 3 * val1`, reaching 0 at level 10),
  expressed as a positive `:movement_speed` modifier. A Cloaking user hugging a
  wall would be hasted in rAthena but is merely un-slowed here.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cloaking,
    properties: [:buff],
    calc_flags: [:cri, :speed],
    flags: [:cloak, :no_pick_item, :stop_attacking],
    prevented_by: [:sc_refresh, :sc_inspiration],
    no_save: true,
    icon: :cloaking,
    option: :cloak

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  def modifiers(%StatusEntry{val1: level}, context) do
    %{cri: Map.get(context.target, :cri, 0), movement_speed: speed_penalty(level)}
  end

  @spec speed_penalty(integer() | nil) :: non_neg_integer()
  defp speed_penalty(level) when is_integer(level) and level >= 3, do: 30 - 3 * level
  defp speed_penalty(_level), do: 300

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, :cloaked, true)}
  end

  @impl true
  def on_damage(_target, _instance, _damage_info, _context), do: :remove
end

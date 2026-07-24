defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Devotion do
  @moduledoc """
  Devotion (SC_DEVOTION), the devotee half of the Crusader link.

  Held by a devoted party member; its state carries the reference to the
  Crusader, the shared `link_id` matching the Crusader's `sc_devoted_by` entry,
  and the stored redirect `range`:

      %{peer: {:player, crusader_id}, link_id: ref, range: r}

  The pairing follows the Blade Stop / Root precedent - a shared `link_id`, an
  `on_expire` peer cascade, and a per-second liveness self-heal - with no
  coordinator:

    * ending this record detaches the devotee from the Crusader's `sc_devoted_by`
      map for the same link id. When `peer` has been nulled by the Crusader-side
      cascade the detach is a no-op, terminating the echo;
    * a per-second tick removes the record once the Crusader's entry no longer
      carries a matching link, or the Crusader unit has vanished - the case a
      terminating session that cleared status storage directly leaves behind;
    * the finite 30xlv second duration is the final backstop.

  No gameplay modifiers land here yet: damage rerouting through this link is a
  later change. The status is not persisted (`no_save`) and ends on a cross-map
  warp (`remove_on_map_change`): the pairing is tied to two live units on one
  map.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_devotion,
    no_dispel: false,
    no_save: true,
    remove_on_map_change: true,
    properties: [:buff],
    tick_interval: 1_000,
    icon: :devotion

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def on_expire({_type, devotee_id}, %StatusEntry{state: state}, _context) do
    detach(devotee_id, state)
    :ok
  end

  @impl true
  def on_tick({_type, devotee_id}, %StatusEntry{state: state} = instance, _context) do
    if peer_intact?(devotee_id, state), do: {:ok, instance}, else: :remove
  end

  # Detaches this devotee from the Crusader's provider entry. A nulled peer -
  # cleared by the Crusader-side cascade before it removed this record - makes
  # the detach a no-op, which is what terminates the removal echo.
  defp detach(devotee_id, %{peer: {:player, crusader_id}, link_id: link_id}) do
    DevotedBy.unlink(crusader_id, devotee_id, link_id)
  end

  defp detach(_devotee_id, _state), do: :ok

  defp peer_intact?(devotee_id, %{peer: {:player, crusader_id}, link_id: link_id}) do
    provider_matches?(crusader_id, devotee_id, link_id) and alive?(crusader_id)
  end

  defp peer_intact?(_devotee_id, _state), do: false

  defp provider_matches?(crusader_id, devotee_id, link_id) do
    match?(
      %StatusEntry{state: %{links: %{^devotee_id => %{link_id: ^link_id}}}},
      StatusStorage.get_status(:player, crusader_id, :sc_devoted_by)
    )
  end

  defp alive?(unit_id) do
    case UnitRegistry.get_unit(:player, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _ -> false
    end
  end
end

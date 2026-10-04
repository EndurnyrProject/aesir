defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Marionette2 do
  @moduledoc """
  Marionette Control's puppet half, identical in renewal and pre-renewal.

  Frozen gains keep each total primary stat at or below ninety-nine at apply
  time. Each second the living master must still hold the matching link and
  be within seven cells on the same map. Ending either half ends both.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_marionette2,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:str, :agi, :vit, :int, :dex, :luk, :max_hp],
    permanent: true,
    no_save: true,
    remove_on_map_change: true,
    target_types: [:player],
    tick_interval: 1_000,
    icon: :marionette

  alias Aesir.ZoneServer.Mmo.Skills.Clown.MarionetteLink
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: map()
  def modifiers(%StatusEntry{state: state}, _context), do: Map.get(state, :gains, %{})

  @impl true
  @spec on_tick(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()} | :remove
  def on_tick(
        {:player, id},
        %StatusEntry{state: %{peer: {:player, peer}, link_id: link}} = entry,
        _context
      ) do
    if MarionetteLink.intact?(peer, :sc_marionette, link) and MarionetteLink.within?(id, peer, 7),
      do: {:ok, entry},
      else: :remove
  end

  def on_tick(_target, _entry, _context), do: :remove

  @impl true
  @spec on_expire(Definition.target(), StatusEntry.t(), Definition.context()) :: :ok
  def on_expire(_target, %StatusEntry{state: state}, _context),
    do: MarionetteLink.close_peer(state, :sc_marionette)
end

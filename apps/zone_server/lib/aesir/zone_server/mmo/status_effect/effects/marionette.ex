defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Marionette do
  @moduledoc """
  Marionette Control's master half, identical in renewal and pre-renewal.

  Frozen primary-stat halves are subtracted and MaxHP loses one thousand.
  The pair lasts until removal, map change, death or separation beyond seven
  cells. The puppet may be a player or the caster's Homunculus. Per-second
  checks and an echo-terminating expiry close the counterpart.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_marionette,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:str, :agi, :vit, :int, :dex, :luk, :max_hp],
    permanent: true,
    no_save: true,
    remove_on_death: true,
    remove_on_map_change: true,
    target_types: [:player],
    tick_interval: 1_000,
    icon: :marionette_master,
    opt3: :marionette

  alias Aesir.ZoneServer.Mmo.Skills.Clown.MarionetteLink
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: map()
  def modifiers(%StatusEntry{state: state}, _context) do
    state
    |> Map.get(:halves, %{})
    |> Map.new(fn {stat, amount} -> {stat, -amount} end)
    |> Map.put(:max_hp, -1000)
  end

  @impl true
  @spec on_tick(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()} | :remove
  def on_tick(
        {:player, id},
        %StatusEntry{state: %{peer: peer, link_id: link}} = entry,
        _context
      ) do
    if MarionetteLink.intact?(peer, :sc_marionette2, link) and
         MarionetteLink.within?({:player, id}, peer, 7),
       do: {:ok, entry},
       else: :remove
  end

  def on_tick(_target, _entry, _context), do: :remove

  @impl true
  @spec on_expire(Definition.target(), StatusEntry.t(), Definition.context()) :: :ok
  def on_expire(_target, %StatusEntry{state: state}, _context),
    do: MarionetteLink.close_peer(state, :sc_marionette2)
end

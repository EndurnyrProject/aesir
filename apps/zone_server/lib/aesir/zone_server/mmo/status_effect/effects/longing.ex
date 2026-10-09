defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Longing do
  @moduledoc """
  Longing for Freedom relaxes a pre-renewal ensemble's performing lock.

  Movement slows by `50 - 10 * level` percent and ASPD takes the opposite
  rate penalty. Level five has no penalty. The granting skill is absent from
  renewal's tree, so this status is not normally applied in renewal. Moonlit
  and Hermode remain rooted, and performing upkeep is tripled in both modes
  whenever the status is held.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_longing,
    no_dispel: false,
    no_clear_buff: [renewal: true, pre_renewal: false],
    properties: [:buff],
    calc_flags: [:movement_speed, :aspd_rate],
    no_save: true,
    remove_on_map_change: true,
    target_types: [:player],
    icon: :longing

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: map()
  def modifiers(%StatusEntry{val1: level}, _context) do
    penalty = 50 - 10 * (level || 1)
    %{movement_speed: penalty, aspd_rate: -penalty}
  end
end

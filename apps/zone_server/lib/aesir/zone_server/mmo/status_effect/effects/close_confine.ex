defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CloseConfine do
  @moduledoc """
  Close Confine's caster hold (SC_CLOSECONFINE).

  Renewal grants the held FLEE bonus of 50; classic grants 10. Recipient starts
  supply the captured bonus, hold count and extra-second duration. Expiry or
  removal frees nearby recipients, but death does not end the hold.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_closeconfine,
    immunity: [:boss],
    no_dispel: true,
    no_clear_buff: false,
    no_save: true,
    remove_on_death: false,
    remove_on_map_change: true,
    properties: [:prevents_movement],
    flags: [:no_move],
    calc_flags: [:flee],
    duration: 10_000,
    icon: :rg_cconfine_m

  alias Aesir.ZoneServer.Mmo.StatusEffect.CloseConfineLink
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), map()) :: %{flee: integer()}
  def modifiers(instance, _context), do: %{flee: instance.val3}

  @impl true
  @spec on_expire({atom(), integer()}, StatusEntry.t(), map()) :: :ok
  def on_expire(target, instance, _context), do: CloseConfineLink.end_caster(target, instance)
end

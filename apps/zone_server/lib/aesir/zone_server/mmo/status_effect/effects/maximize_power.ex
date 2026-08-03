defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MaximizePower do
  @moduledoc """
  Maximize Power (SC_MAXIMIZEPOWER).

  Forces weapon variance to its maximum, suppresses natural SP regeneration,
  and drains one SP at the caster-provided per-level tick interval.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_maximizepower,
    no_dispel: false,
    properties: [:buff],
    target_types: [:player],
    permanent: true,
    calc_flags: [:atk],
    icon: :maximize

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers, only: [consume_sp: 2]

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), map()) :: %{max_weapon_damage: true, sp_regen: -100}
  def modifiers(_instance, _context), do: %{max_weapon_damage: true, sp_regen: -100}

  @impl true
  @spec on_tick(Definition.target(), StatusEntry.t(), map()) :: {:ok, StatusEntry.t()} | :remove
  def on_tick(target, instance, %{target: %{sp: sp}}) do
    if sp < 1 do
      :remove
    else
      consume_sp(target, 1)
      {:ok, instance}
    end
  end
end

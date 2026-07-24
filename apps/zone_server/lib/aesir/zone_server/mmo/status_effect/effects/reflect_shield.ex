defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ReflectShield do
  @moduledoc """
  Reflect Shield (SC_REFLECTSHIELD).

  Toggled by CR_REFLECTSHIELD while a shield is equipped. Implements
  `after_damage_taken/4`: `val1` carries the skill level, and every short-range
  weapon hit that reaches the hook reflects `(10 + 3 * val1)` percent of the
  delivered damage back to the attacker. The hook seam already guarantees
  short-range-weapon-only dispatch and loop prevention (reflected/redirected
  hits never re-trigger it), so this module owns only the percentage.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_reflectshield,
    no_dispel: false,
    permanent: true,
    no_save: true,
    properties: [:buff],
    icon: :reflectshield

  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec after_damage_taken({atom(), integer()}, StatusEntry.t(), map(), map()) ::
          :ok | {:reflect, non_neg_integer()}
  def after_damage_taken(_target, %StatusEntry{val1: level}, %{damage: damage}, _context) do
    amount = div(damage * (10 + 3 * level), 100)

    if amount > 0 do
      {:reflect, amount}
    else
      :ok
    end
  end
end

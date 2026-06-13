defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ArcaneCharge do
  @moduledoc """
  Arcane Charge (SC_ARCANE_CHARGE).

  Accumulates a charge every time the holder takes damage, granting +10 MATK
  per charge. At 3 charges the energy discharges, damaging the holder based on
  the caster's INT and resetting the counter.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_arcane_charge,
    properties: [:buff],
    calc_flags: [:matk]

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @max_charges 3

  @impl true
  def modifiers(instance, _context), do: %{matk: instance.state.charges * 10}

  @impl true
  def on_apply(_target, instance, _context), do: {:ok, put_state(instance, :charges, 0)}

  @impl true
  def on_damage(target, instance, _damage_info, context) do
    charges = instance.state.charges + 1

    if charges >= @max_charges do
      deal_damage(target, Map.get(context.caster, :int, 0) * 2)
      {:ok, put_state(instance, :charges, 0)}
    else
      {:ok, put_state(instance, :charges, charges)}
    end
  end
end

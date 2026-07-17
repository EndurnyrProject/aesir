defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Kyrie do
  @moduledoc """
  Kyrie Eleison (SC_KYRIE).

  A holy barrier absorbing up to val2 damage or val3 physical hits, whichever
  runs out first. Physical hits are blocked via the pre-damage `absorb_damage`
  hook, decrementing the shield pool and hit count until either is exhausted.
  Magic and non-physical hits pass through unchanged.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_kyrie,
    no_dispel: false,
    properties: [:buff],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :kyrie

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, shield_hp: instance.val2, hits_remaining: instance.val3)}
  end

  @impl true
  def absorb_damage(_target, instance, %{damage: damage, dmg_type: :physical}, _context) do
    shield_hp = instance.state.shield_hp - damage
    hits = instance.state.hits_remaining - 1

    if hits <= 0 or shield_hp <= 0 do
      :remove
    else
      {:ok, 0, put_state(instance, shield_hp: shield_hp, hits_remaining: hits)}
    end
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}
end

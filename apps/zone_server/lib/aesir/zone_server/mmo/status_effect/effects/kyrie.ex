defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Kyrie do
  @moduledoc """
  Kyrie Eleison (SC_KYRIE).

  A holy barrier absorbing up to val2 damage or val3 physical hits, whichever
  runs out first. Actual damage absorption awaits a damage-modification hook
  in the combat engine; hit and shield accounting are tracked here.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_kyrie,
    properties: [:buff],
    prevented_by: [:sc_refresh, :sc_inspiration]

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, shield_hp: instance.val2, hits_remaining: instance.val3)}
  end

  @impl true
  def on_damage(_target, instance, %{damage: damage, dmg_type: :physical}, _context) do
    shield_hp = instance.state.shield_hp - damage
    hits = instance.state.hits_remaining - 1

    if hits <= 0 or shield_hp <= 0 do
      :remove
    else
      {:ok, put_state(instance, shield_hp: shield_hp, hits_remaining: hits)}
    end
  end

  def on_damage(_target, instance, _damage_info, _context), do: {:ok, instance}
end

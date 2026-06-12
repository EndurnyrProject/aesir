defmodule Aesir.ZoneServer.Mmo.StatusEffects.Endure do
  @moduledoc """
  Endure (SC_ENDURE).

  Grants MDEF (val1) and uninterrupted movement while taking hits. Wears off
  after 7 hits unless val4 marks it as infinite.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_endure,
    properties: [:buff],
    calc_flags: [:mdef],
    prevented_by: [:sc_refresh, :sc_inspiration]

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @max_hits 7

  @impl true
  def modifiers(instance, _context), do: %{mdef: instance.val1, endure: true}

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, :hits_remaining, @max_hits)}
  end

  @impl true
  def on_damage(_target, %{val4: val4} = instance, _damage_info, _context) when val4 != 0 do
    {:ok, instance}
  end

  def on_damage(_target, instance, _damage_info, _context) do
    hits = instance.state.hits_remaining - 1

    if hits <= 0 do
      :remove
    else
      {:ok, put_state(instance, :hits_remaining, hits)}
    end
  end
end

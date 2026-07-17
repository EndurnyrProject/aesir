defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoisonReact do
  @moduledoc """
  Poison React (SC_POISONREACT).

  Stores counter charges (val1 / 2) that arm a damage boost when the holder
  is hit. The boosted counter-attack itself awaits attack-event dispatch in
  the combat engine.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_poisonreact,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:atk],
    icon: :poisonreact,
    prevented_by: [:sc_refresh, :sc_inspiration]

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, counter_remaining: div(instance.val1, 2), boost_mode: false)}
  end

  @impl true
  def on_damage(_target, instance, _damage_info, _context) do
    %{counter_remaining: counter, boost_mode: boost_mode} = instance.state

    if counter > 0 and not boost_mode do
      remaining = counter - 1

      if remaining <= 0 do
        :remove
      else
        {:ok, put_state(instance, counter_remaining: remaining, boost_mode: true)}
      end
    else
      {:ok, instance}
    end
  end
end

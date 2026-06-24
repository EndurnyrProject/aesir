defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Blessing do
  @moduledoc """
  Blessing (SC_BLESSING).

  Raises STR, INT and DEX by val2 with a HIT bonus. Cast on a cursed target it
  is consumed curing the curse instead; cast on a petrified target it cures
  the petrification and still applies. Against undead/demon targets the caster
  sets val2 to 0, halving those stats instead (rAthena behavior).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_blessing,
    properties: [:buff],
    calc_flags: [:str, :int, :dex, :hit],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :blessing

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def modifiers(%{val2: 0}, context) do
    stats = context.target

    %{
      str: -div(stats.str, 2),
      int: -div(stats.int, 2),
      dex: -div(stats.dex, 2),
      hit: -div(Map.get(stats, :hit, 0), 2)
    }
  end

  def modifiers(instance, _context) do
    %{
      str: instance.val2,
      int: instance.val2,
      dex: instance.val2,
      hit: instance.val2 * 3
    }
  end

  @impl true
  def on_apply(target, instance, _context) do
    if has_status?(target, :sc_curse) do
      remove_status(target, :sc_curse)
      :remove
    else
      if has_status?(target, :sc_stone), do: remove_status(target, :sc_stone)
      {:ok, instance}
    end
  end
end

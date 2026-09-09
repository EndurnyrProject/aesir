defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Blessing do
  @moduledoc """
  Blessing (SC_BLESSING).

  Raises STR, INT and DEX by val2. Cast on a cursed target it is consumed curing
  the curse instead; cast on a petrified target it cures the petrification and
  still applies. Against an undead or demon target the caster sets val2 to 0,
  and the buff halves those three stats instead. The halving works on the
  recipient's calculated stats (allocated points plus job and equipment
  contributions), not on the allocated points alone; it deliberately reads the
  value without the status layer, since it emits a delta on the very stats it
  reads and would otherwise compound on every recalculation.

  Renewal: the buff also grants HIT equal to twice the skill level. That bonus
  is unconditional — a hostile recipient still gets it, and it is never halved.

  Pre-renewal: no HIT bonus at all; the stat changes are identical.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_blessing,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:str, :int, :dex, :hit],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :blessing

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(%{val2: 0} = instance, context) do
    stats = context.target.unbuffed_stats

    %{
      str: -div(stats.str, 2),
      int: -div(stats.int, 2),
      dex: -div(stats.dex, 2),
      hit: hit_bonus(instance)
    }
  end

  def modifiers(instance, _context) do
    %{
      str: instance.val2,
      int: instance.val2,
      dex: instance.val2,
      hit: hit_bonus(instance)
    }
  end

  @spec hit_bonus(map()) :: non_neg_integer()
  defp hit_bonus(instance) do
    case GameMode.mode() do
      :renewal -> instance.val1 * 2
      :pre_renewal -> 0
    end
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

defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Blessing do
  @moduledoc """
  Blessing (SC_BLESSING).

  Raises STR, INT and DEX by val2. On a player, Curse is cured first;
  otherwise petrification is cured. Either cure succeeds without applying a
  new Blessing, even when a stronger Blessing is already held. Players receive
  val1 as their normal stat increase. Against a non-player undead or demon
  target val2 is 0, and the buff halves those three stats instead. The halving works on the
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
    immunity: [:boss],
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [renewal: [:str, :int, :dex, :hit], pre_renewal: [:str, :int, :dex]],
    icon: :blessing

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Unit.UnitRegistry

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
  def before_overlap({type, _id} = target, _instance, _context) do
    cond do
      type == :player and has_status?(target, :sc_curse) -> {:end_only, [:sc_curse]}
      type == :player and has_status?(target, :sc_stone) -> {:end_only, [:sc_stone]}
      true -> {:continue, high_spirit_end_actions(target)}
    end
  end

  @impl true
  def on_apply({:player, _id}, instance, %{loaded: false}),
    do: {:ok, %{instance | val2: instance.val1}}

  def on_apply({type, id}, instance, %{loaded: false}) do
    {:ok, info} = UnitRegistry.get_unit_info(type, id)
    val2 = if RaceModifiers.undead_or_demon?(info), do: 0, else: instance.val1
    {:ok, %{instance | val2: val2}}
  end

  def on_apply(_target, instance, _context), do: {:ok, instance}
end

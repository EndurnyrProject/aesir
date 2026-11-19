defmodule Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.PreRenewal do
  @moduledoc """
  Classic mob formulas use unshifted HIT/FLEE and VIT-based soft defenses.

  A monster rolls its `Attack` to `Attack2`, both raised by status weapon ATK,
  and has no status ATK. Its MATK is INT-based, plus flat status MATK, then
  Mystical Amplification. A guardian's Guard Up is its only status ATK.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.MobFormulas

  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.StatusEffect.CalcFlags
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Mob.Calculated
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @impl true
  @spec base(MobState.t()) :: Calculated.t()
  def base(state) do
    data = state.mob_data
    stats = data.stats

    MobFormulas.base_snapshot(state, %{
      hit: min(max(data.level + stats.dex, 1), 32_767),
      flee: min(max(data.level + stats.agi, 1), 32_767),
      def2: min(max(stats.vit, 0), 32_767),
      mdef2: min(max(stats.int + div(stats.vit, 2), 0), 32_767),
      batk: 0,
      watk_min: data.atk,
      watk_max: data.atk2,
      matk_min: stats.int + div(stats.int, 7) * div(stats.int, 7),
      matk_max: stats.int + div(stats.int, 5) * div(stats.int, 5),
      def: min(max(data.def, -128), 127),
      mdef: min(max(data.mdef, -128), 127)
    })
  end

  @impl true
  @spec base(MobState.t(), keyword()) :: Calculated.t()
  def base(state, opts), do: MobFormulas.adjusted_base(state, opts, __MODULE__, 8)

  @impl true
  @spec expand_calc_flags([CalcFlags.flag()]) :: [CalcFlags.flag()]
  def expand_calc_flags(flags), do: MobFormulas.expand_calc_flags(flags, :pre_renewal)

  @impl true
  @spec recalculate(MobState.t(), [StatusEntry.t()], [CalcFlags.flag()]) :: Calculated.t()
  def recalculate(state, entries, flags),
    do: MobFormulas.recalculate(state, entries, flags, :pre_renewal)

  @impl true
  def magic_attack_bounds(%MobDefinition{}, int) do
    MobFormulas.floor_zero({int + div(int, 7) * div(int, 7), int + div(int, 5) * div(int, 5)})
  end
end

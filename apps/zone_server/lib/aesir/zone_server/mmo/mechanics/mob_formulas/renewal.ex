defmodule Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.Renewal do
  @moduledoc """
  Renewal mob formulas use the combat HIT/FLEE baselines and level-scaled soft MDEF.

  A monster rolls 80% to 120% of its `Attack` (status weapon ATK is inert) and
  adds status ATK, `STR + level` plus status ATK modifiers. Its MATK is
  `INT + level` plus 70% to 130% of its database MATK, then Mystical
  Amplification, then flat status MATK.
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
      hit: min(max(data.level + stats.dex + 150, 1), 32_767),
      flee: min(max(data.level + stats.agi + 100, 1), 32_767),
      def2: min(max(div(data.level + stats.vit, 2), 0), 32_767),
      mdef2: min(max(div(stats.int + data.level, 4), 0), 32_767),
      batk: min(max(stats.str + data.level, 0), 65_535),
      watk_min: div(data.atk * 80, 100),
      watk_max: div(data.atk * 120, 100),
      matk_min: stats.int + data.level + div(data.matk * 70, 100),
      matk_max: stats.int + data.level + div(data.matk * 130, 100),
      def: min(max(data.def, -32_768), 32_767),
      mdef: min(max(data.mdef, -32_768), 32_767)
    })
  end

  @impl true
  @spec base(MobState.t(), keyword()) :: Calculated.t()
  def base(state, opts), do: MobFormulas.adjusted_base(state, opts, __MODULE__, 16)

  @impl true
  @spec expand_calc_flags([CalcFlags.flag()]) :: [CalcFlags.flag()]
  def expand_calc_flags(flags), do: MobFormulas.expand_calc_flags(flags, :renewal)

  @impl true
  @spec recalculate(MobState.t(), [StatusEntry.t()], [CalcFlags.flag()]) :: Calculated.t()
  def recalculate(state, entries, flags),
    do: MobFormulas.recalculate(state, entries, flags, :renewal)

  @impl true
  def magic_attack_bounds(%MobDefinition{level: level, matk: matk}, int) do
    MobFormulas.floor_zero(
      {int + level + div(matk * 70, 100), int + level + div(matk * 130, 100)}
    )
  end
end

defmodule Aesir.ZoneServer.Mmo.Woe.Economy do
  @moduledoc """
  Pure economy/defense investment rules for WoE First Edition castles, plus
  the writes that apply them through the castle store and persistence.

  Levels run 0-100. Investment cost rises in tiers of five levels and
  quadruples for the second and third investment of the same day. Daily
  maturation applies the day's investments, capped at 100, with a rare
  economy-only bonus point when the owning guild has learned the castle
  development guild skill. Conquest applies a flat penalty to both tracks
  and clears the day's investment counters.
  """

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Persistence

  @typedoc "Which castle track is being invested in."
  @type kind :: :economy | :defense

  @battle_development_skill_id 10_014
  @emperium_mob_id 1288

  @economy_tiers [
    5_000,
    10_000,
    20_000,
    35_000,
    55_000,
    80_000,
    110_000,
    145_000,
    185_000,
    230_000,
    280_000,
    335_000,
    395_000,
    460_000,
    530_000,
    605_000,
    685_000,
    770_000,
    860_000,
    955_000
  ]

  @defense_tiers [
    10_000,
    20_000,
    40_000,
    70_000,
    110_000,
    160_000,
    220_000,
    290_000,
    370_000,
    460_000,
    560_000,
    670_000,
    790_000,
    920_000,
    1_060_000,
    1_210_000,
    1_370_000,
    1_540_000,
    1_720_000,
    1_910_000
  ]

  @doc """
  Zeny cost to invest one point in `kind` at `level`, quadrupled once
  `invested_today` is already above zero.
  """
  @spec invest_cost(kind(), 0..100, 0..2) :: pos_integer()
  def invest_cost(kind, level, invested_today) do
    base_cost = Enum.at(tiers_for(kind), tier_index(level))

    if invested_today > 0, do: base_cost * 4, else: base_cost
  end

  @doc """
  Records one investment in `kind` for `castle_id` on behalf of `guild_id`.

  Fails with `:not_owner` when `guild_id` does not hold the castle, `:maxed`
  once the track has reached level 100, or `:daily_limit` once two
  investments have already been made today. On success, writes the
  incremented counter to the castle store and persistence, returning the
  zeny cost charged for the investment (computed from the pre-increment
  counter).
  """
  @spec invest(non_neg_integer(), kind(), non_neg_integer()) ::
          {:ok, pos_integer()} | {:error, :not_owner | :maxed | :daily_limit}
  def invest(castle_id, kind, guild_id) do
    state = CastleStore.economy(castle_id)
    level = Map.fetch!(state, kind)
    invested_today = Map.fetch!(state, invested_key(kind))

    cond do
      CastleStore.owner(castle_id) != guild_id ->
        {:error, :not_owner}

      level >= 100 ->
        {:error, :maxed}

      invested_today >= 2 ->
        {:error, :daily_limit}

      true ->
        cost = invest_cost(kind, level, invested_today)
        new_state = Map.put(state, invested_key(kind), invested_today + 1)

        CastleStore.put_economy(castle_id, new_state)
        Persistence.persist_economy(castle_id, new_state)

        {:ok, cost}
    end
  end

  @doc """
  Applies one day's maturation to `state`: today's investments raise economy
  and defense (capped at 100), and both daily counters reset to zero.

  `development?` and `roll` gate a single bonus economy point: rolled only
  when economy was invested today, the owning guild has learned the castle
  development guild skill, and `roll.()` comes up `2`.
  """
  @spec mature(CastleStore.economy_state(), boolean(), (-> 1 | 2)) ::
          CastleStore.economy_state()
  def mature(state, development?, roll) do
    bonus =
      if state.invested_economy > 0 and development? and roll.() == 2, do: 1, else: 0

    %{
      economy: min(state.economy + state.invested_economy + bonus, 100),
      defense: min(state.defense + state.invested_defense, 100),
      invested_economy: 0,
      invested_defense: 0
    }
  end

  @doc """
  Matures every owned castle; unowned castles are left untouched.
  """
  @spec mature_all() :: :ok
  def mature_all do
    Enum.each(CastleDb.all(), fn castle ->
      case CastleStore.owner(castle.id) do
        nil -> :ok
        guild_id -> mature_castle(castle.id, guild_id)
      end
    end)
  end

  @doc """
  Applies the conquest penalty to an economy state: both tracks drop five
  points (floored at zero) and today's investment counters clear.
  """
  @spec conquest_penalty(CastleStore.economy_state()) :: CastleStore.economy_state()
  def conquest_penalty(state) do
    %{
      economy: max(state.economy - 5, 0),
      defense: max(state.defense - 5, 0),
      invested_economy: 0,
      invested_defense: 0
    }
  end

  @doc """
  Applies and writes the conquest penalty for `castle_id`.
  """
  @spec apply_conquest_penalty(non_neg_integer()) :: :ok
  def apply_conquest_penalty(castle_id) do
    new_state =
      castle_id
      |> CastleStore.economy()
      |> conquest_penalty()

    CastleStore.put_economy(castle_id, new_state)
    Persistence.persist_economy(castle_id, new_state)
  end

  @doc """
  Emperium spawn options for a castle at `defense`: HP scaled by the mode's
  formula, plus a flat DEF/MDEF stat bonus shared by both modes.
  """
  @spec emperium_summon_opts(0..100, Aesir.Commons.GameMode.t()) :: keyword()
  def emperium_summon_opts(defense, mode) do
    {:ok, mob} = Mobs.by_id(@emperium_mob_id)
    flat = div(defense + 2, 3)

    [
      hp_override: mob.hp + hp_bonus(defense, mode),
      stat_bonus: %{def: flat, mdef: flat}
    ]
  end

  @spec tier_index(0..100) :: non_neg_integer()
  defp tier_index(level) when level <= 5, do: 0
  defp tier_index(level), do: div(level - 1, 5)

  @spec tiers_for(kind()) :: [pos_integer()]
  defp tiers_for(:economy), do: @economy_tiers
  defp tiers_for(:defense), do: @defense_tiers

  @spec invested_key(kind()) :: :invested_economy | :invested_defense
  defp invested_key(:economy), do: :invested_economy
  defp invested_key(:defense), do: :invested_defense

  @spec mature_castle(non_neg_integer(), non_neg_integer()) :: :ok
  defp mature_castle(castle_id, guild_id) do
    new_state =
      castle_id
      |> CastleStore.economy()
      |> mature(development?(guild_id), fn -> :rand.uniform(2) end)

    CastleStore.put_economy(castle_id, new_state)
    Persistence.persist_economy(castle_id, new_state)
  end

  @spec development?(non_neg_integer()) :: boolean()
  defp development?(guild_id) do
    case GuildManager.get(guild_id) do
      {:ok, guild} -> GuildState.skill_level(guild, @battle_development_skill_id) > 0
      {:error, :not_found} -> false
    end
  end

  @spec hp_bonus(0..100, Aesir.Commons.GameMode.t()) :: non_neg_integer()
  defp hp_bonus(defense, :renewal), do: 50 * div(defense, 5)
  defp hp_bonus(defense, :pre_renewal), do: 1_000 * defense
end

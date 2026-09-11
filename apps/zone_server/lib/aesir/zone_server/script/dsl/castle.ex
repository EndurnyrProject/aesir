defmodule Aesir.ZoneServer.Script.Dsl.Castle do
  @moduledoc """
  Castle economy buildins for the script DSL: castle identity and ownership
  lookups, economy/defense figures and investment cost, guild leadership
  checks, and recording an investment.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade. This is
  the only seam through which a hand-written NPC (the WoE steward) reaches
  the castle economy engine.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal, only: [no_player!: 1]

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Economy
  alias Aesir.ZoneServer.Script.Ctx

  @doc """
  The id of the castle at the attached player's current map, or `nil` when
  the map is not a castle. Raises on a detached ctx.
  """
  @spec castle_at(Ctx.t()) :: non_neg_integer() | nil
  def castle_at(%Ctx{game_state: nil}), do: no_player!("castle_at/1")

  def castle_at(%Ctx{game_state: gs}) do
    case CastleDb.by_map(gs.map_name) do
      {:ok, castle} -> castle.id
      :error -> nil
    end
  end

  @doc "The castle's display name."
  @spec castle_name(Ctx.t(), non_neg_integer()) :: String.t()
  def castle_name(%Ctx{}, castle_id) do
    {:ok, castle} = CastleDb.by_id(castle_id)
    castle.name
  end

  @doc "The castle's current owner guild, or `nil` when unowned."
  @spec castle_owner(Ctx.t(), non_neg_integer()) :: non_neg_integer() | nil
  def castle_owner(%Ctx{}, castle_id), do: CastleStore.owner(castle_id)

  @doc "The castle's economy/defense levels and today's investment counters."
  @spec castle_economy(Ctx.t(), non_neg_integer()) :: CastleStore.economy_state()
  def castle_economy(%Ctx{}, castle_id), do: CastleStore.economy(castle_id)

  @doc """
  Zeny cost of the castle's next investment in `kind`, derived from its
  current level and today's investment count.
  """
  @spec castle_invest_cost(Ctx.t(), non_neg_integer(), Economy.kind()) :: pos_integer()
  def castle_invest_cost(%Ctx{}, castle_id, kind) do
    state = CastleStore.economy(castle_id)
    Economy.invest_cost(kind, Map.fetch!(state, kind), Map.fetch!(state, invested_field(kind)))
  end

  @doc """
  Whether the attached player leads guild `guild_id` (`false` for an unknown
  guild).
  """
  @spec is_guild_leader(Ctx.t(), non_neg_integer()) :: boolean()
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_guild_leader(%Ctx{char_id: char_id}, guild_id) do
    case GuildManager.get(guild_id) do
      {:ok, %GuildState{master_char_id: master_char_id}} -> master_char_id == char_id
      {:error, :not_found} -> false
    end
  end

  @doc """
  Records one investment in `kind` for `castle_id` on behalf of the attached
  player's guild. Halts with the rejection reason (`:not_owner`, `:maxed`,
  `:daily_limit`) on failure; returns `ctx` unchanged on success.
  """
  @spec castle_invest(Ctx.t(), non_neg_integer(), Economy.kind()) :: Ctx.t()
  def castle_invest(%Ctx{status: {:error, _}} = ctx, _castle_id, _kind), do: ctx
  def castle_invest(%Ctx{game_state: nil} = ctx, _castle_id, _kind), do: Ctx.halt(ctx, :no_player)

  def castle_invest(%Ctx{game_state: gs} = ctx, castle_id, kind) do
    case Economy.invest(castle_id, kind, gs.guild_id) do
      {:ok, _cost} -> ctx
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @spec invested_field(Economy.kind()) :: :invested_economy | :invested_defense
  defp invested_field(:economy), do: :invested_economy
  defp invested_field(:defense), do: :invested_defense
end

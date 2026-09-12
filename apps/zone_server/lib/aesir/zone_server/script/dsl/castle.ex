defmodule Aesir.ZoneServer.Script.Dsl.Castle do
  @moduledoc """
  Castle economy and guardian buildins for the script DSL: castle identity
  and ownership lookups, economy/defense figures and investment cost, guild
  leadership checks, recording an investment, listing/pre-checking/hiring
  guardian slots, and checking/hiring/firing the castle's Kafra service.

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
  alias Aesir.ZoneServer.Mmo.Woe.Guardians
  alias Aesir.ZoneServer.Mmo.Woe.Services
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

  @doc """
  The castle's eight guardian slots in slot order, each with its type and
  whether it is currently hired.
  """
  @spec castle_guardians(Ctx.t(), non_neg_integer()) :: [
          %{slot: 0..7, type: :soldier | :archer | :knight, hired?: boolean()}
        ]
  def castle_guardians(%Ctx{}, castle_id) do
    {:ok, castle} = CastleDb.by_id(castle_id)
    hired = CastleStore.guardians(castle_id)

    castle.guardians
    |> Enum.with_index()
    |> Enum.map(fn {slot_def, slot} ->
      %{slot: slot, type: slot_def.type, hired?: slot in hired}
    end)
  end

  @doc """
  Validates hiring `slot` at `castle_id` for the attached player's guild,
  without hiring it. Raises on a detached ctx.
  """
  @spec castle_guardian_hire_check(Ctx.t(), non_neg_integer(), 0..7) ::
          :ok | {:error, :not_owner | :research_required | :invalid_slot | :already_hired}
  def castle_guardian_hire_check(%Ctx{game_state: nil}, _castle_id, _slot),
    do: no_player!("castle_guardian_hire_check/3")

  def castle_guardian_hire_check(%Ctx{game_state: gs}, castle_id, slot) do
    Guardians.hire_check(castle_id, slot, gs.guild_id)
  end

  @doc """
  Hires `slot` at `castle_id` for the attached player's guild. Halts with the
  rejection reason (`:not_owner`, `:research_required`, `:invalid_slot`,
  `:already_hired`) on failure; returns `ctx` unchanged on success.
  """
  @spec castle_hire_guardian(Ctx.t(), non_neg_integer(), 0..7) :: Ctx.t()
  def castle_hire_guardian(%Ctx{status: {:error, _}} = ctx, _castle_id, _slot), do: ctx

  def castle_hire_guardian(%Ctx{game_state: nil} = ctx, _castle_id, _slot),
    do: Ctx.halt(ctx, :no_player)

  def castle_hire_guardian(%Ctx{game_state: gs} = ctx, castle_id, slot) do
    case Guardians.hire(castle_id, slot, gs.guild_id) do
      :ok -> ctx
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc "Whether `castle_id`'s Kafra service is currently hired."
  @spec castle_kafra_hired?(Ctx.t(), non_neg_integer()) :: boolean()
  def castle_kafra_hired?(%Ctx{}, castle_id), do: Services.kafra_hired?(castle_id)

  @doc """
  Validates hiring `castle_id`'s Kafra for the attached player's guild,
  without hiring it. Raises on a detached ctx.
  """
  @spec castle_kafra_hire_check(Ctx.t(), non_neg_integer()) ::
          :ok | {:error, :not_owner | :contract_required | :already_hired}
  def castle_kafra_hire_check(%Ctx{game_state: nil}, _castle_id),
    do: no_player!("castle_kafra_hire_check/2")

  def castle_kafra_hire_check(%Ctx{game_state: gs}, castle_id) do
    Services.hire_check(castle_id, gs.guild_id)
  end

  @doc """
  Hires `castle_id`'s Kafra for the attached player's guild. Halts with the
  rejection reason (`:not_owner`, `:contract_required`, `:already_hired`) on
  failure; returns `ctx` unchanged on success.
  """
  @spec castle_hire_kafra(Ctx.t(), non_neg_integer()) :: Ctx.t()
  def castle_hire_kafra(%Ctx{status: {:error, _}} = ctx, _castle_id), do: ctx
  def castle_hire_kafra(%Ctx{game_state: nil} = ctx, _castle_id), do: Ctx.halt(ctx, :no_player)

  def castle_hire_kafra(%Ctx{game_state: gs} = ctx, castle_id) do
    case Services.hire_kafra(castle_id, gs.guild_id) do
      :ok -> ctx
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Fires `castle_id`'s Kafra for the attached player's guild. Halts with the
  rejection reason (`:not_owner`, `:not_hired`) on failure; returns `ctx`
  unchanged on success.
  """
  @spec castle_fire_kafra(Ctx.t(), non_neg_integer()) :: Ctx.t()
  def castle_fire_kafra(%Ctx{status: {:error, _}} = ctx, _castle_id), do: ctx
  def castle_fire_kafra(%Ctx{game_state: nil} = ctx, _castle_id), do: Ctx.halt(ctx, :no_player)

  def castle_fire_kafra(%Ctx{game_state: gs} = ctx, castle_id) do
    case Services.fire_kafra(castle_id, gs.guild_id) do
      :ok -> ctx
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @spec invested_field(Economy.kind()) :: :invested_economy | :invested_defense
  defp invested_field(:economy), do: :invested_economy
  defp invested_field(:defense), do: :invested_defense
end

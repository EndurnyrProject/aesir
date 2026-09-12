defmodule Aesir.ZoneServer.Mmo.Woe.Services do
  @moduledoc """
  Hires, fires, and syncs each castle's Kafra service, and refreshes a
  castle's guild flags after conquest.

  The Kafra placement (one per castle, `unique_name: "Kafra Employee#<castle
  map>"`) is always registered; visibility is toggled through
  `Npc.Session.set_enabled/2` rather than spawning or despawning it. Hiring
  is gated on the owning guild's Kafra Contract skill, mirroring
  `Aesir.ZoneServer.Mmo.Woe.Guardians`'s Guardian Research gate. Conquest
  always revokes the Kafra (the new owner must hire it again) and
  rebroadcasts the conquered castle's outside and inside flags so nearby
  clients see the new owner's emblem.
  """

  require Logger

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Content.Npc.Woe.FlagOwner
  alias Aesir.ZoneServer.Content.Npc.Woe.InsideFlag
  alias Aesir.ZoneServer.Content.Npc.Woe.OutsideFlag
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Npc.Packets, as: NpcPackets
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Unit.Broadcast

  @contract_skill_id 10_001
  @kafra_hire_cost 10_000

  @doc """
  Zeny cost to hire a castle's Kafra.
  """
  @spec kafra_hire_cost() :: pos_integer()
  def kafra_hire_cost, do: @kafra_hire_cost

  @doc """
  Whether `castle_id`'s Kafra service is currently hired.
  """
  @spec kafra_hired?(non_neg_integer()) :: boolean()
  def kafra_hired?(castle_id), do: CastleStore.kafra?(castle_id)

  @doc """
  Validates hiring the Kafra at `castle_id` for `guild_id`.

  Fails, in order, with `:not_owner` (the guild does not hold the castle),
  `:contract_required` (the guild has no Kafra Contract skill learned), or
  `:already_hired` (the Kafra is already hired). `:ok` otherwise.
  """
  @spec hire_check(non_neg_integer(), non_neg_integer() | nil) ::
          :ok | {:error, :not_owner | :contract_required | :already_hired}
  def hire_check(castle_id, guild_id) do
    cond do
      CastleStore.owner(castle_id) != guild_id ->
        {:error, :not_owner}

      not contracted?(guild_id) ->
        {:error, :contract_required}

      CastleStore.kafra?(castle_id) ->
        {:error, :already_hired}

      true ->
        :ok
    end
  end

  @doc """
  Hires the Kafra at `castle_id` for `guild_id`: on success, marks it hired
  (stored, persisted) and enables its placement.
  """
  @spec hire_kafra(non_neg_integer(), non_neg_integer() | nil) :: :ok | {:error, atom()}
  def hire_kafra(castle_id, guild_id) do
    case hire_check(castle_id, guild_id) do
      :ok ->
        CastleStore.put_kafra(castle_id, true)
        Persistence.persist_kafra(castle_id, true)
        set_kafra_enabled(castle_id, true)
        :ok

      error ->
        error
    end
  end

  @doc """
  Fires the Kafra at `castle_id` for `guild_id`: `:not_owner` when the guild
  does not hold the castle, `:not_hired` when the Kafra is not hired.
  On success, reverses `hire_kafra/2`.
  """
  @spec fire_kafra(non_neg_integer(), non_neg_integer() | nil) ::
          :ok | {:error, :not_owner | :not_hired}
  def fire_kafra(castle_id, guild_id) do
    case fire_check(castle_id, guild_id) do
      :ok ->
        CastleStore.put_kafra(castle_id, false)
        Persistence.persist_kafra(castle_id, false)
        set_kafra_enabled(castle_id, false)
        :ok

      error ->
        error
    end
  end

  @doc """
  Applies conquest to `castle`'s services: revokes the Kafra (the new owner
  must hire it again) and refreshes the castle's guild flags for nearby
  clients.
  """
  @spec on_conquest(Castle.t()) :: :ok
  def on_conquest(%Castle{id: castle_id} = castle) do
    CastleStore.put_kafra(castle_id, false)
    Persistence.persist_kafra(castle_id, false)
    set_kafra_enabled(castle_id, false)
    refresh_flags(castle)
  end

  @doc """
  Syncs every castle's Kafra placement visibility from its stored flag.

  Called once at boot, after `CastleStore` is hydrated from the persisted
  rows.
  """
  @spec sync_all() :: :ok
  def sync_all do
    Enum.each(CastleDb.all(), fn castle ->
      set_kafra_enabled(castle.id, CastleStore.kafra?(castle.id))
    end)

    :ok
  end

  @doc """
  Rebroadcasts a spawn packet for every outside and inside flag belonging to
  `castle`, so nearby clients pick up the new owner's emblem.
  """
  @spec refresh_flags(Castle.t()) :: :ok
  def refresh_flags(%Castle{map: map}) do
    NpcRegistry.entries()
    |> Enum.filter(&castle_flag?(&1, map))
    |> Enum.each(&broadcast_flag/1)

    :ok
  end

  @spec castle_flag?(NpcRegistry.entry(), String.t()) :: boolean()
  defp castle_flag?({module, placement}, map) when module in [OutsideFlag, InsideFlag] do
    FlagOwner.castle_map(placement) == {:ok, map}
  end

  defp castle_flag?(_entry, _map), do: false

  @spec broadcast_flag(NpcRegistry.entry()) :: :ok
  defp broadcast_flag({_module, placement} = entry) do
    Broadcast.to_in_range(
      placement.map,
      placement.x,
      placement.y,
      Config.view_range(),
      NpcPackets.spawn_packet(entry)
    )
  end

  @spec fire_check(non_neg_integer(), non_neg_integer() | nil) ::
          :ok | {:error, :not_owner | :not_hired}
  defp fire_check(castle_id, guild_id) do
    cond do
      CastleStore.owner(castle_id) != guild_id ->
        {:error, :not_owner}

      not CastleStore.kafra?(castle_id) ->
        {:error, :not_hired}

      true ->
        :ok
    end
  end

  @spec set_kafra_enabled(non_neg_integer(), boolean()) :: :ok
  defp set_kafra_enabled(castle_id, enabled?) do
    case CastleDb.by_id(castle_id) do
      {:ok, castle} -> set_kafra_enabled_for_map(castle.map, enabled?)
      :error -> :ok
    end
  end

  @spec set_kafra_enabled_for_map(String.t(), boolean()) :: :ok
  defp set_kafra_enabled_for_map(map, enabled?) do
    case kafra_gid(map) do
      {:ok, gid} -> NpcSession.set_enabled(gid, enabled?)
      :error -> :ok
    end
  end

  @spec kafra_gid(String.t()) :: {:ok, non_neg_integer()} | :error
  defp kafra_gid(map) do
    case NpcRegistry.by_name("Kafra Employee#" <> map) do
      [{_module, placement} | _rest] ->
        {:ok, NpcRegistry.entity_id(placement)}

      [] ->
        Logger.warning("No Kafra placement registered for castle map #{map}")
        :error
    end
  end

  @spec contracted?(non_neg_integer() | nil) :: boolean()
  defp contracted?(guild_id) do
    case GuildManager.get(guild_id) do
      {:ok, guild} -> GuildState.skill_level(guild, @contract_skill_id) >= 1
      {:error, :not_found} -> false
    end
  end
end

defmodule Aesir.ZoneServer.Mmo.Woe.Guardians do
  @moduledoc """
  Hires, scales, spawns, despawns, and releases WoE castle guardians.

  Each castle has eight guardian slots (defined by the castle DB). A slot is
  hired once for `@hire_cost` zeny, gated on the owning guild's Guardian
  Research skill, and stays hired across sieges until the castle falls to an
  unresearched (or guildless) conqueror. Hired slots come alive only while
  the castle is under siege; `Strengthen Guardians` scales a live guardian's
  HP, DEF/MDEF, ATK, and attack speed by the owning guild's skill level.
  """

  require Logger

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Economy
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @hire_cost 10_000
  @research_skill_id 10_002
  @guardup_skill_id 10_003
  @mob_ids %{archer: 1285, knight: 1286, soldier: 1287}

  @doc """
  Zeny cost to hire one guardian slot.
  """
  @spec hire_cost() :: pos_integer()
  def hire_cost, do: @hire_cost

  @doc """
  Validates hiring slot `slot` at `castle_id` for `guild_id`.

  Fails, in order, with `:not_owner` (the guild does not hold the castle),
  `:research_required` (the guild has no Guardian Research skill learned),
  `:invalid_slot` (not an integer in `0..7`), or `:already_hired` (the slot
  is already in the castle's hired list). `:ok` otherwise.
  """
  @spec hire_check(non_neg_integer(), term(), non_neg_integer() | nil) ::
          :ok | {:error, :not_owner | :research_required | :invalid_slot | :already_hired}
  def hire_check(castle_id, slot, guild_id) do
    cond do
      CastleStore.owner(castle_id) != guild_id ->
        {:error, :not_owner}

      not researched?(guild_id) ->
        {:error, :research_required}

      not (is_integer(slot) and slot in 0..7) ->
        {:error, :invalid_slot}

      slot in CastleStore.guardians(castle_id) ->
        {:error, :already_hired}

      true ->
        :ok
    end
  end

  @doc """
  Hires slot `slot` at `castle_id` for `guild_id`: on success, adds the slot
  to the castle's hired list (stored sorted, persisted), and when the castle
  is currently under siege, spawns it immediately.
  """
  @spec hire(non_neg_integer(), 0..7, non_neg_integer()) ::
          :ok | {:error, :not_owner | :research_required | :invalid_slot | :already_hired}
  def hire(castle_id, slot, guild_id) do
    case hire_check(castle_id, slot, guild_id) do
      :ok ->
        guardians = Enum.sort([slot | CastleStore.guardians(castle_id)])
        CastleStore.put_guardians(castle_id, guardians)
        Persistence.persist_guardians(castle_id, guardians)

        if CastleStore.get(castle_id).siege_active? do
          {:ok, castle} = CastleDb.by_id(castle_id)
          spawn_slot(castle, slot)
        end

        :ok

      error ->
        error
    end
  end

  @doc """
  Spawn options for a guardian in `slot` at `defense` under `guardup_level`.

  Below level 1, `Strengthen Guardians` grants no scaling: only `guild_id` is
  set. From level 1, HP, DEF/MDEF, ATK, and attack-speed bonuses apply on top
  of the mob's base stats.
  """
  @spec summon_opts(Castle.slot(), 0..100, 0..3, non_neg_integer(), GameMode.t()) :: keyword()
  def summon_opts(_slot, _defense, guardup_level, guild_id, _mode) when guardup_level < 1 do
    [guild_id: guild_id]
  end

  def summon_opts(slot, defense, guardup_level, guild_id, mode) do
    {:ok, mob} = Mobs.by_id(Map.fetch!(@mob_ids, slot.type))
    flat = div(defense + 2, 3)

    [
      guild_id: guild_id,
      hp_override: mob.hp + Economy.hp_bonus(defense, mode) + 1_000 * defense,
      stat_bonus: %{
        def: flat,
        mdef: flat,
        atk: 2 * guardup_level + 8,
        aspd_rate: 2 * guardup_level + 3
      }
    ]
  end

  @doc """
  Spawns every hired slot of `castle` not already live. A castle with no
  owner spawns nothing.
  """
  @spec spawn_all(Castle.t()) :: :ok
  def spawn_all(%Castle{id: castle_id} = castle) do
    case CastleStore.owner(castle_id) do
      nil ->
        :ok

      _guild_id ->
        live = live_slots(castle_id)

        castle_id
        |> CastleStore.guardians()
        |> Enum.reject(&(&1 in live))
        |> Enum.each(&spawn_slot(castle, &1))

        :ok
    end
  end

  @doc """
  Spawns one guardian `slot` of `castle`, scaled from the owner's defense
  level and `Strengthen Guardians` skill level, and records the live unit id.

  Re-checks the castle's live siege flag first and summons nothing when the
  siege is no longer active, closing the race where the siege ends between a
  caller reading the flag and this call reaching the map.

  A summon failure logs a warning and leaves the slot empty for a later
  attempt.
  """
  @spec spawn_slot(Castle.t(), 0..7) :: :ok
  def spawn_slot(%Castle{id: castle_id, map: map, guardians: slots}, slot) do
    if CastleStore.get(castle_id).siege_active? do
      owner = CastleStore.owner(castle_id)
      defense = CastleStore.economy(castle_id).defense
      slot_def = Enum.at(slots, slot)
      mob_id = Map.fetch!(@mob_ids, slot_def.type)
      {x, y} = slot_def.cell
      opts = summon_opts(slot_def, defense, guardup_level(owner), owner, GameMode.mode())

      case Coordinator.summon_mob(map, mob_id, x, y, opts) do
        {:ok, unit_id} ->
          :ets.insert(table_for(:castle_guardians), {{castle_id, slot}, unit_id})
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to summon guardian for castle #{castle_id} slot #{slot} on #{map}: #{inspect(reason)}"
          )

          :ok
      end
    else
      :ok
    end
  end

  @doc """
  Despawns every live guardian of `castle` and clears its live-slot rows.
  """
  @spec despawn_all(Castle.t()) :: :ok
  def despawn_all(%Castle{id: castle_id, map: map}) do
    table = table_for(:castle_guardians)

    table
    |> :ets.select([{{{castle_id, :"$1"}, :"$2"}, [], [:"$2"]}])
    |> Enum.each(&despawn_unit(map, &1))

    :ets.match_delete(table, {{castle_id, :_}, :_})

    :ok
  end

  @spec despawn_unit(String.t(), non_neg_integer()) :: :ok
  defp despawn_unit(map, unit_id) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} ->
        UnitRegistry.unregister_unit(:mob, unit_id)
        MobSupervisor.terminate_mob(map, pid)
        :ok

      {:error, :not_found} ->
        :ok
    end
  end

  @doc """
  Frees the live slot held by `unit_id`, if any.
  """
  @spec release(non_neg_integer()) :: {:ok, {non_neg_integer(), 0..7}} | :error
  def release(unit_id) do
    case :ets.match_object(table_for(:castle_guardians), {{:_, :_}, unit_id}) do
      [{{castle_id, slot}, ^unit_id}] ->
        :ets.delete(table_for(:castle_guardians), {castle_id, slot})
        {:ok, {castle_id, slot}}

      [] ->
        :error
    end
  end

  @doc """
  Un-hires `slot` at `castle_id`: removes it from the hired list and
  persists the change. Does not despawn a live unit in the slot.
  """
  @spec clear_slot(non_neg_integer(), 0..7) :: :ok
  def clear_slot(castle_id, slot) do
    guardians = List.delete(CastleStore.guardians(castle_id), slot)
    CastleStore.put_guardians(castle_id, guardians)
    Persistence.persist_guardians(castle_id, guardians)
  end

  @doc """
  Applies conquest to `castle`'s guardians: always despawns the previous
  owner's live guardians, then either respawns the same hired slots for
  `new_guild_id` when it has learned Guardian Research, or clears the hired
  list when it has not (or does not exist).
  """
  @spec on_conquest(Castle.t(), non_neg_integer()) :: :ok
  def on_conquest(%Castle{id: castle_id} = castle, new_guild_id) do
    despawn_all(castle)

    if researched?(new_guild_id) do
      spawn_all(castle)
    else
      CastleStore.put_guardians(castle_id, [])
      Persistence.persist_guardians(castle_id, [])
    end

    :ok
  end

  @doc """
  Live guardian slots currently filled for `castle_id`.
  """
  @spec live_slots(non_neg_integer()) :: [0..7]
  def live_slots(castle_id) do
    :ets.select(table_for(:castle_guardians), [{{{castle_id, :"$1"}, :_}, [], [:"$1"]}])
  end

  @spec researched?(non_neg_integer() | nil) :: boolean()
  defp researched?(guild_id) do
    case GuildManager.get(guild_id) do
      {:ok, guild} -> GuildState.skill_level(guild, @research_skill_id) >= 1
      {:error, :not_found} -> false
    end
  end

  @spec guardup_level(non_neg_integer() | nil) :: 0..3
  defp guardup_level(nil), do: 0

  defp guardup_level(guild_id) do
    case GuildManager.get(guild_id) do
      {:ok, guild} -> GuildState.skill_level(guild, @guardup_skill_id)
      {:error, :not_found} -> 0
    end
  end
end

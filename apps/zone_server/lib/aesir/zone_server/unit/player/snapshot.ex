defmodule Aesir.ZoneServer.Unit.Player.Snapshot do
  @moduledoc """
  Builds full-state area-of-interest snapshots for a single player (design Part 5).

  A snapshot is the unreliable, per-tick view of where every entity in the
  player's `view_range` currently is. It carries only motion (`x`/`y`/`dir`/
  `move_state`) plus `hp_pct` for smooth nearby health bars; entity *existence*
  rides the reliable World channel, so a lost or late snapshot is simply
  superseded by the next one.

  `build/1` is pure: it reads the spatial index and unit registry (ETS) and
  returns a `%Aesir.Net.Snapshot{}`. It performs no sends, so the caller decides
  how the message is delivered (`PlayerSession` routes it to the `:snapshots`
  datagram channel). The querying player is included so the client has its own
  authoritative position to reconcile its prediction against.

  ## Datagram size-splitting

  A QUIC datagram cannot be IP-fragmented (design Part 5), so a snapshot must
  never exceed the path's safe datagram size. `build_chunks/1` orders the AoI
  entities nearest-first (the same Manhattan metric the AoI filter uses) and
  greedily packs them into multiple self-contained `%Snapshot{}` chunks, each
  within `@datagram_budget`, all sharing one `server_tick`. Datagrams arrive
  independently, so every chunk is valid on its own.

  Far entities that do not fit within `@max_chunks` chunks are decimated (dropped)
  and the count is logged — no silent caps. The crowded-town entity cap is a
  tuning knob (`@max_chunks`), not a protocol change.
  """

  require Logger

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.Envelope
  alias Aesir.Net.Snapshot, as: NetSnapshot
  alias Aesir.Net.SnapshotEntity
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @standing 0
  @moving 1

  # Conservative safe path-MTU datagram budget in bytes (design Part 5: ~1200 B);
  # confirm against `quic:datagram_max_size/1` at integration time.
  @datagram_budget 1_200
  # Crowded-town tuning knob: at most this many datagrams per snapshot tick.
  @max_chunks 8
  # The Snapshot rides inside the Envelope oneof as a length-delimited field whose
  # length is a varint. The empty-snapshot measurement counts a 1-byte prefix, but a
  # full chunk (body > 127 B) needs a 2-byte prefix; reserve slack so the additive
  # budget never undershoots by that growth. Chunk bodies stay < 16_384 B, so the
  # prefix never exceeds 2 bytes and this slack is always sufficient.
  @length_prefix_slack 3

  @doc "The per-datagram size budget in bytes (channel byte + Envelope payload)."
  @spec datagram_budget() :: pos_integer()
  def datagram_budget, do: @datagram_budget

  @doc "Maximum number of datagrams a single snapshot tick may span."
  @spec max_chunks() :: pos_integer()
  def max_chunks, do: @max_chunks

  @doc """
  Builds the full-state snapshot for the player whose `game_state` is given.

  Queries `SpatialIndex.get_all_units_in_range/4` for every `{unit_type,
  unit_id}` in the player's `view_range`, reads each unit's registered state and
  maps it to a `%Aesir.Net.SnapshotEntity{}`. All entities share one
  `server_tick`. May exceed the datagram budget — use `build_chunks/1` for the
  size-split form sent over the wire.
  """
  @spec build(PlayerState.t()) :: NetSnapshot.t()
  def build(%PlayerState{} = game_state) do
    entities =
      game_state.map_name
      |> SpatialIndex.get_all_units_in_range(game_state.x, game_state.y, game_state.view_range)
      |> Enum.flat_map(&entity_for_unit/1)

    %NetSnapshot{server_tick: ServerTick.now(), entities: entities}
  end

  @doc """
  Builds the AoI snapshot split into datagram-sized chunks.

  Entities are ordered nearest-first (Manhattan distance from the player, the
  metric the AoI filter uses) and greedily packed into `%Snapshot{}` chunks whose
  encoded datagram stays within `datagram_budget/0`. Every chunk carries the same
  `server_tick`, so each is self-contained. Entities that overflow `max_chunks/0`
  chunks are dropped and the count is logged.
  """
  @spec build_chunks(PlayerState.t()) :: [NetSnapshot.t()]
  def build_chunks(%PlayerState{} = game_state) do
    server_tick = ServerTick.now()

    entities =
      game_state.map_name
      |> SpatialIndex.get_all_units_in_range(game_state.x, game_state.y, game_state.view_range)
      |> Enum.flat_map(&entity_for_unit/1)
      |> Enum.sort_by(&manhattan(&1, game_state.x, game_state.y))

    {chunks, dropped} = pack(entities, server_tick)
    log_decimation(dropped)

    chunks
  end

  @spec pack([SnapshotEntity.t()], non_neg_integer()) ::
          {[NetSnapshot.t()], non_neg_integer()}
  defp pack(entities, server_tick) do
    overhead = empty_snapshot_size(server_tick)
    entity_budget = @datagram_budget - overhead - @length_prefix_slack

    {chunks, current, _used} =
      Enum.reduce(entities, {[], [], 0}, fn entity, {chunks, current, used} ->
        cost = entity_size(entity)
        add_entity(entity, cost, entity_budget, chunks, current, used)
      end)

    chunks = finalize_chunks(chunks, current)
    kept = Enum.take(chunks, @max_chunks)
    dropped = chunks |> Enum.drop(@max_chunks) |> List.flatten() |> length()

    {Enum.map(kept, &%NetSnapshot{server_tick: server_tick, entities: &1}), dropped}
  end

  @spec add_entity(
          SnapshotEntity.t(),
          non_neg_integer(),
          integer(),
          [[SnapshotEntity.t()]],
          [SnapshotEntity.t()],
          non_neg_integer()
        ) :: {[[SnapshotEntity.t()]], [SnapshotEntity.t()], non_neg_integer()}
  defp add_entity(entity, cost, _entity_budget, chunks, [], _used) do
    {chunks, [entity], cost}
  end

  defp add_entity(entity, cost, entity_budget, chunks, current, used)
       when used + cost > entity_budget do
    {[Enum.reverse(current) | chunks], [entity], cost}
  end

  defp add_entity(entity, cost, _entity_budget, chunks, current, used) do
    {chunks, [entity | current], used + cost}
  end

  @spec finalize_chunks([[SnapshotEntity.t()]], [SnapshotEntity.t()]) :: [[SnapshotEntity.t()]]
  defp finalize_chunks(chunks, []), do: Enum.reverse(chunks)
  defp finalize_chunks(chunks, current), do: Enum.reverse([Enum.reverse(current) | chunks])

  @spec empty_snapshot_size(non_neg_integer()) :: pos_integer()
  defp empty_snapshot_size(server_tick) do
    # 1 channel-id byte + the Envelope wrapping a zero-entity Snapshot, measured
    # with the maximum `seq` varint so the real datagram (any smaller seq) is
    # guaranteed to stay within budget.
    1 + envelope_size(%NetSnapshot{server_tick: server_tick, entities: []})
  end

  @spec entity_size(SnapshotEntity.t()) :: pos_integer()
  defp entity_size(entity) do
    one = envelope_size(%NetSnapshot{server_tick: 0, entities: [entity]})
    one - envelope_size(%NetSnapshot{server_tick: 0, entities: []})
  end

  @spec envelope_size(NetSnapshot.t()) :: pos_integer()
  defp envelope_size(%NetSnapshot{} = snap) do
    {:ok, _iodata, size} = Envelope.encode(%Envelope{seq: 0xFFFF_FFFF, body: {:snapshot, snap}})
    size
  end

  @spec log_decimation(non_neg_integer()) :: :ok
  defp log_decimation(0), do: :ok

  defp log_decimation(dropped) do
    Logger.warning(
      "snapshot datagram cap reached: decimated #{dropped} far AoI entities (max_chunks=#{@max_chunks})"
    )
  end

  @spec manhattan(SnapshotEntity.t(), integer(), integer()) :: non_neg_integer()
  defp manhattan(%SnapshotEntity{x: x, y: y}, px, py), do: abs(x - px) + abs(y - py)

  @spec entity_for_unit({atom(), integer()}) :: [SnapshotEntity.t()]
  defp entity_for_unit({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, unit_state, _pid}} -> [to_entity(unit_id, unit_state)]
      {:error, :not_found} -> []
    end
  end

  @spec to_entity(integer(), PlayerState.t() | MobState.t()) :: SnapshotEntity.t()
  defp to_entity(unit_id, %PlayerState{} = state) do
    %{hp: hp} = state.stats.current_state
    %{max_hp: max_hp} = state.stats.derived_stats
    build_entity(unit_id, state, hp, max_hp)
  end

  defp to_entity(unit_id, %MobState{hp: hp, max_hp: max_hp} = state) do
    build_entity(unit_id, state, hp, max_hp)
  end

  @spec build_entity(integer(), PlayerState.t() | MobState.t(), integer(), integer()) ::
          SnapshotEntity.t()
  defp build_entity(unit_id, state, hp, max_hp) do
    %SnapshotEntity{
      id: unit_id,
      x: state.x,
      y: state.y,
      dir: state.dir,
      move_state: move_state(state.movement_state),
      hp_pct: hp_pct(hp, max_hp)
    }
  end

  @spec move_state(atom()) :: 0 | 1
  defp move_state(:moving), do: @moving
  defp move_state(_), do: @standing

  @spec hp_pct(integer(), integer()) :: 0..100
  defp hp_pct(_hp, max_hp) when max_hp <= 0, do: 0
  defp hp_pct(hp, max_hp), do: round(hp / max_hp * 100)
end

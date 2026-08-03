defmodule Aesir.ZoneServer.Unit.SnapshotBuilder do
  @moduledoc """
  Reusable construction of delta `%Aesir.Net.Snapshot{}` datagram chunks from an
  arbitrary entity list (design Part 1, Part 3).

  Two concerns live here so the per-map delta broadcaster
  (`Aesir.ZoneServer.Map.Coordinator`) can use them:

    * `entities_for/1` turns a list of `{unit_type, unit_id}` into
      `%Aesir.Net.SnapshotEntity{}` records by reading the unit registry, skipping
      units that are no longer registered.
    * `chunks_for/3` orders those entities nearest-first and greedily packs them
      into datagram-sized `%Aesir.Net.Snapshot{}` chunks.

  ## Datagram size-splitting

  A QUIC datagram cannot be IP-fragmented, so a snapshot must never exceed the
  path's safe datagram size. `chunks_for/3` orders the entities nearest-first (the
  same Manhattan metric the AoI filter uses) and greedily packs them into multiple
  self-contained `%Snapshot{}` chunks, each within `datagram_budget/0`, all sharing
  one `server_tick`. Datagrams arrive independently, so every chunk is valid on its
  own.

  Far entities that do not fit within `max_chunks/0` chunks are decimated (dropped)
  and the count is logged — no silent caps. The crowded-town entity cap is a tuning
  knob (`max_chunks/0`), not a protocol change.
  """

  require Logger

  alias Aesir.Net.Envelope
  alias Aesir.Net.Snapshot, as: NetSnapshot
  alias Aesir.Net.SnapshotEntity
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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
  Maps a list of `{unit_type, unit_id}` to `%Aesir.Net.SnapshotEntity{}` records.

  Reads each unit's registered state from `UnitRegistry.get_unit/2` and maps it to
  a `%SnapshotEntity{id, x, y, dir, move_state, hp_pct}`. Units that are no longer
  registered (`{:error, :not_found}`) are skipped.
  """
  @spec entities_for([{atom(), integer()}]) :: [SnapshotEntity.t()]
  def entities_for(units) do
    Enum.flat_map(units, &entity_for_unit/1)
  end

  @doc """
  Packs entities into datagram-sized `%Aesir.Net.Snapshot{}` chunks.

  Entities are ordered nearest-first (Manhattan distance from `{center_x,
  center_y}`, the metric the AoI filter uses) and greedily packed into
  `%Snapshot{}` chunks whose encoded datagram stays within `datagram_budget/0`.
  Every chunk carries the same `server_tick`, so each is self-contained. Entities
  that overflow `max_chunks/0` chunks are dropped and the count is logged.
  """
  @spec chunks_for([SnapshotEntity.t()], {integer(), integer()}, non_neg_integer()) ::
          [NetSnapshot.t()]
  def chunks_for(entities, {center_x, center_y}, server_tick) do
    sorted = Enum.sort_by(entities, &manhattan(&1, center_x, center_y))

    {chunks, dropped} = pack(sorted, server_tick)
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

  @spec to_entity(integer(), PlayerState.t() | MobState.t() | HomunculusState.t()) ::
          SnapshotEntity.t()
  defp to_entity(unit_id, %PlayerState{} = state) do
    %{hp: hp} = state.stats.current_state
    %{max_hp: max_hp} = state.stats.derived_stats
    build_entity(unit_id, state, hp, max_hp)
  end

  defp to_entity(unit_id, %MobState{hp: hp, max_hp: max_hp} = state) do
    build_entity(unit_id, state, hp, max_hp)
  end

  defp to_entity(unit_id, %HomunculusState{hp: hp, max_hp: max_hp} = state) do
    build_entity(unit_id, state, hp, max_hp)
  end

  @spec build_entity(
          integer(),
          PlayerState.t() | MobState.t() | HomunculusState.t(),
          integer(),
          integer()
        ) ::
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

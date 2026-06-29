defmodule Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay do
  @moduledoc """
  Turns status lifecycle events into client wire messages.

  This is the only module in the status system that knows about the display
  protocol. The interpreter calls `on_applied/4` on a genuine apply and
  `on_removed/4` after a removal; spawn/visibility code calls `spawn_state/2`
  and `active_icons/2` to backfill a newly-visible unit.

  Three independent rAthena display mechanisms are covered:

    - **EFST icon bar** — `StatusChange` (apply/remove), driven by `Definition.icon`.
    - **Sprite ailment state** — `UnitStateChange`, the unit's aggregate
      `opt1`/`opt2`/`option`/`opt3` over all active statuses.
    - **One-shot effect** — `Unit.SpecialEffect`, fired when a status declares
      `on_apply_effect`.

  Best-effort: it resolves a unit's position, broadcasts to its area, and never
  raises or blocks gameplay. An atom that fails to resolve to a wire id is
  skipped with a warning.
  """

  require Logger

  alias Aesir.Net.StatusChange
  alias Aesir.Net.UnitStateChange
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.Opt1
  alias Aesir.ZoneServer.Mmo.Opt2
  alias Aesir.ZoneServer.Mmo.Opt3
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @typedoc "Aggregate sprite-state ids for a unit, as carried in `UnitSpawn`."
  @type spawn_state :: %{
          body_state: non_neg_integer(),
          health_state: non_neg_integer(),
          effect_state: non_neg_integer(),
          virtue: non_neg_integer()
        }

  @doc """
  Emits the display messages for a genuine status apply.

  In order: the EFST icon (`StatusChange{on: true}`) if the status declares one,
  the recomputed sprite-state aggregate (`UnitStateChange`) if the status carries
  any opt field, and the `on_apply_effect` one-shot if declared.
  """
  @spec on_applied(Unit.unit_type(), integer(), atom(), StatusEntry.t()) :: :ok
  def on_applied(unit_type, unit_id, status_id, %StatusEntry{} = instance) do
    definition = Registry.get_definition(status_id)

    broadcast_icon(unit_type, unit_id, definition, instance, true)
    broadcast_aggregate_if_opt(unit_type, unit_id, definition)
    play_on_apply_effect(unit_type, unit_id, definition)

    :ok
  end

  @doc """
  Emits the display messages for a status removal.

  Must be called after the instance is deleted from storage, so the recomputed
  aggregate already reflects the removal. Sends `StatusChange{on: false}` for an
  icon status and a refreshed `UnitStateChange` for an opt-bearing status.
  """
  @spec on_removed(Unit.unit_type(), integer(), atom(), StatusEntry.t()) :: :ok
  def on_removed(unit_type, unit_id, status_id, %StatusEntry{} = instance) do
    definition = Registry.get_definition(status_id)

    broadcast_icon(unit_type, unit_id, definition, instance, false)
    broadcast_aggregate_if_opt(unit_type, unit_id, definition)

    :ok
  end

  @doc """
  Returns the current sprite-state aggregate for a unit, for `build_unit_spawn`.
  """
  @spec spawn_state(Unit.unit_type(), integer()) :: spawn_state()
  def spawn_state(unit_type, unit_id) do
    aggregate(unit_type, unit_id)
  end

  @doc """
  Returns one `StatusChange{on: true}` message per active icon-bearing status,
  for the spawn-resync follow-up sent to a newly-visible observer.
  """
  @spec active_icons(Unit.unit_type(), integer()) :: [StatusChange.t()]
  def active_icons(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.flat_map(fn instance ->
      case Registry.get_definition(instance.type) do
        %{icon: icon} when not is_nil(icon) ->
          List.wrap(icon_message(unit_id, icon, instance, true))

        _ ->
          []
      end
    end)
  end

  defp broadcast_icon(_unit_type, _unit_id, %{icon: nil}, _instance, _on), do: :ok
  defp broadcast_icon(_unit_type, _unit_id, nil, _instance, _on), do: :ok

  defp broadcast_icon(unit_type, unit_id, %{icon: icon}, instance, on) do
    case icon_message(unit_id, icon, instance, on) do
      nil -> :ok
      message -> broadcast_area(unit_type, unit_id, message)
    end
  end

  defp icon_message(unit_id, icon, instance, on) do
    case Efst.id(icon) do
      nil ->
        Logger.warning("StatusDisplay: unknown icon atom #{inspect(icon)}, skipping")
        nil

      efst ->
        {total_ms, remain_ms} = timers(instance)

        %StatusChange{
          unit_id: unit_id,
          efst: efst,
          on: on,
          total_ms: total_ms,
          remain_ms: remain_ms,
          val1: instance.val1,
          val2: instance.val2,
          val3: instance.val3
        }
    end
  end

  defp broadcast_aggregate_if_opt(unit_type, unit_id, definition) do
    if opt_bearing?(definition) do
      %{body_state: b, health_state: h, effect_state: e, virtue: v} =
        aggregate(unit_type, unit_id)

      packet = %UnitStateChange{
        unit_id: unit_id,
        body_state: b,
        health_state: h,
        effect_state: e,
        virtue: v
      }

      broadcast_area(unit_type, unit_id, packet)
    else
      :ok
    end
  end

  defp opt_bearing?(%{opt1: o1, opt2: o2, option: op, opt3: o3}) do
    not (is_nil(o1) and is_nil(o2) and is_nil(op) and is_nil(o3))
  end

  defp opt_bearing?(_), do: false

  defp play_on_apply_effect(_unit_type, _unit_id, %{on_apply_effect: nil}), do: :ok
  defp play_on_apply_effect(_unit_type, _unit_id, nil), do: :ok

  defp play_on_apply_effect(unit_type, unit_id, %{on_apply_effect: effect}) do
    SpecialEffect.play({unit_type, unit_id}, effect, :area)
    :ok
  end

  defp aggregate(unit_type, unit_id) do
    empty = %{body_state: 0, health_state: 0, effect_state: 0, virtue: 0}

    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.map(fn instance -> {instance, Registry.get_definition(instance.type)} end)
    |> Enum.reject(fn {_instance, definition} -> is_nil(definition) end)
    |> Enum.reduce(empty, &fold_state/2)
  end

  defp fold_state({instance, definition}, acc) do
    acc
    |> put_opt1(definition[:opt1])
    |> or_opt(:health_state, Opt2, definition[:opt2])
    |> or_opt(:effect_state, Option, definition[:option])
    |> or_opt(:effect_state, Option, dynamic_option(definition, instance))
    |> or_opt(:virtue, Opt3, definition[:opt3])
  end

  defp dynamic_option(%{module: module}, instance), do: module.dynamic_option(instance)
  defp dynamic_option(_definition, _instance), do: nil

  defp put_opt1(acc, nil), do: acc

  defp put_opt1(acc, atom) do
    case Opt1.id(atom) do
      nil ->
        Logger.warning("StatusDisplay: unknown opt1 atom #{inspect(atom)}, skipping")
        acc

      id ->
        %{acc | body_state: id}
    end
  end

  defp or_opt(acc, _key, _module, nil), do: acc

  defp or_opt(acc, key, module, atom) do
    case module.id(atom) do
      nil ->
        Logger.warning(
          "StatusDisplay: unknown #{inspect(module)} atom #{inspect(atom)}, skipping"
        )

        acc

      id ->
        Map.update!(acc, key, &Bitwise.bor(&1, id))
    end
  end

  defp timers(%StatusEntry{expires_at: nil}), do: {0, 0}

  defp timers(%StatusEntry{expires_at: expires_at, started_at: started_at}) do
    remain_ms = max(expires_at - System.monotonic_time(:millisecond), 0)
    elapsed_ms = max(System.system_time(:millisecond) - started_at, 0)
    {elapsed_ms + remain_ms, remain_ms}
  end

  defp broadcast_area(unit_type, unit_id, packet) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, map_name}} ->
        Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet, [])

      {:error, :not_found} ->
        Logger.debug("StatusDisplay: unit #{inspect({unit_type, unit_id})} has no position")
        :ok
    end
  end
end

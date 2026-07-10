defmodule Aesir.ZoneServer.Mmo.Skill.Unit.TickManager do
  @moduledoc """
  Single process driving all ground skill-unit groups.

  Mirrors `Aesir.ZoneServer.Mmo.StatusTickManager`: a central GenServer running a
  fixed sub-second tick that processes only the groups that are actually due. On
  each tick it runs `on_interval` for groups whose `next_tick_at <= now` and reaps
  groups whose `expires_at <= now` via `on_expire` + delete.

  Expiry never broadcasts a "disappear" packet in this layer: Storm Gust units are
  invisible and per-cell unit rendering is deferred to a later spec.
  """

  use GenServer
  require Logger

  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.GroundNuke
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  @tick_interval_ms 100

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Process.send_after(self(), :tick, @tick_interval_ms)
    Logger.info("Skill.Unit.TickManager started with #{@tick_interval_ms}ms interval")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    process_tick(System.monotonic_time(:millisecond))
    Process.send_after(self(), :tick, @tick_interval_ms)
    {:noreply, state}
  end

  @doc """
  Processes one tick at the given `now` timestamp.

  Extracted from the timer so the tick logic is driven directly in tests with a
  controlled `now` instead of relying on the 100ms cadence.

  The due and expired snapshots are taken up front, so a group that is both due
  and expired in the same tick is reaped at most once: the expire phase skips
  any group already deleted during the due phase.
  """
  @spec process_tick(integer()) :: :ok
  def process_tick(now) do
    due = Storage.get_due_groups(now)
    expired = Storage.get_expired_groups(now)

    Enum.each(due, &run_interval(&1, now))
    Enum.each(expired, &expire/1)
    :ok
  end

  defp run_interval(%Group{} = group, now) do
    with {:ok, module} <- handler_for(group) do
      case dispatch_interval(module, group, now) do
        {:ok, updated} ->
          Storage.update(%{updated | next_tick_at: now + updated.interval})

        {:expire, updated} ->
          module.on_expire(updated)
          Storage.delete(updated.group_id)
      end
    end
  end

  # Keeps the result typed as the behaviour's full union ({:ok, _} | {:expire, _}).
  # Calling `module.on_interval` directly narrows to the single registered module's
  # body and flags the framework's still-unused :expire branch as unreachable.
  @spec dispatch_interval(module(), Group.t(), integer()) ::
          {:ok, Group.t()} | {:expire, Group.t()}
  defp dispatch_interval(module, group, now), do: module.on_interval(group, now)

  defp expire(%Group{group_id: group_id} = group) do
    case Storage.get(group_id) do
      nil -> :ok
      _group -> reap(group)
    end
  end

  defp reap(%Group{group_id: group_id} = group) do
    with {:ok, module} <- handler_for(group) do
      module.on_expire(group)
    end

    Storage.delete(group_id)
  end

  # Mob-cast groups are not in the player skill catalog: they all dispatch to
  # the generic mob ground-nuke handler. Player groups resolve per-skill modules
  # through the catalog as before.
  defp handler_for(%Group{caster_type: :mob}), do: {:ok, GroundNuke}
  defp handler_for(%Group{skill_name: skill_name}), do: Catalog.ground_module_for(skill_name)
end

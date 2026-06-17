defmodule Aesir.ZoneServer.Mmo.SkillUnit.TickManager do
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

  alias Aesir.ZoneServer.Mmo.SkillUnit.Behaviors
  alias Aesir.ZoneServer.Mmo.SkillUnit.Group
  alias Aesir.ZoneServer.Mmo.SkillUnit.Storage

  @tick_interval_ms 100

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Process.send_after(self(), :tick, @tick_interval_ms)
    Logger.info("SkillUnit.TickManager started with #{@tick_interval_ms}ms interval")
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
  """
  @spec process_tick(integer()) :: :ok
  def process_tick(now) do
    now |> Storage.get_due_groups() |> Enum.each(&run_interval(&1, now))
    now |> Storage.get_expired_groups() |> Enum.each(&expire/1)
    :ok
  end

  defp run_interval(%Group{skill_name: skill_name} = group, now) do
    with {:ok, module} <- Behaviors.module_for(skill_name) do
      case module.on_interval(group, now) do
        {:ok, updated} ->
          Storage.update(%{updated | next_tick_at: now + updated.interval})

        {:expire, updated} ->
          module.on_expire(updated)
          Storage.delete(updated.group_id)
      end
    end
  end

  defp expire(%Group{skill_name: skill_name, group_id: group_id} = group) do
    with {:ok, module} <- Behaviors.module_for(skill_name) do
      module.on_expire(group)
    end

    Storage.delete(group_id)
  end
end

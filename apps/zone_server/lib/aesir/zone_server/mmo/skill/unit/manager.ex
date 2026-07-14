defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Manager do
  @moduledoc """
  Serializes every ground skill-unit mutation and drives interval/expiry ticks.

  Storage reads remain direct, while registration, callback updates, explicit
  state changes, and teardown pass through this process so the primary row and
  every secondary index change as one ordered operation.
  """

  use GenServer

  require Logger

  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.GroundNuke
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  @tick_interval 100

  @type server :: GenServer.server()
  @type mover :: {atom(), integer()}

  @doc "Starts the supervised skill-unit manager."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    case name do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc "Registers a fully prepared group before its placement is published."
  @spec register(Group.t()) :: :ok
  def register(%Group{} = group), do: register(default_server(), group)

  @doc false
  @spec register(server(), Group.t()) :: :ok
  def register(server, %Group{} = group), do: GenServer.call(server, {:register, group})

  @doc "Merges skill-owned state into a live group without resurrecting a deleted one."
  @spec update_state(non_neg_integer(), map()) :: :ok
  def update_state(group_id, state), do: update_state(default_server(), group_id, state)

  @doc false
  @spec update_state(server(), non_neg_integer(), map()) :: :ok
  def update_state(server, group_id, state) do
    GenServer.call(server, {:update_state, group_id, state})
  end

  @doc "Runs cleanup and destroys a live group."
  @spec destroy(non_neg_integer()) :: :ok
  def destroy(group_id), do: destroy(default_server(), group_id)

  @doc false
  @spec destroy(server(), non_neg_integer()) :: :ok
  def destroy(server, group_id), do: GenServer.call(server, {:destroy, group_id})

  @doc "Serially invokes a movement callback against the latest live group."
  @spec trigger(non_neg_integer(), mover(), :on_touch | :on_out) :: :ok
  def trigger(group_id, mover, callback), do: trigger(default_server(), group_id, mover, callback)

  @doc false
  @spec trigger(server(), non_neg_integer(), mover(), :on_touch | :on_out) :: :ok
  def trigger(server, group_id, mover, callback) when callback in [:on_touch, :on_out] do
    GenServer.call(server, {:trigger, group_id, mover, callback})
  end

  @doc "Processes one cadence tick using the configured clock."
  @spec tick(server()) :: :ok
  def tick(server \\ default_server()), do: GenServer.call(server, :tick)

  @doc false
  @spec tick(server(), integer()) :: :ok
  def tick(server, now), do: GenServer.call(server, {:tick, now})

  @impl true
  def init(opts) do
    state = %{
      clock: Keyword.get(opts, :clock, fn -> System.monotonic_time(:millisecond) end),
      schedule_tick: Keyword.get(opts, :schedule_tick, &Process.send_after(&1, :tick, &2)),
      tick_interval: Keyword.get(opts, :tick_interval, @tick_interval)
    }

    schedule_tick(state)
    Logger.info("Skill.Unit.Manager started with #{state.tick_interval}ms interval")
    {:ok, state}
  end

  @impl true
  def handle_call({:register, group}, _from, state) do
    {:reply, Storage.insert(group), state}
  end

  def handle_call({:update_state, group_id, new_state}, _from, state) do
    case Storage.get(group_id) do
      nil ->
        :ok

      %Group{state: current} = group ->
        Storage.update(%{group | state: Map.merge(current, new_state)})
    end

    {:reply, :ok, state}
  end

  def handle_call({:destroy, group_id}, _from, state) do
    if group = Storage.get(group_id), do: cleanup(group)
    {:reply, :ok, state}
  end

  def handle_call({:trigger, group_id, mover, callback}, _from, state) do
    if group = Storage.get(group_id), do: run_trigger(group, mover, callback)
    {:reply, :ok, state}
  end

  def handle_call(:tick, _from, state) do
    process_tick(state.clock.())
    {:reply, :ok, state}
  end

  def handle_call({:tick, now}, _from, state) do
    process_tick(now)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    process_tick(state.clock.())
    schedule_tick(state)
    {:noreply, state}
  end

  defp schedule_tick(state) do
    state.schedule_tick.(self(), state.tick_interval)
    :ok
  end

  defp process_tick(now) do
    due = Storage.get_due_groups(now)
    expired = Storage.get_expired_groups(now)

    Enum.each(due, &run_interval(&1, now))
    Enum.each(expired, &expire_if_live/1)
  end

  defp run_interval(%Group{} = group, now) do
    case handler_for(group) do
      {:ok, module} -> run_interval(module, group, now)
      :error -> callback_failed(group, :on_interval, :missing_handler, nil)
    end
  end

  defp run_interval(module, group, now) do
    case invoke(module, :on_interval, [group, now]) do
      {:ok, {:ok, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        Storage.update(%{updated | next_tick_at: now + updated.interval})

      {:ok, {:ok, %Group{group_id: group_id}}} ->
        callback_failed(group, :on_interval, {:foreign_group_id, group_id}, module)

      {:ok, {:expire, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        cleanup(updated, module)

      {:ok, {:expire, %Group{group_id: group_id}}} ->
        callback_failed(group, :on_interval, {:foreign_group_id, group_id}, module)

      {:ok, result} ->
        callback_failed(group, :on_interval, {:invalid_return, result}, module)

      {:error, reason} ->
        callback_failed(group, :on_interval, reason, module)
    end
  end

  defp expire_if_live(%Group{group_id: group_id}) do
    if group = Storage.get(group_id), do: cleanup(group)
  end

  defp run_trigger(%Group{} = group, mover, callback) do
    with {:ok, module} <- handler_for(group),
         true <- function_exported?(module, callback, 2) do
      case invoke(module, callback, [group, mover]) do
        {:ok, {:ok, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
          Storage.update(updated)

        {:ok, {:ok, %Group{group_id: group_id}}} ->
          callback_failed(group, callback, {:foreign_group_id, group_id}, module)

        {:ok, :expire} ->
          cleanup(group, module)

        {:ok, result} ->
          callback_failed(group, callback, {:invalid_return, result}, module)

        {:error, reason} ->
          callback_failed(group, callback, reason, module)
      end
    else
      _ -> :ok
    end
  end

  defp cleanup(%Group{} = group) do
    module =
      case handler_for(group) do
        {:ok, handler} -> handler
        :error -> nil
      end

    cleanup(group, module)
  end

  defp cleanup(%Group{group_id: group_id} = group, module) do
    if module && function_exported?(module, :on_expire, 1) do
      case invoke(module, :on_expire, [group]) do
        {:ok, :ok} -> :ok
        {:ok, result} -> log_callback_error(group, :on_expire, {:invalid_return, result})
        {:error, reason} -> log_callback_error(group, :on_expire, reason)
      end
    end

    Storage.delete(group_id)
  end

  defp callback_failed(group, callback, reason, module) do
    log_callback_error(group, callback, reason)
    cleanup(group, module)
  end

  defp log_callback_error(group, callback, reason) do
    Logger.error(
      "Skill.Unit.Manager callback=#{callback} failed skill=#{group.skill_name} " <>
        "group_id=#{group.group_id}: #{inspect(reason)}"
    )
  end

  defp invoke(module, callback, args) do
    {:ok, apply(module, callback, args)}
  rescue
    error -> {:error, {error, __STACKTRACE__}}
  catch
    kind, reason -> {:error, {kind, reason, __STACKTRACE__}}
  end

  defp default_server, do: ProcessTree.get({__MODULE__, :server}) || __MODULE__

  defp handler_for(%Group{caster_type: :mob}), do: {:ok, GroundNuke}
  defp handler_for(%Group{skill_name: skill_name}), do: Catalog.ground_module_for(skill_name)
end

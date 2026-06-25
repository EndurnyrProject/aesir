defmodule Aesir.Commons.Cluster.Entry do
  @moduledoc """
  Owner process for a single Horde.Registry entry. Registering `{key, value}` from
  this process ties the entry's existence to this process's liveness: when the
  process (or its node) dies, Horde removes the entry cluster-wide.

  When a partition heals, Horde drops the entries owned by the formerly-absent
  node from the CRDT (a tombstone that wins causally), so a live entry would
  otherwise vanish cluster-wide after a netsplit. To keep `liveness == presence`,
  the entry monitors node topology and re-asserts its registration on `:nodeup`,
  restoring itself once the cluster reconnects.

  On a netsplit heal where the same key was registered on both sides, Horde
  terminates the losing owner with a `{:name_conflict, ...}` exit; the loser is
  not restarted (it is `:temporary`). This is intentional — registry operations
  from any node resolve the surviving owner via a fresh `Horde.Registry.lookup`,
  so no local owner process is required for correctness.

  Options:
    * `:key`    - required registry key (any term)
    * `:value`  - required initial value
    * `:anchor` - optional pid to monitor; entry stops when the anchor goes down
    * `:ttl`    - optional inactivity timeout (ms); reset on update/replace/touch
  """
  use GenServer, restart: :temporary

  alias Aesir.Commons.Cluster

  # Re-assertion is delayed so it lands AFTER Horde re-establishes cluster
  # membership on :nodeup (otherwise the re-register would race the membership
  # sync). Jitter spreads the burst when many entries re-assert at once.
  @reassert_base_delay 500
  @reassert_jitter 500

  defstruct [:key, :value, :anchor_ref, :ttl, :timer_ref]

  @type t :: %__MODULE__{
          key: term(),
          value: term(),
          anchor_ref: reference() | nil,
          ttl: pos_integer() | nil,
          timer_ref: reference() | nil
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @spec update(pid(), (term() -> term())) :: {:ok, term()}
  def update(pid, fun), do: GenServer.call(pid, {:update, fun})

  @doc """
  Atomically transforms the value and returns a caller-chosen reply.

  `fun.(value)` must return `{reply, new_value}`; `new_value` is stored and
  `reply` is returned. Runs inside the owner process, so the read-decide-write is
  serialized against other updates (used for single-use token consumption).
  """
  @spec get_and_update(pid(), (term() -> {reply, term()})) :: reply when reply: term()
  def get_and_update(pid, fun), do: GenServer.call(pid, {:get_and_update, fun})

  @spec replace(pid(), term()) :: {:ok, term()}
  def replace(pid, value), do: GenServer.call(pid, {:replace, value})

  @spec touch(pid()) :: :ok
  def touch(pid), do: GenServer.cast(pid, :touch)

  @impl true
  def init(opts) do
    key = Keyword.fetch!(opts, :key)
    value = Keyword.fetch!(opts, :value)
    anchor = Keyword.get(opts, :anchor)
    ttl = Keyword.get(opts, :ttl)

    case Horde.Registry.register(Cluster.registry(), key, value) do
      {:ok, _pid} ->
        :net_kernel.monitor_nodes(true, node_type: :visible)
        anchor_ref = if is_pid(anchor), do: Process.monitor(anchor), else: nil

        state = %__MODULE__{key: key, value: value, anchor_ref: anchor_ref, ttl: ttl}
        {:ok, schedule_ttl(state)}

      {:error, {:already_registered, _pid}} ->
        :ignore
    end
  end

  @impl true
  def handle_call({:update, fun}, _from, %{key: key, value: value} = state) do
    new = fun.(value)
    put_value(key, new)
    {:reply, {:ok, new}, reset_ttl(%{state | value: new})}
  end

  def handle_call({:replace, value}, _from, %{key: key} = state) do
    put_value(key, value)
    {:reply, {:ok, value}, reset_ttl(%{state | value: value})}
  end

  def handle_call({:get_and_update, fun}, _from, %{key: key, value: value} = state) do
    {reply, new} = fun.(value)
    put_value(key, new)
    {:reply, reply, reset_ttl(%{state | value: new})}
  end

  @impl true
  def handle_cast(:touch, state), do: {:noreply, reset_ttl(state)}

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{anchor_ref: ref} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:nodeup, _node, _node_type}, %{key: key} = state) do
    Process.send_after(
      self(),
      {:reassert, key},
      @reassert_base_delay + :rand.uniform(@reassert_jitter)
    )

    {:noreply, state}
  end

  def handle_info({:nodedown, _node, _node_type}, state), do: {:noreply, state}

  def handle_info({:reassert, key}, %{key: key, value: value} = state) do
    reassert(key, value)
    {:noreply, state}
  end

  def handle_info(:ttl_expired, state), do: {:stop, :normal, state}
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{key: key}) do
    Horde.Registry.unregister(Cluster.registry(), key)
    :ok
  end

  defp put_value(key, value) do
    case Horde.Registry.update_value(Cluster.registry(), key, fn _ -> value end) do
      {_new, _old} -> :ok
      :error -> reassert(key, value)
    end
  end

  defp reassert(key, value) do
    case Horde.Registry.register(Cluster.registry(), key, value) do
      {:ok, _pid} -> :ok
      {:error, {:already_registered, _pid}} -> :ok
    end
  end

  defp schedule_ttl(%{ttl: nil} = state), do: state

  defp schedule_ttl(%{ttl: ttl} = state),
    do: %{state | timer_ref: Process.send_after(self(), :ttl_expired, ttl)}

  defp reset_ttl(%{ttl: nil} = state), do: state

  defp reset_ttl(%{timer_ref: ref} = state) do
    if ref, do: Process.cancel_timer(ref)
    schedule_ttl(%{state | timer_ref: nil})
  end
end

defmodule Aesir.ZoneServer.Unit.Trade.Session do
  @moduledoc """
  Owns the state and lifecycle of an accepted player trade.

  Each participant is identified by its player session pid. Offers can be
  changed until both participants lock, then both must confirm before the
  atomic exchange runs.
  """

  @behaviour :gen_statem

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Trade.Exchange
  alias Aesir.ZoneServer.Unit.Trade.Offer

  @type participant :: %{pid: pid(), char_id: integer()}
  @type init_arg :: %{a: participant(), b: participant()}
  @type confirm_snapshot :: %{inventory: term(), stats: term()}

  @doc false
  @spec child_spec(init_arg()) :: Supervisor.child_spec()
  def child_spec(init_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [init_arg]},
      restart: :temporary,
      type: :worker
    }
  end

  @doc "Starts a trade session for two player sessions."
  @spec start_link(init_arg()) :: :gen_statem.start_ret()
  def start_link(init_arg), do: :gen_statem.start_link(__MODULE__, init_arg, [])

  @doc "Adds an inventory-row snapshot to the caller's offer."
  @spec add_item(pid(), InventoryItem.t(), pos_integer()) :: :ok | {:error, atom()}
  def add_item(pid, snapshot, amount),
    do: :gen_statem.call(pid, {:add_item, snapshot, amount})

  @doc "Removes an inventory row from the caller's offer."
  @spec remove_item(pid(), integer()) :: :ok | {:error, atom()}
  def remove_item(pid, row_id), do: :gen_statem.call(pid, {:remove_item, row_id})

  @doc "Replaces the zeny in the caller's offer."
  @spec set_zeny(pid(), non_neg_integer()) :: :ok | {:error, atom()}
  def set_zeny(pid, zeny), do: :gen_statem.call(pid, {:set_zeny, zeny})

  @doc "Locks the caller's offer."
  @spec lock(pid()) :: :ok | {:error, atom()}
  def lock(pid), do: :gen_statem.call(pid, :lock)

  @doc "Confirms a locked offer with the caller's current capacity snapshot."
  @spec confirm(pid(), confirm_snapshot()) :: :ok | {:error, atom()}
  def confirm(pid, snapshot), do: :gen_statem.call(pid, {:confirm, snapshot})

  @doc "Cancels a trade without waiting for it to stop."
  @spec cancel(pid(), atom()) :: :ok
  def cancel(pid, reason), do: :gen_statem.cast(pid, {:cancel, reason})

  @impl :gen_statem
  def callback_mode, do: :state_functions

  @impl :gen_statem
  def init(%{a: %{pid: pid_a, char_id: char_a}, b: %{pid: pid_b, char_id: char_b}})
      when pid_a != pid_b do
    monitor_a = Process.monitor(pid_a)
    monitor_b = Process.monitor(pid_b)

    sides = %{
      pid_a => new_side(char_a, monitor_a),
      pid_b => new_side(char_b, monitor_b)
    }

    data = %{sides: sides, order: {pid_a, pid_b}}

    notify(pid_a, {:opened, self(), char_b})
    notify(pid_b, {:opened, self(), char_a})

    {:ok, :building, data}
  end

  def init(_init_arg), do: {:stop, :invalid_participants}

  def building({:call, {pid, _} = from}, event, data) do
    case Map.fetch(data.sides, pid) do
      :error -> reply(from, {:error, :not_a_participant})
      {:ok, side} -> handle_building_call(event, pid, side, from, data)
    end
  end

  def building(:cast, {:cancel, reason}, data), do: stop_cancelled(data, reason)
  def building(:info, message, data), do: handle_info_event(message, data)

  def locked({:call, {pid, _} = from}, event, data) do
    case Map.fetch(data.sides, pid) do
      :error -> reply(from, {:error, :not_a_participant})
      {:ok, side} -> handle_locked_call(event, pid, side, from, data)
    end
  end

  def locked(:cast, {:cancel, reason}, data), do: stop_cancelled(data, reason)
  def locked(:info, message, data), do: handle_info_event(message, data)

  def exchanging(:internal, :execute, data) do
    {pid_a, pid_b} = data.order
    side_a = exchange_side(data.sides[pid_a])
    side_b = exchange_side(data.sides[pid_b])

    case Exchange.run(side_a, side_b) do
      {:ok, %{a: delta_a, b: delta_b}} ->
        notify(pid_a, {:completed, delta_a})
        notify(pid_b, {:completed, delta_b})

      {:error, reason} ->
        notify_both(data, {:cancelled, reason})
    end

    {:stop, :normal}
  end

  def exchanging({:call, from}, _event, _data), do: reply(from, {:error, :exchanging})
  def exchanging(:cast, _event, _data), do: :keep_state_and_data
  def exchanging(:info, _event, _data), do: :keep_state_and_data

  defp handle_building_call(event, _pid, %{locked: true}, from, _data)
       when elem(event, 0) in [:add_item, :remove_item, :set_zeny] do
    reply(from, {:error, :locked})
  end

  defp handle_building_call({:add_item, snapshot, amount}, pid, side, from, data) do
    mutate_offer(data, pid, side, from, &Offer.add(&1, snapshot, amount))
  end

  defp handle_building_call({:remove_item, row_id}, pid, side, from, data) do
    mutate_offer(data, pid, side, from, &Offer.remove(&1, row_id))
  end

  defp handle_building_call({:set_zeny, zeny}, pid, side, from, data) do
    mutate_offer(data, pid, side, from, &Offer.set_zeny(&1, zeny))
  end

  defp handle_building_call(:lock, _pid, %{locked: true}, from, _data), do: reply(from, :ok)

  defp handle_building_call(:lock, pid, side, from, data) do
    data = put_side(data, pid, %{side | locked: true})
    notify_views(data)

    if Enum.all?(data.sides, fn {_pid, current} -> current.locked end) do
      {:next_state, :locked, data, [{:reply, from, :ok}]}
    else
      {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  defp handle_building_call({:confirm, _snapshot}, _pid, _side, from, _data),
    do: reply(from, {:error, :not_locked})

  defp handle_locked_call({:confirm, %{inventory: _, stats: _} = snapshot}, pid, side, from, data) do
    data = put_side(data, pid, %{side | confirmed: true, snapshot: snapshot})

    if Enum.all?(data.sides, fn {_pid, current} -> current.confirmed end) do
      {:next_state, :exchanging, data, [{:reply, from, :ok}, {:next_event, :internal, :execute}]}
    else
      {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  defp handle_locked_call({:confirm, _snapshot}, _pid, _side, from, _data),
    do: reply(from, {:error, :invalid_snapshot})

  defp handle_locked_call(_event, _pid, _side, from, _data),
    do: reply(from, {:error, :locked})

  defp mutate_offer(data, pid, side, from, mutation) do
    case mutation.(side.offer) do
      {:ok, offer} ->
        data = put_side(data, pid, %{side | offer: offer})
        notify_views(data)
        {:keep_state, data, [{:reply, from, :ok}]}

      {:error, reason} ->
        reply(from, {:error, reason})
    end
  end

  defp handle_info_event({:DOWN, monitor, :process, pid, _reason}, data) do
    case data.sides do
      %{^pid => %{monitor: ^monitor}} -> stop_cancelled(data, :disconnected)
      _ -> :keep_state_and_data
    end
  end

  defp handle_info_event(_message, _data), do: :keep_state_and_data

  defp new_side(char_id, monitor) do
    %{
      char_id: char_id,
      offer: Offer.new(),
      locked: false,
      confirmed: false,
      snapshot: nil,
      monitor: monitor
    }
  end

  defp put_side(data, pid, side), do: put_in(data, [:sides, pid], side)

  defp exchange_side(side) do
    %{
      char_id: side.char_id,
      offer: side.offer,
      inventory: side.snapshot.inventory,
      stats: side.snapshot.stats
    }
  end

  defp notify_views(data) do
    {pid_a, pid_b} = data.order
    notify(pid_a, {:offer_update, view(data.sides[pid_a], data.sides[pid_b])})
    notify(pid_b, {:offer_update, view(data.sides[pid_b], data.sides[pid_a])})
  end

  defp view(own, partner) do
    %{
      own: offer_view(own),
      partner: offer_view(partner)
    }
  end

  defp offer_view(side) do
    %{entries: side.offer.entries, zeny: side.offer.zeny, locked: side.locked}
  end

  defp stop_cancelled(data, reason) do
    notify_both(data, {:cancelled, reason})
    {:stop, :normal}
  end

  defp notify_both(data, event) do
    {pid_a, pid_b} = data.order
    notify(pid_a, event)
    notify(pid_b, event)
  end

  defp notify(pid, event), do: send(pid, {:trade, event})
  defp reply(from, response), do: {:keep_state_and_data, [{:reply, from, response}]}
end

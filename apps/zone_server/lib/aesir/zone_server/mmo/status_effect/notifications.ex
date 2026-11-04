defmodule Aesir.ZoneServer.Mmo.StatusEffect.Notifications do
  @moduledoc """
  Tells a status holder's session about committed status mutations.

  A player's refresh follows the `:owner_refresh` policy of the call that
  mutated the status (`maybe_refresh_owner/4`). A monster's session is cast
  every write, a homunculus's session is cast every change, and a status that
  stops its holder's attack stops a player's attack when it applies.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @typedoc "An actual status mutation committed for the application or removal's holder."
  @type status_event() :: {atom(), :apply | :removed}

  @typedoc "The owner-refresh policy of a status mutation."
  @type remove_option :: {:owner_refresh, StatusEntry.owner_refresh()}

  @doc """
  Applies the `:owner_refresh` policy of `opts` to a player's committed events.

  `:notify` publishes each event to the player's session, `:defer` leaves them
  to the owning session's handler, and the default `:auto` notifies unless the
  caller is the owning session. Other unit types and empty event lists refresh
  nothing.
  """
  @spec maybe_refresh_owner(Unit.unit_type(), integer(), [status_event()], keyword()) :: :ok
  def maybe_refresh_owner(:player, unit_id, [_ | _] = events, opts) do
    case Keyword.get(opts, :owner_refresh, :auto) do
      :notify -> notify_player_events(unit_id, events)
      :defer -> :ok
      :auto -> if owner_process?(unit_id), do: :ok, else: notify_player_events(unit_id, events)
      policy -> raise ArgumentError, "invalid owner refresh policy: #{inspect(policy)}"
    end
  end

  def maybe_refresh_owner(_unit_type, _unit_id, _events, _opts), do: :ok

  defp owner_process?(unit_id) do
    case UnitRegistry.get_unit(:player, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) -> pid == self()
      _ -> false
    end
  end

  defp notify_player_events(unit_id, events) do
    Enum.each(events, fn {status_id, event} ->
      PubSub.broadcast(
        Aesir.PubSub,
        "player:#{unit_id}",
        {:stats, {:status_changed, status_id, event}}
      )
    end)
  end

  @doc """
  Tells a unit's session that `status_id` applied: a monster is cast the write,
  a homunculus's session the change, and a player stops attacking when the
  status stops attacking.
  """
  @spec notify_unit_status_applied(Unit.unit_type(), integer(), atom()) :: :ok
  def notify_unit_status_applied(:mob, unit_id, status_id),
    do: notify_mob_status_write(:mob, unit_id, status_id, :apply)

  def notify_unit_status_applied(:homunculus, unit_id, status_id) do
    notify_homunculus_owner(unit_id, status_id, :applied)
  end

  def notify_unit_status_applied(:player, unit_id, status_id) do
    with true <- PropertyChecker.stops_attacking?(status_id),
         {:ok, pid} <- UnitRegistry.get_player_pid(unit_id),
         do: PlayerSession.stop_attack(pid)

    :ok
  end

  def notify_unit_status_applied(_unit_type, _unit_id, _status_id), do: :ok

  @doc "Tells a monster's or homunculus's session that `status_id` was removed."
  @spec notify_unit_status_removed(Unit.unit_type(), integer(), atom()) :: :ok
  def notify_unit_status_removed(:mob, unit_id, status_id),
    do: notify_mob_status_write(:mob, unit_id, status_id, :removed)

  def notify_unit_status_removed(:homunculus, unit_id, status_id) do
    notify_homunculus_owner(unit_id, status_id, :removed)
  end

  def notify_unit_status_removed(_unit_type, _unit_id, _status_id), do: :ok

  @doc "Casts a status write to a monster's session; other unit types are ignored."
  @spec notify_mob_status_write(Unit.unit_type(), integer(), atom(), :apply | :removed | :armed) ::
          :ok
  def notify_mob_status_write(:mob, unit_id, status_id, event) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        GenServer.cast(pid, {:casting, {:status_changed, status_id, event}})

      _ ->
        :ok
    end
  end

  def notify_mob_status_write(_unit_type, _unit_id, _status_id, _event), do: :ok

  defp notify_homunculus_owner(unit_id, status_id, event) do
    case UnitRegistry.get_unit(:homunculus, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        GenServer.cast(pid, {:homunculus, {:status_changed, unit_id, status_id, event}})

      _ ->
        :ok
    end
  end
end

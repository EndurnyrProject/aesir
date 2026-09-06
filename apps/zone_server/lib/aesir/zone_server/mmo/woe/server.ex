defmodule Aesir.ZoneServer.Mmo.Woe.Server do
  @moduledoc """
  Per-node GenServer owning the WoE agit lifecycle.

  `start/0` arms every FE castle (`gvg` mapflag, Emperium summon, siege flag),
  and `stop/0` disarms them (clear `gvg`, despawn the Emperiums, roll-call the
  owners). Attributed mob-death lifecycle events claim a matching live
  Emperium before eligible conquest is persisted and announced.

  The respawn timers live here so they outlive the dead Emperium. Re-arming a
  castle's timer cancels the previous one, and a stale timer fire never touches
  the current timer's bookkeeping.
  """

  use GenServer

  require Logger

  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Lifecycle.Event
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @emperium_mob_id 1288
  @guild_approval_skill_id 10_000

  @type t :: %__MODULE__{
          active?: boolean(),
          respawn_timers: %{non_neg_integer() => {reference(), reference()}}
        }

  defstruct active?: false, respawn_timers: %{}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.merge(opts, name: via_name()))
  end

  @doc """
  AgitStart: arms every FE castle (idempotent).

  Sets the `:gvg` mapflag, summons the Emperium (mob 1288), records its unit
  id, and marks the castle under siege, then broadcasts the WoE-begun message.
  """
  @spec start() :: :ok
  def start do
    GenServer.call(via_name(), :start_agit)
  end

  @doc """
  AgitEnd: disarms every FE castle (idempotent).

  Clears the `:gvg` mapflag, despawns the Emperiums, cancels pending respawn
  timers, then broadcasts the WoE-ended message and an owners roll-call.
  """
  @spec stop() :: :ok
  def stop do
    GenServer.call(via_name(), :stop_agit)
  end

  @doc "Whether the agit window is currently active."
  @spec active?() :: boolean()
  def active? do
    GenServer.call(via_name(), :active?)
  end

  @impl true
  def init(:ok) do
    :ok = Lifecycle.subscribe()
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:active?, _from, state) do
    {:reply, state.active?, state}
  end

  @impl true
  def handle_call(:start_agit, _from, state) do
    state =
      if state.active? do
        state
      else
        arm_all_castles()
        announce_woe("WoE has begun")
        %{state | active?: true}
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stop_agit, _from, state) do
    state =
      if state.active? do
        cancel_timers(state.respawn_timers)
        disarm_all_castles()
        announce_woe("WoE has ended")
        announce_owners()
        %{state | active?: false, respawn_timers: %{}}
      else
        state
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(
        {:unit_lifecycle,
         %Event{unit_type: :mob, unit_id: unit_id, reason: :death, old_map: map_name} = event},
        state
      )
      when is_binary(map_name) do
    case CastleDb.by_map(map_name) do
      {:ok, castle} -> handle_emperium_break(castle, unit_id, event.kill_credit, state)
      :error -> {:noreply, state}
    end
  end

  def handle_info({:unit_lifecycle, %Event{}}, state), do: {:noreply, state}

  def handle_info({:respawn_emperium, castle_id, expected_epoch, token}, state) do
    case Map.fetch(state.respawn_timers, castle_id) do
      {:ok, {_ref, ^token}} ->
        timers = Map.delete(state.respawn_timers, castle_id)

        if state.active? and CastleStore.get(castle_id).epoch == expected_epoch do
          respawn_emperium(castle_id)
        end

        {:noreply, %{state | respawn_timers: timers}}

      _ ->
        # A stale timer from a re-armed capture: the current timer for this
        # castle must stay in the map so stop/0 can cancel it.
        {:noreply, state}
    end
  end

  defp arm_all_castles do
    Enum.each(CastleDb.all(), &arm_castle/1)
  end

  defp arm_castle(%Castle{id: id, map: map, emperium: {x, y}}) do
    case Coordinator.summon_mob(map, @emperium_mob_id, x, y, []) do
      {:ok, unit_id} ->
        MapFlags.set_runtime(map, :gvg, true)
        CastleStore.set_emperium(id, unit_id)
        CastleStore.set_siege(id, true)

      {:error, reason} ->
        Logger.warning(
          "Failed to summon Emperium for castle #{id} on #{map}; castle stays non-gvg: #{inspect(reason)}"
        )
    end
  end

  defp disarm_all_castles do
    Enum.each(CastleDb.all(), &disarm_castle/1)
  end

  defp disarm_castle(%Castle{id: id, map: map}) do
    MapFlags.clear_runtime(map, :gvg)
    despawn_emperium(map, CastleStore.get(id).emperium_unit_id)
    CastleStore.set_emperium(id, nil)
    CastleStore.set_siege(id, false)
  end

  defp despawn_emperium(_map, nil), do: :ok

  defp despawn_emperium(map, unit_id) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _mob, pid}} ->
        UnitRegistry.unregister_unit(:mob, unit_id)
        MobSupervisor.terminate_mob(map, pid)

      {:error, :not_found} ->
        :ok
    end
  end

  defp respawn_emperium(castle_id) do
    case CastleDb.by_id(castle_id) do
      {:ok, %Castle{map: map, emperium: {x, y}}} ->
        case Coordinator.summon_mob(map, @emperium_mob_id, x, y, []) do
          {:ok, unit_id} ->
            CastleStore.set_emperium(castle_id, unit_id)

          {:error, reason} ->
            Logger.error(
              "Failed to respawn Emperium for castle #{castle_id} on #{map}: #{inspect(reason)}"
            )
        end

      :error ->
        Logger.error("Respawn timer fired for unknown castle #{castle_id}")
    end
  end

  defp handle_emperium_break(castle, unit_id, kill_credit, state) do
    guild_id = eligible_conqueror(castle.id, kill_credit)

    case CastleStore.claim_break(castle.id, unit_id, guild_id) do
      {:ok, castle_state} ->
        record_conquest(castle.id, guild_id)
        queue_castle_ejections(castle, guild_id, castle_state.epoch)

        timers =
          arm_respawn_timer(state.respawn_timers, castle.id, castle_state.epoch)

        {:noreply, %{state | respawn_timers: timers}}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  defp eligible_conqueror(castle_id, %{guild_id: guild_id})
       when is_integer(guild_id) and guild_id > 0 do
    with false <- CastleStore.owner(castle_id) == guild_id,
         {:ok, guild} <- Manager.get(guild_id),
         true <- State.skill_level(guild, @guild_approval_skill_id) > 0 do
      guild_id
    else
      _not_eligible -> nil
    end
  end

  defp eligible_conqueror(_castle_id, _kill_credit), do: nil

  defp record_conquest(_castle_id, nil), do: :ok

  defp record_conquest(castle_id, guild_id) do
    Persistence.persist(castle_id, guild_id)
    announce_conquest(castle_id, guild_id)
  end

  defp queue_castle_ejections(_castle, nil, _capture_epoch), do: :ok

  defp queue_castle_ejections(%Castle{id: castle_id, map: map}, owner_guild_id, capture_epoch) do
    UnitRegistry.list_players()
    |> Enum.each(fn character_id ->
      case UnitRegistry.get_unit(:player, character_id) do
        {:ok, {PlayerState, %PlayerState{map_name: ^map, guild_id: guild_id}, pid}}
        when is_pid(pid) and guild_id != owner_guild_id ->
          PlayerSession.eject_from_castle(pid, castle_id, map, capture_epoch)

        _other ->
          :ok
      end
    end)
  end

  defp arm_respawn_timer(timers, castle_id, epoch) do
    case Map.fetch(timers, castle_id) do
      {:ok, {old_ref, _token}} -> Process.cancel_timer(old_ref)
      :error -> :ok
    end

    token = make_ref()

    ref =
      Process.send_after(
        self(),
        {:respawn_emperium, castle_id, epoch, token},
        Config.woe_emperium_respawn_ms()
      )

    Map.put(timers, castle_id, {ref, token})
  end

  defp cancel_timers(timers) do
    Enum.each(timers, fn {_castle_id, {ref, _token}} -> Process.cancel_timer(ref) end)
  end

  defp announce_conquest(castle_id, guild_id) do
    case CastleDb.by_id(castle_id) do
      {:ok, %Castle{name: name}} ->
        announce_woe("#{name} conquered by #{guild_name(guild_id)}")

      :error ->
        Logger.error("Conquest announced for unknown castle #{castle_id}")
    end
  end

  defp announce_owners do
    Enum.each(CastleDb.all(), fn %Castle{id: id, name: name} ->
      owner_display =
        case CastleStore.owner(id) do
          nil -> "unoccupied"
          guild_id -> guild_name(guild_id)
        end

      announce_woe("#{name}: #{owner_display}")
    end)
  end

  defp guild_name(guild_id) do
    case Manager.get(guild_id) do
      {:ok, %State{name: name}} -> name
      {:error, :not_found} -> "Guild ##{guild_id}"
    end
  end

  defp announce_woe(text) do
    Announcement.to_all(announcement_opts(text))
  end

  defp announcement_opts(text) do
    {:ok, flag} = Flags.value("bc_woe")
    decoded = Flags.decode(flag, 0)

    %{
      text: text,
      color: decoded.color,
      style: Flags.style_for(decoded.scope),
      source_name: source_name()
    }
  end

  defp source_name, do: Application.get_env(:zone_server, :broadcast_source_name, "Server")

  defp via_name, do: {:via, Registry, {Aesir.ZoneServer.ProcessRegistry, __MODULE__}}
end

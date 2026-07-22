defmodule Aesir.ZoneServer.Unit.Player.SessionAdapter do
  @moduledoc """
  `Unit.Session.Adapter` for players.

  Operates on the player **session map** (not the bare `PlayerState`): `commit/3`
  needs the whole session to reach `StateCommit`, and `notify_vitals/2` needs the
  `:connection_pid`, so every callback takes and returns the session map with the
  `PlayerState` under `:game_state`.

  Player vitals live in `game_state.stats.current_state` (`hp`/`sp`) with maxima
  in `game_state.stats.derived_stats`; client sync goes through `StatusSync`.
  """

  @behaviour Aesir.ZoneServer.Unit.Session.Adapter

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.Session.Adapter

  @impl Adapter
  @spec get_vitals(map()) :: Adapter.vitals()
  def get_vitals(%{game_state: %PlayerState{stats: stats}}) do
    %{
      hp: stats.current_state.hp,
      sp: stats.current_state.sp,
      max_hp: stats.derived_stats.max_hp,
      max_sp: stats.derived_stats.max_sp
    }
  end

  @impl Adapter
  @spec put_vitals(map(), Adapter.vitals_update()) :: map()
  def put_vitals(%{game_state: %PlayerState{stats: stats} = game_state} = session, updates) do
    current = stats.current_state

    current = %{
      current
      | hp: Map.get(updates, :hp, current.hp),
        sp: Map.get(updates, :sp, current.sp)
    }

    %{session | game_state: %{game_state | stats: %{stats | current_state: current}}}
  end

  @impl Adapter
  @spec notify_vitals(map(), Adapter.fields()) :: :ok
  def notify_vitals(
        %{game_state: %PlayerState{stats: stats}, connection_pid: connection_pid},
        fields
      ) do
    current = stats.current_state

    Enum.each(fields, fn
      :hp -> StatusSync.send_param(connection_pid, StatusParams.hp(), current.hp)
      :sp -> StatusSync.send_param(connection_pid, StatusParams.sp(), current.sp)
    end)

    :ok
  end

  @impl Adapter
  @spec set_position(map(), Adapter.position()) :: map()
  def set_position(%{game_state: %PlayerState{} = game_state} = session, {x, y}) do
    game_state = PlayerState.update_position(game_state, x, y)
    Movement.set_position(:player, game_state.character_id, game_state, game_state.map_name)
    %{session | game_state: game_state}
  end

  @impl Adapter
  @spec stop_movement(map()) :: map()
  def stop_movement(%{game_state: %PlayerState{} = game_state} = session) do
    %{session | game_state: PlayerState.stop_walking(game_state)}
  end

  @impl Adapter
  @spec commit(map(), map(), Adapter.fields()) :: map()
  def commit(previous, %{game_state: %PlayerState{} = game_state}, fields) do
    committed = StateCommit.commit(previous, game_state)

    CharacterPersistence.update_stats(
      game_state.character_id,
      persist_map(game_state.stats.current_state, fields),
      async: true
    )

    committed
  end

  defp persist_map(current, fields) do
    Map.new(fields, fn
      :hp -> {:hp, current.hp}
      :sp -> {:sp, current.sp}
    end)
  end
end

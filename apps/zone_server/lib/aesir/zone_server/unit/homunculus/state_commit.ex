defmodule Aesir.ZoneServer.Unit.Homunculus.StateCommit do
  @moduledoc """
  Replaces the Homunculus nested in its owning player session and synchronizes
  active world presence.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Homunculus.SpawnView
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.WorldId

  @world_id_range 2..1_999_999

  @doc "Stores a restored offline state without publishing world presence."
  @spec restore(SessionState.t(), HomunculusState.t() | nil) :: SessionState.t()
  def restore(%SessionState{} = session, nil), do: %{session | homunculus: nil}

  def restore(%SessionState{} = session, %HomunculusState{} = homunculus) do
    if offline_state?(homunculus) do
      %{session | homunculus: homunculus}
    else
      raise ArgumentError, "restored Homunculus must be offline"
    end
  end

  @doc """
  Removes active world presence for a map transfer while retaining identity,
  clocks, and the nested world snapshot for destination re-entry.
  """
  @spec detach(SessionState.t()) :: SessionState.t()
  def detach(%SessionState{homunculus: %HomunculusState{world_gid: gid} = homunculus} = session)
      when is_integer(gid) do
    detach_world_presence(homunculus)
    session
  end

  def detach(%SessionState{} = session), do: session

  @doc "Removes all world presence and stores the supplied lifecycle state offline."
  @spec clear_presence(SessionState.t(), HomunculusState.t() | nil) :: SessionState.t()
  def clear_presence(%SessionState{} = session, nil) do
    remove_if_active(session.homunculus)
    %{session | homunculus: nil}
  end

  def clear_presence(%SessionState{} = session, %HomunculusState{} = homunculus) do
    remove_if_active(session.homunculus)

    offline = %{
      homunculus
      | world_gid: nil,
        owner_session_pid: nil,
        map_name: nil,
        x: nil,
        y: nil,
        movement_state: :standing,
        target: nil,
        casting: nil
    }

    %{session | homunculus: offline}
  end

  @doc """
  Recovers dead-session ghosts and reserves one transient GID before a durable
  lifecycle transition begins.
  """
  @spec reserve_activation(SessionState.t(), HomunculusState.t(), keyword()) ::
          {:ok, integer()} | {:error, :duplicate_session | :exhausted}
  def reserve_activation(
        %SessionState{} = session,
        %HomunculusState{} = homunculus,
        opts \\ []
      ) do
    validate_active!(prepare_active(session, homunculus, 1))

    with :ok <- recover_owner_presence(homunculus.owner_character_id) do
      WorldId.allocate(
        Keyword.get(opts, :world_id_range, @world_id_range),
        :homunculus
      )
    end
  end

  @doc "Releases an unregistered GID reserved for Homunculus activation."
  @spec release_activation(integer()) :: :ok
  def release_activation(gid), do: UnitRegistry.release_unit_id(gid, :homunculus)

  @doc "Commits active world presence using an already reserved Homunculus GID."
  @spec activate_claimed(SessionState.t(), HomunculusState.t(), pos_integer()) :: SessionState.t()
  def activate_claimed(
        %SessionState{} = session,
        %HomunculusState{} = homunculus,
        gid
      )
      when is_integer(gid) and gid > 0 do
    active = prepare_active(session, homunculus, gid)
    validate_active!(active)
    commit(session, active)
  end

  @doc """
  Recovers dead-session ghosts, allocates one transient GID, and commits an
  active Homunculus at its owner's current position.
  """
  @spec activate(SessionState.t(), HomunculusState.t(), keyword()) ::
          {:ok, SessionState.t()} | {:error, :duplicate_session | :exhausted}
  def activate(%SessionState{} = session, %HomunculusState{} = homunculus, opts \\ []) do
    with {:ok, gid} <- reserve_activation(session, homunculus, opts) do
      {:ok, activate_claimed(session, homunculus, gid)}
    end
  end

  defp prepare_active(session, homunculus, gid) do
    owner = session.game_state

    %{
      homunculus
      | lifecycle: :active,
        world_gid: gid,
        owner_session_pid: self(),
        map_name: owner.map_name,
        x: owner.x,
        y: owner.y,
        dir: owner.dir
    }
  end

  defp validate_active!(active) do
    unless active_world_state?(active) do
      raise ArgumentError, "active Homunculus requires complete living world state"
    end

    :ok
  end

  @doc """
  Stores `homunculus`, marks the owner-private view dirty, and synchronizes its
  active registry, spatial, movement, status, and observer state.
  """
  @spec commit(SessionState.t(), HomunculusState.t() | nil) :: SessionState.t()
  def commit(
        %SessionState{homunculus_runtime: %Runtime{} = runtime} = session,
        homunculus
      )
      when is_struct(homunculus, HomunculusState) or is_nil(homunculus) do
    homunculus = synchronize_presence(session.homunculus, homunculus)

    %{
      session
      | homunculus: homunculus,
        homunculus_runtime: %{runtime | private_dirty: true}
    }
  end

  defp synchronize_presence(previous, %HomunculusState{lifecycle: :active} = current) do
    unless active_world_state?(current) do
      raise ArgumentError, "active Homunculus requires complete living world state"
    end

    current = %{current | owner_session_pid: self()}
    maybe_remove_replaced(previous, current.world_gid)
    publish_active(previous, current)
    current
  end

  defp synchronize_presence(previous, nil) do
    remove_if_active(previous)
    nil
  end

  defp synchronize_presence(previous, %HomunculusState{} = current) do
    remove_if_active(previous, current.lifecycle)

    %{
      current
      | world_gid: nil,
        owner_session_pid: nil,
        map_name: nil,
        x: nil,
        y: nil,
        movement_state: :standing
    }
  end

  defp publish_active(
         %HomunculusState{world_gid: gid, map_name: old_map, x: old_x, y: old_y},
         %HomunculusState{world_gid: gid} = current
       ) do
    case UnitRegistry.get_unit(:homunculus, gid) do
      {:ok, {_module, previous_state, _pid}}
      when {old_map, old_x, old_y} == {current.map_name, current.x, current.y} ->
        UnitRegistry.update_unit_state(:homunculus, gid, current)
        maybe_mark_snapshot_dirty(previous_state, current)

      {:ok, {_module, _state, _pid}} ->
        Movement.set_position(:homunculus, gid, current, current.map_name)

      {:error, :not_found} ->
        register_active(current)
    end
  end

  defp publish_active(_previous, %HomunculusState{} = current), do: register_active(current)

  defp register_active(%HomunculusState{} = current) do
    UnitRegistry.register_unit(
      :homunculus,
      current.world_gid,
      HomunculusState,
      current,
      current.owner_session_pid
    )

    Movement.set_position(:homunculus, current.world_gid, current, current.map_name)
  end

  defp maybe_remove_replaced(%HomunculusState{world_gid: gid} = previous, new_gid)
       when is_integer(gid) and gid != new_gid,
       do: remove_world_presence(previous)

  defp maybe_remove_replaced(_previous, _new_gid), do: :ok

  defp remove_if_active(previous), do: remove_if_active(previous, :out_of_sight)

  defp remove_if_active(%HomunculusState{world_gid: gid} = previous, reason)
       when is_integer(gid),
       do: remove_world_presence(previous, reason)

  defp remove_if_active(_previous, _reason), do: :ok

  defp detach_world_presence(%HomunculusState{world_gid: gid} = homunculus) do
    clear_spatial_presence(homunculus)
    UnitRegistry.detach_unit(:homunculus, gid)
  end

  defp remove_world_presence(%HomunculusState{} = homunculus),
    do: remove_world_presence(homunculus, :out_of_sight)

  defp remove_world_presence(%HomunculusState{world_gid: gid} = homunculus, reason) do
    clear_spatial_presence(homunculus, reason)
    StatusStorage.clear_unit_statuses(:homunculus, gid)
    UnitRegistry.unregister_unit(:homunculus, gid)
  end

  defp clear_spatial_presence(%HomunculusState{} = homunculus),
    do: clear_spatial_presence(homunculus, :out_of_sight)

  defp clear_spatial_presence(%HomunculusState{world_gid: gid}, reason) do
    case SpatialIndex.get_unit_position(:homunculus, gid) do
      {:ok, {x, y, map_name}} ->
        observers = SpatialIndex.get_players_in_range(map_name, x, y, Config.view_range())
        notify_removed(observers, gid, reason)
        Movement.clear_dirty(map_name, :homunculus, gid)

      {:error, :not_found} ->
        :ok
    end

    SpatialIndex.remove_unit(:homunculus, gid)
  end

  defp notify_removed(observers, gid, :dead), do: SpawnView.notify_died(observers, gid)
  defp notify_removed(observers, gid, _reason), do: SpawnView.notify_left(observers, gid)

  defp recover_owner_presence(owner_character_id) do
    :homunculus
    |> UnitRegistry.list_units_by_type()
    |> Enum.reduce_while(:ok, fn gid, :ok ->
      recover_registered(gid, owner_character_id)
    end)
  end

  defp recover_registered(gid, owner_character_id) do
    case UnitRegistry.get_unit(:homunculus, gid) do
      {:ok, {_module, %HomunculusState{owner_character_id: ^owner_character_id}, pid}} ->
        recover_observed_owner(gid, pid)

      _other ->
        {:cont, :ok}
    end
  end

  defp recover_observed_owner(_gid, pid) when is_pid(pid) and node(pid) != node(),
    do: {:halt, {:error, :duplicate_session}}

  defp recover_observed_owner(gid, pid) when is_pid(pid) do
    if Process.alive?(pid),
      do: {:halt, {:error, :duplicate_session}},
      else: ghost_cleanup_result(gid, pid)
  end

  defp recover_observed_owner(gid, _pid), do: ghost_cleanup_result(gid, nil)

  defp ghost_cleanup_result(gid, observed_pid) do
    case cleanup_ghost(gid, observed_pid) do
      :ok -> {:cont, :ok}
      {:error, :duplicate_session} = error -> {:halt, error}
    end
  end

  defp cleanup_ghost(gid, observed_pid) do
    case UnitRegistry.get_unit(:homunculus, gid) do
      {:ok, {_module, %HomunculusState{} = state, ^observed_pid}} ->
        remove_world_presence(state)

      {:ok, {_module, %HomunculusState{}, _new_pid}} ->
        {:error, :duplicate_session}

      {:error, :not_found} ->
        :ok
    end
  end

  defp maybe_mark_snapshot_dirty(previous, current) do
    if snapshot_public_changed?(previous, current) do
      move_state = if current.movement_state == :moving, do: 1, else: 0
      Movement.mark_dirty(current.map_name, :homunculus, current.world_gid, move_state)
    end
  end

  defp snapshot_public_changed?(previous, current) do
    Map.take(previous, [:hp, :max_hp, :dir, :movement_state]) !=
      Map.take(current, [:hp, :max_hp, :dir, :movement_state])
  end

  defp active_world_state?(%HomunculusState{} = state) do
    HomunculusState.living?(state) and valid_identity?(state) and valid_health?(state) and
      valid_position?(state)
  end

  defp valid_identity?(state) do
    positive_integer?(state.world_gid) and positive_integer?(state.class_id) and
      positive_integer?(state.level) and nonempty_binary?(state.name)
  end

  defp valid_health?(state) do
    positive_integer?(state.max_hp) and is_integer(state.hp) and state.hp <= state.max_hp
  end

  defp valid_position?(state) do
    nonempty_binary?(state.map_name) and is_integer(state.x) and is_integer(state.y) and
      is_integer(state.dir) and state.dir in 0..7 and state.movement_state in [:standing, :moving]
  end

  defp offline_state?(state) do
    is_nil(state.world_gid) and is_nil(state.owner_session_pid) and is_nil(state.map_name) and
      is_nil(state.x) and is_nil(state.y) and state.movement_state == :standing and
      is_nil(state.target) and is_nil(state.casting)
  end

  defp positive_integer?(value), do: is_integer(value) and value > 0
  defp nonempty_binary?(value), do: is_binary(value) and byte_size(value) > 0
end

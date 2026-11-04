defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Publisher do
  @moduledoc """
  Sends skill-unit spawn, update and despawn packets to the players who may
  see a group, and keeps the per-observer tracking that decides who already
  knows a group.

  A `:public` group goes to everyone in view range of its centre, a
  `:party_only` group to the recipients `Group.visible_to?/3` admits, and a
  `:none` group to nobody. Every function runs inside `Skill.Unit.Manager`.
  """

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.SkillUnitDespawn
  alias Aesir.Net.SkillUnitSpawn
  alias Aesir.Net.SkillUnitUpdate
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.View
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @typedoc "The unit that damaged a cell, or `nil` for decay."
  @type source :: {atom(), integer()} | nil

  @doc "Announces a newly registered group to the players in view."
  @spec spawn(Group.t()) :: :ok
  def spawn(%Group{visibility: :none}), do: :ok

  def spawn(%Group{visibility: :public} = group) do
    packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group.group_id))}
    {x, y} = group.center
    publish(group.map_name, x, y, packet)
  end

  def spawn(%Group{visibility: :party_only} = group) do
    packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group.group_id))}
    to_eligible_players(group, packet, true)
  end

  @doc "Announces a group to the players in view and records them as its observers."
  @spec tracked_spawn(Group.t()) :: :ok
  def tracked_spawn(%Group{visibility: :none}), do: :ok

  def tracked_spawn(%Group{visibility: :public} = group) do
    packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group.group_id))}
    {x, y} = group.center
    :ok = publish(group.map_name, x, y, packet)
    Enum.each(players_in_range(group), &Storage.add_observer_group(&1, group.group_id))
    :ok
  end

  def tracked_spawn(%Group{visibility: :party_only} = group) do
    packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group.group_id))}
    to_eligible_players(group, packet, true)
  end

  @doc "Announces a group to the eligible players in view who are not yet tracking it."
  @spec spawn_untracked(Group.t()) :: :ok
  def spawn_untracked(%Group{} = group) do
    packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group.group_id))}

    tracked = fn player_id ->
      MapSet.member?(Storage.get_observer_groups(player_id), group.group_id)
    end

    group
    |> players_in_range()
    |> then(&eligible_recipients(group, &1))
    |> Enum.reject(tracked)
    |> Enum.each(fn player_id ->
      Broadcast.to_player(player_id, packet)
      Storage.add_observer_group(player_id, group.group_id)
    end)

    :ok
  end

  @doc "Reports a cell's HP change."
  @spec cell_update(Cell.t(), integer(), source(), :damage | :decay) :: :ok
  def cell_update(%Cell{} = cell, hp_delta, source, reason) do
    case Storage.get(cell.group_id) do
      %Group{} = group ->
        {source_type, source_id} = source_fields(source)

        packet = %SkillUnitUpdate{
          group_id: group.group_id,
          cell_id: cell.cell_id,
          hp: cell.hp,
          max_hp: cell.max_hp,
          hp_delta: hp_delta,
          source_type: source_type,
          source_id: source_id,
          reason: update_reason(reason),
          server_tick: ServerTick.now()
        }

        by_visibility(group, cell.x, cell.y, packet)

      _ ->
        :ok
    end
  end

  @doc "Reports one cell leaving its still-live group."
  @spec cell_despawn(Cell.t(), atom()) :: :ok
  def cell_despawn(%Cell{} = cell, reason) do
    case Storage.get(cell.group_id) do
      %Group{} = group ->
        packet = %SkillUnitDespawn{
          group_id: cell.group_id,
          cell_ids: [cell.cell_id],
          reason: reason,
          server_tick: ServerTick.now()
        }

        by_visibility(group, cell.x, cell.y, packet)

      _ ->
        :ok
    end
  end

  @doc "Reports cells destroyed out of a still-live group."
  @spec cells_despawn(Group.t(), [non_neg_integer()]) :: :ok
  def cells_despawn(%Group{} = group, cell_ids) do
    if cell_ids != [] do
      packet = %SkillUnitDespawn{
        group_id: group.group_id,
        cell_ids: Enum.sort(cell_ids),
        reason: :SKILL_UNIT_DESPAWN_REASON_DESTROYED,
        server_tick: ServerTick.now()
      }

      {x, y} = group.center
      by_visibility(group, x, y, packet)
    end

    :ok
  end

  @doc """
  Reports a whole group gone, to the players in view and to every observer
  who tracked it from elsewhere; the observer tracking is released.
  """
  @spec group_despawn(Group.t(), [non_neg_integer()], atom()) :: :ok
  def group_despawn(%Group{} = group, cell_ids, reason) do
    packet = %SkillUnitDespawn{
      group_id: group.group_id,
      cell_ids: Enum.sort(cell_ids),
      reason: reason,
      server_tick: ServerTick.now()
    }

    observers = Storage.take_group_observers(group.group_id)
    in_range = players_in_range(group)

    case group.visibility do
      :none ->
        :ok

      :public ->
        {x, y} = group.center
        :ok = publish(group.map_name, x, y, packet)

        observers
        |> Enum.uniq()
        |> Kernel.--(in_range)
        |> Enum.each(&Broadcast.to_player(&1, packet))

      :party_only ->
        group
        |> eligible_recipients(in_range)
        |> Enum.concat(observers)
        |> Enum.uniq()
        |> Enum.each(&Broadcast.to_player(&1, packet))
    end

    :ok
  end

  @doc """
  Reports a group recentered. Observers who already knew it get the move;
  players newly in view of the new centre get a spawn; earlier observers now
  out of view lose it, exactly as if they had walked away from it.
  """
  @spec move(Group.t()) :: :ok
  def move(%Group{visibility: :none}), do: :ok

  def move(%Group{group_id: group_id} = group) do
    cells = Storage.get_cells_by_group(group_id)
    previous = group_id |> Storage.take_group_observers() |> MapSet.new()

    recipients =
      group |> players_in_range() |> then(&eligible_recipients(group, &1)) |> MapSet.new()

    move = View.move(group, cells, ServerTick.now())
    spawn = %SkillUnitSpawn{group: View.group(group, cells)}

    Enum.each(recipients, fn player_id ->
      Broadcast.to_player(player_id, if(player_id in previous, do: move, else: spawn))
      Storage.add_observer_group(player_id, group_id)
    end)

    left_view = %SkillUnitDespawn{
      group_id: group_id,
      cell_ids: cells |> Enum.map(& &1.cell_id) |> Enum.sort(),
      reason: :SKILL_UNIT_DESPAWN_REASON_LEFT_VIEW,
      server_tick: ServerTick.now()
    }

    previous
    |> MapSet.difference(recipients)
    |> Enum.each(&Broadcast.to_player(&1, left_view))
  end

  @doc """
  Replaces a group's view in place: a despawn then a spawn to everyone who
  may see it, and a despawn to earlier observers who no longer may.
  """
  @spec group_replacement(Group.t(), [Cell.t()]) :: :ok
  def group_replacement(%Group{} = group, cells) do
    cell_ids = cells |> Enum.map(& &1.cell_id) |> Enum.sort()

    despawn = %SkillUnitDespawn{
      group_id: group.group_id,
      cell_ids: cell_ids,
      reason: :SKILL_UNIT_DESPAWN_REASON_DESTROYED,
      server_tick: ServerTick.now()
    }

    spawn = %SkillUnitSpawn{group: View.group(group, cells)}
    {x, y} = group.center
    observers = Storage.take_group_observers(group.group_id)
    in_range = SpatialIndex.get_players_in_range(group.map_name, x, y, Config.view_range())

    case group.visibility do
      :none ->
        :ok

      :public ->
        :ok = publish(group.map_name, x, y, despawn)
        :ok = publish(group.map_name, x, y, spawn)

        observers
        |> Enum.uniq()
        |> Kernel.--(in_range)
        |> Enum.each(fn player_id ->
          Broadcast.to_player(player_id, despawn)
          Broadcast.to_player(player_id, spawn)
        end)

        Enum.each(in_range, &Storage.add_observer_group(&1, group.group_id))

      :party_only ->
        eligible = eligible_recipients(group, in_range)

        observers
        |> Enum.reject(&(&1 in eligible))
        |> Enum.uniq()
        |> Enum.each(&Broadcast.to_player(&1, despawn))

        Enum.each(eligible, fn player_id ->
          Broadcast.to_player(player_id, despawn)
          Broadcast.to_player(player_id, spawn)
          Storage.add_observer_group(player_id, group.group_id)
        end)
    end

    :ok
  end

  @doc """
  Sends one observer the authoritative snapshot of the visible groups around
  a point and makes that set the observer's tracked groups.
  """
  @spec snapshot_for(integer(), String.t(), integer(), integer(), non_neg_integer()) ::
          MapSet.t(non_neg_integer())
  def snapshot_for(observer_id, map_name, x, y, range) do
    groups =
      map_name
      |> Storage.get_visible_groups_in_range(x, y, range)
      |> Enum.filter(&(eligible_recipients(&1, [observer_id]) != []))

    snapshot =
      groups
      |> Enum.map(&{&1, Storage.get_cells_by_group(&1.group_id)})
      |> View.snapshot(ServerTick.now())

    Broadcast.to_player(observer_id, snapshot)
    :ok = Storage.replace_observer_groups(observer_id, Enum.map(groups, & &1.group_id))
    MapSet.new(groups, & &1.group_id)
  end

  @doc """
  Applies one visibility diff for an observer: a spawn for each entered group
  the observer may see, a left-view despawn for each materialized group left.
  Returns the observer's tracked groups afterwards.
  """
  @spec sync_view(integer(), Enumerable.t(), Enumerable.t()) :: MapSet.t(non_neg_integer())
  def sync_view(observer_id, enter_ids, leave_ids) do
    leave_ids = leave_ids |> MapSet.new() |> MapSet.to_list() |> Enum.sort()

    enter_ids =
      enter_ids
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(leave_ids))
      |> MapSet.to_list()
      |> Enum.sort()

    observer_groups = Storage.get_observer_groups(observer_id)

    Enum.each(enter_ids, fn group_id ->
      if not MapSet.member?(observer_groups, group_id),
        do: enter_observer_view(observer_id, group_id)
    end)

    Enum.each(leave_ids, fn group_id ->
      if MapSet.member?(observer_groups, group_id), do: leave_observer_view(observer_id, group_id)
    end)

    Storage.get_observer_groups(observer_id)
  end

  defp enter_observer_view(observer_id, group_id) do
    case Storage.get(group_id) do
      %Group{} = group ->
        if eligible_recipients(group, [observer_id]) != [] do
          packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group_id))}
          Broadcast.to_player(observer_id, packet)
          Storage.add_observer_group(observer_id, group_id)
        end

      _ ->
        :ok
    end
  end

  defp leave_observer_view(observer_id, group_id) do
    case Storage.get(group_id) do
      %Group{} = group ->
        if Group.materialized?(group) do
          cell_ids =
            group_id
            |> Storage.get_cells_by_group()
            |> Enum.map(& &1.cell_id)
            |> Enum.sort()

          Broadcast.to_player(observer_id, %SkillUnitDespawn{
            group_id: group_id,
            cell_ids: cell_ids,
            reason: :SKILL_UNIT_DESPAWN_REASON_LEFT_VIEW,
            server_tick: ServerTick.now()
          })
        end

      _ ->
        :ok
    end

    Storage.remove_observer_group(observer_id, group_id)
  end

  defp by_visibility(%Group{visibility: :none}, _x, _y, _packet), do: :ok

  defp by_visibility(%Group{visibility: :public} = group, x, y, packet),
    do: publish(group.map_name, x, y, packet)

  defp by_visibility(%Group{visibility: :party_only} = group, x, y, packet) do
    group.map_name
    |> SpatialIndex.get_players_in_range(x, y, Config.view_range())
    |> then(&eligible_recipients(group, &1))
    |> Enum.each(&Broadcast.to_player(&1, packet))
  end

  defp to_eligible_players(%Group{} = group, packet, track?) do
    group
    |> players_in_range()
    |> then(&eligible_recipients(group, &1))
    |> Enum.each(fn player_id ->
      Broadcast.to_player(player_id, packet)
      if track?, do: Storage.add_observer_group(player_id, group.group_id)
    end)

    :ok
  end

  defp publish(map_name, x, y, packet),
    do: Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet)

  defp players_in_range(%Group{map_name: map_name, center: {x, y}}) do
    SpatialIndex.get_players_in_range(map_name, x, y, Config.view_range())
  end

  defp eligible_recipients(%Group{visibility: :public}, player_ids), do: player_ids
  defp eligible_recipients(%Group{visibility: :none}, _player_ids), do: []

  defp eligible_recipients(%Group{visibility: :party_only} = group, player_ids) do
    player_ids
    |> Enum.uniq()
    |> Enum.filter(fn player_id ->
      observer_party_id =
        case UnitRegistry.get_unit(:player, player_id) do
          {:ok, {_module, %PlayerState{party_id: party_id}, _pid}} -> party_id
          {:error, :not_found} -> nil
        end

      Group.visible_to?(group, player_id, observer_party_id)
    end)
  end

  defp source_fields({:player, source_id}), do: {:SKILL_UNIT_OWNER_TYPE_PLAYER, source_id}

  defp source_fields({:homunculus, world_gid}) do
    case UnitRegistry.get_unit(:homunculus, world_gid) do
      {:ok, {_module, %HomunculusState{owner_character_id: owner_id}, _pid}} ->
        {:SKILL_UNIT_OWNER_TYPE_PLAYER, owner_id}

      {:error, :not_found} ->
        raise ArgumentError, "Homunculus skill-unit damage source unavailable"
    end
  end

  defp source_fields({:mob, source_id}), do: {:SKILL_UNIT_OWNER_TYPE_MOB, source_id}
  defp source_fields({:npc, source_id}), do: {:SKILL_UNIT_OWNER_TYPE_NPC, source_id}
  defp source_fields(nil), do: {:SKILL_UNIT_OWNER_TYPE_UNSPECIFIED, 0}
  defp update_reason(:damage), do: :SKILL_UNIT_UPDATE_REASON_DAMAGE
  defp update_reason(:decay), do: :SKILL_UNIT_UPDATE_REASON_DECAY
end

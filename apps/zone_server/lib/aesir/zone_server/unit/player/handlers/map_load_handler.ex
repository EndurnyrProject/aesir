defmodule Aesir.ZoneServer.Unit.Player.Handlers.MapLoadHandler do
  @moduledoc """
  Handles the client's map-loaded acknowledgement.

  On initial entry the full client sync runs (status params, inventory, cart,
  skill list), the invincibility starts, and only then does the player enter
  the map: `:spawn_player` indexes the player and runs the first visibility
  pass, so nothing can see or pick the player before its invincibility runs.
  After a warp the client already holds that data, so only the respawn on the
  destination map fires. Both branches clear the warp cooldown, run the
  on-spawn touch check (the warp underfoot, else the NPC trigger areas) and
  publish the player's own vending state (its open shop, or none) with
  request ID zero. An ack from a player already on its map is ignored:
  nothing restarts, nothing is sent and the player is not spawned again.
  """

  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.NavigationHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.TouchHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestView
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @doc """
  Processes the map-loaded acknowledgement (protobuf analogue of
  CZ_NOTIFY_ACTORINIT).
  """
  @spec handle_map_loaded(map()) :: {:noreply, map()}
  def handle_map_loaded(%{game_state: %{pending_map_load: nil}} = state), do: {:noreply, state}

  def handle_map_loaded(%{game_state: %{pending_map_load: :warp}} = state) do
    {:noreply, state} = StatsManager.handle_recalculate_stats(state)
    game_state = state.game_state

    state =
      Map.put(
        state,
        :castle_regen_map,
        landing_castle(game_state) || Map.get(state, :castle_regen_map)
      )

    Logger.debug("Player #{game_state.character_id} finished loading warp destination map")

    # The client already holds inventory/skills/stats from the initial load, so
    # a warp only needs to re-enter the player on the destination map.
    send(self(), :respawn_after_warp)

    visible_skill_units = send_skill_unit_snapshot(game_state)

    state = %{
      state
      | game_state: %{
          PlayerState.clear_warp_cooldown(game_state)
          | pending_map_load: nil,
            visible_skill_units: visible_skill_units
        }
    }

    state =
      state
      |> spawn_touch()
      |> VendingHandler.publish_owner_snapshot()
      |> Invincibility.start_on_map_load()

    {:noreply, NavigationHandler.on_map_loaded(state)}
  end

  def handle_map_loaded(%{connection_pid: connection_pid} = state) do
    {:noreply, state} = StatsManager.handle_recalculate_stats(state)
    game_state = state.game_state
    state = Map.put(state, :castle_regen_map, landing_castle(game_state))

    Logger.debug("Player #{game_state.character_id} finished loading map (LoadEndAck)")

    StatusSync.send_params(connection_pid, %{
      StatusParams.weight() => Weight.current_weight(game_state.inventory),
      StatusParams.max_weight() => Weight.max_weight(game_state.stats)
    })

    StatusSync.send_params(connection_pid, %{
      StatusParams.next_base_exp() => Leveling.next_base_exp(game_state.stats.progression),
      StatusParams.next_job_exp() => Leveling.next_job_exp(game_state.stats.progression),
      StatusParams.skill_point() => game_state.stats.progression.skill_point
    })

    base_stats = game_state.stats.base_stats
    job_id = game_state.stats.progression.job_id

    StatusSync.send_params(connection_pid, %{
      StatusParams.status_point() => game_state.stats.progression.status_point,
      StatusParams.ustr() => StatPoint.next_cost(base_stats.str, job_id),
      StatusParams.uagi() => StatPoint.next_cost(base_stats.agi, job_id),
      StatusParams.uvit() => StatPoint.next_cost(base_stats.vit, job_id),
      StatusParams.uint() => StatPoint.next_cost(base_stats.int, job_id),
      StatusParams.udex() => StatPoint.next_cost(base_stats.dex, job_id),
      StatusParams.uluk() => StatPoint.next_cost(base_stats.luk, job_id)
    })

    StatusSync.send_stat_updates(connection_pid, game_state.stats)
    MessageRouter.send_to(connection_pid, InventoryView.inventory_list(game_state.inventory))
    MessageRouter.send_to(connection_pid, QuestView.quest_list(game_state.quest_log))
    maybe_send_cart_info(connection_pid, game_state)
    send_own_status_sync(connection_pid, game_state.character_id)

    skill_list = SkillListView.build(game_state)
    MessageRouter.send_to(connection_pid, skill_list)

    visible_skill_units = send_skill_unit_snapshot(game_state)

    # The spawn is queued first: it runs after this handler returns, with the
    # invincibility already published, ahead of the spawn-cell warp below and
    # of the invincibility's deferred arrival (sent when the map sets no time).
    send(self(), :spawn_player)

    state = %{
      state
      | game_state: %{
          PlayerState.clear_warp_cooldown(game_state)
          | pending_map_load: nil,
            visible_skill_units: visible_skill_units
        }
    }

    state = state |> spawn_touch() |> VendingHandler.publish_owner_snapshot()
    {:noreply, Invincibility.start_on_map_load(state)}
  end

  # On-spawn touch check: the warp whose area holds the spawn cell fires,
  # else the cell's NPC trigger areas are scanned. Runs on both branches of
  # `handle_map_loaded/1`, after the warp cooldown is cleared so a warp that
  # triggered this load cycle cannot suppress the on-spawn fire. The spawn
  # message is already queued ahead, so a touched script's first session call
  # finds the player on the map.
  @spec spawn_touch(map()) :: map()
  defp spawn_touch(%{game_state: game_state} = state) do
    case TouchHandler.warp_underfoot(game_state) do
      %Warp{} = warp ->
        PlayerSession.warp(self(), warp.to_map, warp.to_x, warp.to_y)
        state

      nil ->
        TouchHandler.scan(state)
    end
  end

  # The spawn/visibility flows only carry a unit's sprite state and status
  # icons to *other* observers, and the on-apply broadcasts during `init` fire
  # before the player is in the spatial index — so nothing tells the owner
  # about state restored at login (the cart re-mounted by `load_on_spawn`,
  # persisted statuses). Mirrors rAthena's login self-sync in `pc_authok`
  # (own options + EFST icons).
  defp send_own_status_sync(connection_pid, char_id) do
    MessageRouter.send_to(connection_pid, StatusDisplay.state_packet(:player, char_id))

    :player
    |> StatusDisplay.active_icons(char_id)
    |> Enum.each(&MessageRouter.send_to(connection_pid, &1))
  end

  # Sends the cart dump on map load only for a mounted player; an unmounted
  # player has an empty cart and needs no CartInfo.
  defp maybe_send_cart_info(_connection_pid, %{cart_type: 0}), do: :ok

  defp maybe_send_cart_info(connection_pid, %{cart: cart}) do
    MessageRouter.send_to(connection_pid, InventoryView.cart_info(cart))
  end

  defp send_skill_unit_snapshot(game_state) do
    SkillUnitManager.snapshot_for(
      game_state.character_id,
      game_state.map_name,
      game_state.x,
      game_state.y,
      game_state.view_range
    )
  end

  # Landing in a castle the player's guild owns grants the castle regeneration
  # bonus. A warp sets it already; the warp acknowledgement grants it too for
  # relocations that only carry the game state (item scripts).
  defp landing_castle(%{map_name: map, guild_id: guild_id}),
    do: if(CastleStore.owned_by_guild?(map, guild_id), do: map)
end

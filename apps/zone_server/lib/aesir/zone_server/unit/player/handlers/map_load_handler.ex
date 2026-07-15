defmodule Aesir.ZoneServer.Unit.Player.Handlers.MapLoadHandler do
  @moduledoc """
  Handles the client's map-loaded acknowledgement.

  On initial entry the full client sync runs (status params, inventory, cart,
  skill list) before the spawn; after a warp the client already holds that
  data, so only the respawn on the destination map fires. Both branches clear
  the warp cooldown and run the on-spawn warp check.
  """

  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestView
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @doc """
  Processes the map-loaded acknowledgement (protobuf analogue of
  CZ_NOTIFY_ACTORINIT).
  """
  @spec handle_map_loaded(map()) :: {:noreply, map()}
  def handle_map_loaded(%{game_state: %{pending_map_load: :warp} = game_state} = state) do
    Logger.debug("Player #{game_state.character_id} finished loading warp destination map")

    # The client already holds inventory/skills/stats from the initial load, so
    # a warp only needs to re-enter the player on the destination map.
    send(self(), :respawn_after_warp)

    visible_skill_units = send_skill_unit_snapshot(game_state)
    cleared_game_state = PlayerState.clear_warp_cooldown(game_state)
    maybe_fire_spawn_warp(cleared_game_state)

    {:noreply,
     %{
       state
       | game_state: %{
           cleared_game_state
           | pending_map_load: nil,
             visible_skill_units: visible_skill_units
         }
     }}
  end

  def handle_map_loaded(%{connection_pid: connection_pid, game_state: game_state} = state) do
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

    StatusSync.send_params(connection_pid, %{
      StatusParams.status_point() => game_state.stats.progression.status_point,
      StatusParams.ustr() => StatPoint.cost_to_raise(base_stats.str),
      StatusParams.uagi() => StatPoint.cost_to_raise(base_stats.agi),
      StatusParams.uvit() => StatPoint.cost_to_raise(base_stats.vit),
      StatusParams.uint() => StatPoint.cost_to_raise(base_stats.int),
      StatusParams.udex() => StatPoint.cost_to_raise(base_stats.dex),
      StatusParams.uluk() => StatPoint.cost_to_raise(base_stats.luk)
    })

    StatusSync.send_stat_updates(connection_pid, game_state.stats)
    MessageRouter.send_to(connection_pid, InventoryView.inventory_list(game_state.inventory))
    MessageRouter.send_to(connection_pid, QuestView.quest_list(game_state.quest_log))
    maybe_send_cart_info(connection_pid, game_state)
    send_own_status_sync(connection_pid, game_state.character_id)

    skill_list = SkillListView.build(game_state.stats.progression)
    MessageRouter.send_to(connection_pid, skill_list)

    visible_skill_units = send_skill_unit_snapshot(game_state)

    send(self(), :spawn_player)

    cleared_game_state = PlayerState.clear_warp_cooldown(game_state)
    maybe_fire_spawn_warp(cleared_game_state)

    {:noreply,
     %{state | game_state: %{cleared_game_state | visible_skill_units: visible_skill_units}}}
  end

  # On-spawn entry trigger (rAthena `OnTouch` on-spawn): if the spawn cell sits
  # inside a warp's `xs/ys` area, fire the warp. Runs on both the initial-entry
  # and `:warp` branches of `handle_map_loaded/1`. The cooldown is cleared
  # before this check so a warp that triggered the load cycle can't suppress
  # the on-spawn fire. Real warp data doesn't chain, so this won't loop; the
  # per-player cooldown guards same-map re-fire within a map (Task 7).
  @spec maybe_fire_spawn_warp(PlayerState.t()) :: :ok
  defp maybe_fire_spawn_warp(%PlayerState{} = game_state) do
    warps_for_map =
      case Warps.for_map(game_state.map_name) do
        {:ok, list} -> list
        :error -> []
      end

    case Warp.Registry.hit?(warps_for_map, game_state.x, game_state.y) do
      %Warp{} = warp ->
        GenServer.cast(self(), {:warp, warp.to_map, warp.to_x, warp.to_y})

      nil ->
        :ok
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
end

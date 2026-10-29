defmodule Aesir.ZoneServer.Unit.Player.Handlers.SitHandlerTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.DamageDealt
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.SitHandler
  alias Aesir.ZoneServer.Unit.Player.NaturalHeal.Timing
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "sitting broadcasts a sit-down action to the area, actor included" do
    player = register(player(1, :idle))

    assert {:noreply, %{game_state: %{action_state: :sitting}}} =
             SitHandler.handle_sit(%{game_state: player})

    assert_receive {:"$gen_cast", {:send_packet, %DamageDealt{src_id: 1, type: 2}}}
  end

  test "standing broadcasts a stand-up action to the area, actor included" do
    player = register(player(1, :sitting))

    assert {:noreply, %{game_state: %{action_state: :idle}}} =
             SitHandler.handle_stand(%{game_state: player})

    assert_receive {:"$gen_cast", {:send_packet, %DamageDealt{src_id: 1, type: 3}}}
  end

  test "a forced stand ends Tension Relax and restarts the sitting regeneration" do
    player = register(player(1, :sitting))
    :ok = StatusStorage.apply_status(:player, 1, :sc_tensionrelax, val1: 1)
    timing = %Timing{sitting_hp_acc: 900, sitting_sp_acc: 400, skill_hp_acc: 300}

    assert {:noreply, stood} =
             SitHandler.handle_force_stand(%{game_state: player, regen_timing: timing})

    assert stood.game_state.action_state == :idle
    assert stood.regen_timing == %{timing | sitting_hp_acc: 0, sitting_sp_acc: 0}
    refute StatusStorage.has_status?(:player, 1, :sc_tensionrelax)
    assert_receive {:"$gen_cast", {:send_packet, %DamageDealt{src_id: 1, type: 3}}}
  end

  test "a forced stand leaves a player who is not sitting alone" do
    state = %{game_state: register(player(1, :trading)), regen_timing: %Timing{}}

    assert {:noreply, ^state} = SitHandler.handle_force_stand(state)
  end

  test "a refused transition broadcasts nothing" do
    player = register(player(1, :trading))

    assert {:noreply, %{game_state: %{action_state: :trading}}} =
             SitHandler.handle_sit(%{game_state: player})

    refute_receive {:"$gen_cast", {:send_packet, %DamageDealt{}}}
  end

  defp player(id, action_state),
    do: %{PlayerState.new(character(id)) | action_state: action_state}

  defp register(player) do
    :ok = UnitRegistry.register_unit(:player, player.character_id, PlayerState, player, self())
    :ok = SpatialIndex.add_player(player.character_id, player.x, player.y, player.map_name)
    player
  end

  defp character(id) do
    %Character{
      id: id,
      account_id: id,
      name: "Sitter #{id}",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 0,
      base_level: 1,
      job_level: 10,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1
    }
  end
end

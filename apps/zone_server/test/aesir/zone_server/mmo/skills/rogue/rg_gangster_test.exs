defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgGangsterTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgGangster
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    Catalog.reload()
  end

  test "is discovered as an iconless passive with its Gangster Paradise marker" do
    assert {:ok, definition} = Catalog.by_id(223)
    assert definition.name == :rg_gangster
    assert definition.display_name == "Slyness"
    assert definition.max_level == 1
    assert {:ok, RgGangster} = Catalog.passive_module_for(:rg_gangster)
    assert %{icon: nil, no_save: true} = Registry.get_definition(:sc_gangsterparadise)
  end

  test "sitting with another seated Rogue applies Gangster Paradise and standing clears it" do
    rogue = player(1)
    seated_rogue = player(2, :sitting)
    register(rogue)
    register(seated_rogue)

    assert {:noreply, sitting} = PacketHandler.handle_message(%ActionRequest{action: 2}, %{game_state: rogue})
    assert sitting.game_state.action_state == :sitting
    assert StatusStorage.has_status?(:player, 1, :sc_gangsterparadise)
    assert StatusStorage.has_status?(:player, 2, :sc_gangsterparadise)

    assert {:noreply, standing} =
             PacketHandler.handle_message(%ActionRequest{action: 3}, sitting)

    assert standing.game_state.action_state == :idle
    refute StatusStorage.has_status?(:player, 1, :sc_gangsterparadise)
    refute StatusStorage.has_status?(:player, 2, :sc_gangsterparadise)
  end

  test "sitting without another seated Rogue does not apply Gangster Paradise" do
    rogue = player(1)
    register(rogue)

    assert {:noreply, _sitting} =
             PacketHandler.handle_message(%ActionRequest{action: 2}, %{game_state: rogue})

    refute StatusStorage.has_status?(:player, 1, :sc_gangsterparadise)
  end

  defp player(id, action_state \\ :idle) do
    player = put_in(PlayerState.new(character(id)).stats.progression.learned_skills, %{1 => 3, 223 => 1})
    %{player | action_state: action_state}
  end

  defp character(id) do
    %Character{
      id: id,
      account_id: id,
      name: "Rogue #{id}",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 12,
      base_level: 50,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }
  end

  defp register(player) do
    :ok = UnitRegistry.register_unit(:player, player.character_id, PlayerState, player, self())
    :ok = SpatialIndex.add_player(player.character_id, player.x, player.y, player.map_name)
  end
end

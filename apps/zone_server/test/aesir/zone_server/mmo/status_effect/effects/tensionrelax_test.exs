defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.TensionrelaxTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Tensionrelax
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    player =
      PlayerState.new(%Character{
        id: 5_112,
        account_id: 5_113,
        name: "LK",
        last_map: "prontera",
        last_x: 50,
        last_y: 50,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 90,
        job_level: 50,
        class: 7
      })

    :ok = UnitRegistry.register_player(player, self())
    %{player: player}
  end

  test "triples natural and skill HP regeneration" do
    assert %{hp_regen: 200, skill_hp_regen_rate: 200} =
             Tensionrelax.modifiers(%StatusEntry{}, %{})
  end

  test "ends when standing", %{player: player} do
    assert :remove =
             Tensionrelax.on_tick({:player, player.character_id}, %StatusEntry{}, %{
               target: %{hp: 100, max_hp: 500}
             })
  end

  test "ends at full HP even while sitting", %{player: player} do
    :ok =
      UnitRegistry.update_unit_state(:player, player.character_id, %{
        player
        | action_state: :sitting
      })

    assert :remove =
             Tensionrelax.on_tick({:player, player.character_id}, %StatusEntry{}, %{
               target: %{hp: 500, max_hp: 500}
             })
  end

  test "continues while wounded and sitting", %{player: player} do
    :ok =
      UnitRegistry.update_unit_state(:player, player.character_id, %{
        player
        | action_state: :sitting
      })

    entry = %StatusEntry{}

    assert {:ok, ^entry} =
             Tensionrelax.on_tick({:player, player.character_id}, entry, %{
               target: %{hp: 100, max_hp: 500}
             })
  end
end

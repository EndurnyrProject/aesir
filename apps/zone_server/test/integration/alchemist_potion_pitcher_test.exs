defmodule Aesir.ZoneServer.Integration.AlchemistPotionPitcherTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPotionpitcher
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @moduletag :capture_log

  test "pitching a potion heals a party member through their real session" do
    caster_session =
      start_player_session(id: 23_101, name: "Pitcher", learned_skills: %{227 => 0})

    target_session = start_player_session(id: 23_102, name: "Recipient", vit: 10)

    start_hp = get_player_state(target_session.pid).stats.current_state.hp
    PlayerSession.apply_damage(target_session.pid, start_hp - 1, nil)
    assert get_player_state(target_session.pid).stats.current_state.hp == 1

    target = %{get_player_state(target_session.pid) | party_id: 7}
    :ok = UnitRegistry.update_unit_state(:player, target.character_id, target)

    caster = %{
      get_player_state(caster_session.pid)
      | party_id: 7,
        inventory: %{0 => %InventoryItem{nameid: 501, amount: 1, equip: 0}}
    }

    {:ok, definition} = Catalog.by_id(231)

    assert {:ok, _updated} =
             AmPotionpitcher.cast(caster, {:unit, target.character_id}, 1, definition)

    assert get_player_state(target_session.pid).stats.current_state.hp > 1
  end
end

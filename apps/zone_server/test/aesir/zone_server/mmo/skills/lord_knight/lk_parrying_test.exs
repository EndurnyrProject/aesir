defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkParryingTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.LordKnight.LkParrying
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  test "requires a two-handed sword and applies Parrying at the cast level" do
    assert {:ok, definition} = Catalog.by_name(:lk_parrying)
    assert definition.id == 356
    assert definition.sp_cost == List.duplicate(50, 10)
    player = player()

    assert {:error, :wrong_weapon} = LkParrying.validate(player, :self, 7, definition)
    one_hand = put_in(player.stats.equipment, %Equipment{right_hand: 1101})
    assert {:error, :wrong_weapon} = LkParrying.validate(one_hand, :self, 7, definition)

    two_hand = put_in(player.stats.equipment, %Equipment{right_hand: 1116, left_hand: 1116})
    assert :ok = LkParrying.validate(two_hand, :self, 7, definition)
    :ok = UnitRegistry.register_player(two_hand, self())
    assert {:ok, ^two_hand} = LkParrying.cast(two_hand, :self, 7, definition)
    assert %{val1: 7} = StatusStorage.get_status(:player, two_hand.character_id, :sc_parrying)
  end

  defp player do
    PlayerState.new(%Character{
      id: 5_103,
      account_id: 5_104,
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
  end
end

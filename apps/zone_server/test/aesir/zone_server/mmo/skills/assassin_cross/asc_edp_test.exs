defmodule Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscEdpTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscEdp
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "casting preserves the weapon element and grants the mode's poison share beside EDP" do
    player = player()
    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())
    assert {:ok, ^player} = AscEdp.cast(player, :self, 5, AscEdp.definition())
    assert %{val1: 5, val2: 5} = StatusStorage.get_status(:player, 1, :sc_edp)
    aura = if GameMode.mode() == :renewal, do: :sc_sub_weaponproperty, else: :sc_watk_element
    assert %{val1: 5, val2: 25} = StatusStorage.get_status(:player, 1, aura)
    refute StatusStorage.has_status?(:player, 1, :sc_encpoison)
    Interpreter.remove_status(:player, 1, :sc_edp)
    assert StatusStorage.has_status?(:player, 1, aura)
  end

  test "renewal requires a right-hand weapon, classic permits bare hands" do
    player = player()
    expected = if GameMode.mode() == :renewal, do: {:error, :wrong_weapon}, else: {:ok, player}
    assert AscEdp.begin_attempt(player, :self, 1, AscEdp.definition()) == expected
    equipped = put_in(player.stats.equipment.right_hand, 1201)
    assert {:ok, ^equipped} = AscEdp.begin_attempt(equipped, :self, 1, AscEdp.definition())
  end

  test "bottle selection respects mode, preferring the bound renewal bottle even in a later slot" do
    player = %{
      player()
      | inventory: %{
          0 => %InventoryItem{nameid: 678, amount: 1},
          5 => %InventoryItem{nameid: 22_549, amount: 1}
        }
    }

    id = if GameMode.mode() == :renewal, do: 22_549, else: 678

    assert AscEdp.dynamic_item_cost(player, :self, 1, AscEdp.definition()) == [
             %{id: id, amount: 1}
           ]

    player = %{player | inventory: %{0 => %InventoryItem{nameid: 678, amount: 1}}}

    assert AscEdp.dynamic_item_cost(player, :self, 1, AscEdp.definition()) == [
             %{id: 678, amount: 1}
           ]
  end

  defp player do
    PlayerStateFixture.build(%{
      character_id: 1,
      map_name: "prontera",
      stats: %{combat_stats: %CombatStats{}}
    })
  end
end

defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrMacemasteryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrMacemastery

  test "grants 3 ATK per level while wielding either mace type" do
    for weapon <- [:mace, :two_handed_mace] do
      assert PrMacemastery.atk_bonus(1, %{weapon_type: weapon}) == 3
      assert PrMacemastery.atk_bonus(10, %{weapon_type: weapon}) == 30
    end
  end

  @tag game_mode: :renewal
  test "Renewal grants 10 critical tenths per level with either mace type" do
    for weapon <- [:mace, :two_handed_mace] do
      assert PrMacemastery.critical_bonus(1, %{weapon_type: weapon}) == 10
      assert PrMacemastery.critical_bonus(5, %{weapon_type: weapon}) == 50
      assert PrMacemastery.critical_bonus(10, %{weapon_type: weapon}) == 100
    end
  end

  @tag game_mode: :pre_renewal
  test "classic grants no critical bonus with either mace type" do
    for weapon <- [:mace, :two_handed_mace] do
      assert PrMacemastery.critical_bonus(1, %{weapon_type: weapon}) == 0
      assert PrMacemastery.critical_bonus(5, %{weapon_type: weapon}) == 0
      assert PrMacemastery.critical_bonus(10, %{weapon_type: weapon}) == 0
    end
  end

  test "grants no bonuses with other weapons" do
    assert PrMacemastery.atk_bonus(10, %{weapon_type: :staff}) == 0
    assert PrMacemastery.critical_bonus(10, %{weapon_type: :staff}) == 0
  end
end

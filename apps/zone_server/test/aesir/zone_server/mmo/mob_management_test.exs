defmodule Aesir.ZoneServer.Mmo.MobManagementTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop

  setup :setup_ets_tables

  describe "mob data loading" do
    test "loads Poring correctly" do
      assert {:ok, poring} = MobManagement.get_mob_by_id(1002)
      assert %MobDefinition{} = poring
      assert poring.id == 1002
      assert poring.aegis_name == "PORING"
      assert poring.name == "Poring"
      assert poring.level == 1
      assert poring.race == :plant
      assert poring.element == {:water, 1}
    end

    test "normalizes the on-disk demihuman spelling to :demi_human" do
      assert {:ok, orc_warrior} = MobManagement.get_mob_by_id(1023)
      assert orc_warrior.race == :demi_human
    end

    test "loads mob by aegis name" do
      assert {:ok, poring} = MobManagement.get_mob_by_name("PORING")
      assert poring.id == 1002
    end

    test "returns error for non-existent mob" do
      assert {:error, :mob_not_found} = MobManagement.get_mob_by_id(99_999)
      assert {:error, :mob_not_found} = MobManagement.get_mob_by_name("NON_EXISTENT")
    end

    test "loads all mobs" do
      mobs = MobManagement.get_all_mobs()
      assert length(mobs) > 0
      assert Enum.all?(mobs, &match?(%MobDefinition{}, &1))
    end
  end

  describe "spawn data loading" do
    test "loads spawn data for prt_fild01" do
      assert {:ok, spawns} = MobManagement.get_spawns_for_map("prt_fild01")
      assert length(spawns) > 0

      # Check for Poring spawn (mob id 1002)
      poring_spawns = Enum.filter(spawns, &(&1.mob == 1002))
      assert length(poring_spawns) > 0
    end

    test "returns error for map with no spawns" do
      assert {:error, :no_spawns} = MobManagement.get_spawns_for_map("non_existent_map")
    end
  end

  describe "mob calculations" do
    setup do
      {:ok, poring} = MobManagement.get_mob_by_id(1002)
      {:ok, poring: poring}
    end

    test "checks if mob is aggressive", %{poring: poring} do
      # Poring has ai_type: 2, which is not aggressive
      assert MobManagement.aggressive?(poring) == false
    end

    test "checks if mob can move", %{poring: poring} do
      # Poring has no movement restrictions
      assert MobManagement.can_move?(poring) == true
    end
  end

  describe "MVP reward fields at runtime" do
    test "loads mvp_drops as MobDrop structs, not raw maps" do
      assert {:ok, baphomet} = MobManagement.get_mob_by_id(1039)

      expected_exp = %{renewal: 109_044, pre_renewal: 53_625}[GameMode.mode()]
      assert baphomet.mvp_exp == expected_exp
      assert [%MobDrop{} | _] = baphomet.mvp_drops

      assert Enum.all?(baphomet.mvp_drops, &match?(%MobDrop{}, &1))

      {item, rate} =
        %{renewal: {"Bs_Making_S", 5000}, pre_renewal: {"Yggdrasilberry", 2000}}[GameMode.mode()]

      assert %MobDrop{item: ^item, rate: ^rate} = hd(baphomet.mvp_drops)
    end

    test "a non-MVP mob carries the field defaults" do
      assert {:ok, poring} = MobManagement.get_mob_by_id(1002)

      assert poring.mvp_exp == 0
      assert poring.mvp_drops == []
    end

    test "mvp_drops and drops stay separate at runtime" do
      assert {:ok, baphomet} = MobManagement.get_mob_by_id(1039)

      mvp_items = MapSet.new(baphomet.mvp_drops, & &1.item)
      drop_items = MapSet.new(baphomet.drops, & &1.item)

      assert MapSet.disjoint?(mvp_items, drop_items)
    end
  end
end

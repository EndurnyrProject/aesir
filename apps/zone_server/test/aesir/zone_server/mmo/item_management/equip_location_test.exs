defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipLocationTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation

  describe "location_atoms_to_bitmask/1" do
    test "maps single locations to their EQP bit" do
      assert EquipLocation.location_atoms_to_bitmask([:right_hand]) == 2
      assert EquipLocation.location_atoms_to_bitmask([:armor]) == 16
      assert EquipLocation.location_atoms_to_bitmask([:left_hand]) == 32
      assert EquipLocation.location_atoms_to_bitmask([:head_low]) == 1
      assert EquipLocation.location_atoms_to_bitmask([:head_mid]) == 512
      assert EquipLocation.location_atoms_to_bitmask([:head_top]) == 256
    end

    test "ORs multiple location atoms together" do
      assert EquipLocation.location_atoms_to_bitmask([:right_hand, :left_hand]) == 34
    end

    test "expands composite atoms to their combined bits" do
      assert EquipLocation.location_atoms_to_bitmask([:both_hand]) == 34
      assert EquipLocation.location_atoms_to_bitmask([:both_accessory]) == 136
    end

    test "empty list is zero" do
      assert EquipLocation.location_atoms_to_bitmask([]) == 0
    end
  end

  describe "bitmask_to_location_atoms/1" do
    test "decodes a single bit" do
      assert EquipLocation.bitmask_to_location_atoms(16) == [:armor]
    end

    test "decodes multiple bits into the canonical single-location atoms" do
      assert EquipLocation.bitmask_to_location_atoms(34) == [:right_hand, :left_hand]
      assert EquipLocation.bitmask_to_location_atoms(136) == [:right_accessory, :left_accessory]
    end

    test "round-trips single locations" do
      for atom <- [:right_hand, :armor, :left_hand, :head_top, :shoes, :garment, :ammo] do
        bitmask = EquipLocation.location_atoms_to_bitmask([atom])
        assert EquipLocation.bitmask_to_location_atoms(bitmask) == [atom]
      end
    end
  end

  describe "every distinct location atom in equip.yml" do
    test "maps to a non-zero bitmask" do
      atoms =
        ItemManagement.get_all_items()
        |> Enum.flat_map(& &1.locations)
        |> Enum.uniq()

      assert atoms != []

      for atom <- atoms do
        bitmask = EquipLocation.location_atoms_to_bitmask([atom])
        assert is_integer(bitmask) and bitmask > 0, "#{atom} mapped to #{inspect(bitmask)}"
      end
    end
  end
end

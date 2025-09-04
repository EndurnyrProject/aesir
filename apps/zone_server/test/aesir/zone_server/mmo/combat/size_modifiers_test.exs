defmodule Aesir.ZoneServer.Mmo.Combat.SizeModifiersTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers

  describe "get_modifier/2" do
    test "same size attacks should be 1.0" do
      assert SizeModifiers.get_modifier(:small, :small) == 1.0
      assert SizeModifiers.get_modifier(:medium, :medium) == 1.0
      assert SizeModifiers.get_modifier(:large, :large) == 1.0
    end

    test "small vs large should be 0.5 (penalty)" do
      assert SizeModifiers.get_modifier(:small, :large) == 0.5
    end

    test "large vs small should be 1.5 (bonus)" do
      assert SizeModifiers.get_modifier(:large, :small) == 1.5
    end

    test "medium vs small should be 1.25 (bonus)" do
      assert SizeModifiers.get_modifier(:medium, :small) == 1.25
    end

    test "medium vs large should be 0.75 (penalty)" do
      assert SizeModifiers.get_modifier(:medium, :large) == 0.75
    end

    test "unknown sizes should default to 1.0" do
      assert SizeModifiers.get_modifier(:invalid, :medium) == 1.0
      assert SizeModifiers.get_modifier(:small, :invalid) == 1.0
    end
  end

  describe "helper functions" do
    test "player_size/0 should return medium" do
      assert SizeModifiers.player_size() == :medium
    end

    test "weapon_size/1 should return medium for now" do
      assert SizeModifiers.weapon_size(:sword) == :medium
      assert SizeModifiers.weapon_size(:dagger) == :medium
    end
  end
end

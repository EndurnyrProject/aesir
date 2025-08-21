defmodule Aesir.ZoneServer.Mmo.StatusEffect.GameFunctionsTest do
  use ExUnit.Case, async: true
  import Mimic
  alias Aesir.ZoneServer.Mmo.StatusEffect.GameFunctions

  setup :verify_on_exit!

  describe "registry/0" do
    test "includes all required game functions" do
      registry = GameFunctions.registry()

      assert Map.has_key?(registry, "pc_checkskill")
      assert Map.has_key?(registry, "has_status")
      assert Map.has_key?(registry, "get_skill_level")
      assert Map.has_key?(registry, "is_equipped")
      assert Map.has_key?(registry, "job_level")
      assert Map.has_key?(registry, "base_level")
      assert Map.has_key?(registry, "random")
      assert Map.has_key?(registry, "pc_check_weapontype")
    end
  end

  describe "pc_check_weapontype/3" do
    test "returns 0 (false) in stub implementation" do
      context = %{target_id: "player_123"}

      # Test with single weapon type
      assert GameFunctions.pc_check_weapontype(context, :target, :dagger) == 0

      # Test with list of weapon types
      assert GameFunctions.pc_check_weapontype(context, :target, [:axe, :mace]) == 0

      # Test with different target selector
      assert GameFunctions.pc_check_weapontype(context, :caster, :spear) == 0
    end
  end

  describe "has_status/3 and has_status/2" do
    test "has_status/3 returns 0 (false) in stub implementation" do
      context = %{target_id: "player_123"}

      # Test with atom status
      assert GameFunctions.has_status(context, :target, :sc_poison) == 0

      # Test with string status
      assert GameFunctions.has_status(context, :target, "sc_curse") == 0
    end

    test "has_status/2 returns 0 (false) in stub implementation" do
      context = %{target_id: "player_123"}

      # Test with atom status
      assert GameFunctions.has_status(context, :sc_poison) == 0

      # Test with string status
      assert GameFunctions.has_status(context, "sc_curse") == 0
    end
  end
end

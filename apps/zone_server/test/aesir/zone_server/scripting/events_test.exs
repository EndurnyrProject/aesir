defmodule Aesir.ZoneServer.Scripting.EventsTest do
  use ExUnit.Case, async: true
  alias Aesir.ZoneServer.Scripting.Events

  # Define example scripts in the test file
  def example_scripts do
    %{
      healing_potion: """
      return {
        on_use = function()
          heal(500, 250)
          sc_start("SC_BLESSING", 60000, 10)
          return true
        end
      }
      """,
      blessed_armor: """
      return {
        on_equip = function()
          bonus("bStr", 5)
          bonus("bDex", 3)
          
          local refine = getrefine()
          if refine >= 7 then
            bonus("bAllStats", 1)
          end
          
          if refine >= 9 then
            bonus("bMaxHPrate", 5)
            bonus("bMaxSPrate", 5)
          end
          
          return true
        end,
        
        on_unequip = function()
          return true
        end
      }
      """,
      vampiric_sword: """
      return {
        on_equip = function()
          bonus("bStr", 10)
          bonus2("bHPDrainRate", 100, 5)
          autobonus("bonus('bCritical', 100)", 200, 5000)
          return true
        end,
        
        on_attack = function()
          local chance = rand(1, 100)
          if chance <= 10 then
            heal(100, 0)
          end
          return true
        end
      }
      """
    }
  end

  describe "valid_event?/1" do
    test "returns true for valid events" do
      assert Events.valid_event?(:on_use) == true
      assert Events.valid_event?(:on_equip) == true
      assert Events.valid_event?(:on_unequip) == true
      assert Events.valid_event?(:on_timer) == true
      assert Events.valid_event?(:on_login) == true
      assert Events.valid_event?(:on_logout) == true
      assert Events.valid_event?(:on_pc_die) == true
      assert Events.valid_event?(:on_pc_kill) == true
      assert Events.valid_event?(:on_npc_kill) == true
      assert Events.valid_event?(:on_cast_skill) == true
      assert Events.valid_event?(:on_use_skill) == true
      assert Events.valid_event?(:on_attack) == true
      assert Events.valid_event?(:on_consume) == true
      assert Events.valid_event?(:on_refine) == true
    end

    test "returns false for invalid events" do
      assert Events.valid_event?(:invalid_event) == false
      assert Events.valid_event?(:on_invalid) == false
      assert Events.valid_event?("on_use") == false
      assert Events.valid_event?(nil) == false
    end
  end

  describe "all_events/0" do
    test "returns list of all valid events" do
      events = Events.all_events()

      assert is_list(events)
      assert :on_use in events
      assert :on_equip in events
      assert :on_unequip in events
      assert length(events) >= 14
    end
  end

  describe "example scripts" do
    test "healing potion example has correct structure" do
      healing_script = example_scripts()[:healing_potion]

      assert String.contains?(healing_script, "on_use")
      assert String.contains?(healing_script, "heal")
      assert String.contains?(healing_script, "sc_start")
    end

    test "blessed armor example has correct structure" do
      armor_script = example_scripts()[:blessed_armor]

      assert String.contains?(armor_script, "on_equip")
      assert String.contains?(armor_script, "on_unequip")
      assert String.contains?(armor_script, "bonus")
      assert String.contains?(armor_script, "getrefine")
    end

    test "vampiric sword example has correct structure" do
      sword_script = example_scripts()[:vampiric_sword]

      assert String.contains?(sword_script, "on_equip")
      assert String.contains?(sword_script, "on_attack")
      assert String.contains?(sword_script, "autobonus")
      assert String.contains?(sword_script, "bonus2")
    end
  end

  describe "event_to_lua_name/1" do
    test "converts event atoms to lua function names" do
      assert Events.event_to_lua_name(:on_use) == "on_use"
      assert Events.event_to_lua_name(:on_equip) == "on_equip"
      assert Events.event_to_lua_name(:on_unequip) == "on_unequip"
      assert Events.event_to_lua_name(:invalid) == nil
    end
  end
end

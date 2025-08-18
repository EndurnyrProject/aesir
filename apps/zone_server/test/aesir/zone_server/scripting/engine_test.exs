defmodule Aesir.ZoneServer.Scripting.EngineTest do
  use ExUnit.Case
  alias Aesir.ZoneServer.Scripting.Engine

  setup do
    case Process.whereis(Aesir.ZoneServer.Scripting.Engine) do
      nil ->
        {:ok, _pid} = Engine.start_link()

      _pid ->
        Engine.clear_cache()
    end

    :ok
  end

  describe "load_script/2" do
    test "loads a script successfully" do
      script_code = """
      return {
        on_use = function()
          heal(100, 50)
          return true
        end
      }
      """

      assert :ok = Engine.load_script("test_item", script_code)
    end

    test "can load multiple scripts" do
      script1 = "return { on_use = function(p) return true end }"
      script2 = "return { on_equip = function(p) return true end }"

      assert :ok = Engine.load_script("item1", script1)
      assert :ok = Engine.load_script("item2", script2)
    end
  end

  describe "execute_script/3" do
    test "executes a simple healing script" do
      script_code = """
      return {
        on_use = function()
          heal(100, 50)
          return true
        end
      }
      """

      player_state = %{
        char_id: 150_000,
        name: "TestPlayer",
        base_level: 99,
        job_level: 50
      }

      Engine.load_script("healing_potion", script_code)
      assert {:ok, true} = Engine.execute_script("healing_potion", :on_use, player_state)
    end

    test "returns :no_handler for non-existent event" do
      script_code = """
      return {
        on_use = function()
          return true
        end
      }
      """

      Engine.load_script("test_item", script_code)
      assert {:ok, :no_handler} = Engine.execute_script("test_item", :on_equip, %{})
    end

    test "returns error for non-existent script" do
      assert {:error, :script_not_found} = Engine.execute_script("nonexistent", :on_use, %{})
    end

    test "executes script with bonus functions" do
      script_code = """
      return {
        on_equip = function()
          bonus("bStr", 10)
          bonus2("bAddRace", "RC_DemiHuman", 20)
          return true
        end
      }
      """

      player_state = %{char_id: 150_000}

      Engine.load_script("strong_sword", script_code)
      assert {:ok, true} = Engine.execute_script("strong_sword", :on_equip, player_state)
    end

    test "executes script with status effects" do
      script_code = """
      return {
        on_use = function()
          sc_start("SC_BLESSING", 60000, 10)
          sc_start("SC_INCREASEAGI", 60000, 10)
          return true
        end
      }
      """

      Engine.load_script("blessing_scroll", script_code)
      assert {:ok, true} = Engine.execute_script("blessing_scroll", :on_use, %{})
    end

    test "executes script with character info functions" do
      script_code = """
      return {
        on_use = function()
          local char_id = getcharid(0)
          local job = getbasejob()
          local level = getbaselevel()
          
          if level >= 50 then
            heal(1000, 500)
          else
            heal(500, 250)
          end
          
          return true
        end
      }
      """

      player_state = %{
        char_id: 150_000,
        job: 4001,
        base_level: 99
      }

      Engine.load_script("level_potion", script_code)
      assert {:ok, true} = Engine.execute_script("level_potion", :on_use, player_state)
    end

    test "executes script with random function" do
      script_code = """
      return {
        on_use = function()
          local chance = rand(1, 100)
          if chance <= 50 then
            getitem(501, 1)  -- Red Potion
          else
            getitem(502, 1)  -- Orange Potion
          end
          return true
        end
      }
      """

      Engine.load_script("random_box", script_code)
      assert {:ok, true} = Engine.execute_script("random_box", :on_use, %{})
    end

    test "handles complex equipment script" do
      script_code = """
      return {
        on_equip = function()
          local refine = getrefine()
          
          -- Base bonuses
          bonus("bStr", 5)
          bonus("bDex", 3)
          
          -- Refine bonuses
          if refine >= 7 then
            bonus("bAtkRate", 5)
          end
          
          if refine >= 9 then
            bonus("bAspd", 1)
            bonus2("bAddRace", "RC_DemiHuman", 10)
          end
          
          -- Autobonus on attack
          autobonus("bonus('bStr', 10)", 100, 5000)
          
          return true
        end,
        
        on_unequip = function()
          -- Cleanup is automatic
          return true
        end
      }
      """

      player_state = %{
        char_id: 150_000,
        refine: 10
      }

      Engine.load_script("refined_blade", script_code)
      assert {:ok, true} = Engine.execute_script("refined_blade", :on_equip, player_state)
      assert {:ok, true} = Engine.execute_script("refined_blade", :on_unequip, player_state)
    end

    test "sandbox prevents dangerous operations" do
      # Scripts trying to access forbidden functions should fail
      dangerous_scripts = [
        {"io_test", "return { on_use = function(p) io.write('hack') return true end }"},
        {"os_test", "return { on_use = function(p) os.execute('rm -rf /') return true end }"},
        {"require_test", "return { on_use = function(p) require('os') return true end }"},
        {"loadfile_test",
         "return { on_use = function(p) loadfile('/etc/passwd') return true end }"}
      ]

      for {name, script} <- dangerous_scripts do
        Engine.load_script(name, script)
        result = Engine.execute_script(name, :on_use, %{})
        # Should either error or return no handler due to sandbox
        assert match?({:error, _}, result) or match?({:ok, :no_handler}, result)
      end
    end

    test "handles syntax errors gracefully" do
      script_code = """
      return {
        on_use = function()
          this is not valid lua syntax!!!
        end
      }
      """

      Engine.load_script("broken", script_code)
      assert {:error, _} = Engine.execute_script("broken", :on_use, %{})
    end

    test "handles runtime errors gracefully" do
      script_code = """
      return {
        on_use = function()
          local x = nil
          return x.nonexistent_field  -- This will cause a runtime error
        end
      }
      """

      Engine.load_script("runtime_error", script_code)
      assert {:error, _} = Engine.execute_script("runtime_error", :on_use, %{})
    end
  end

  describe "clear_cache/0" do
    test "clears all cached scripts" do
      Engine.load_script("item1", "return {}")
      Engine.load_script("item2", "return {}")

      assert :ok = Engine.clear_cache()

      # Scripts should no longer exist
      assert {:error, :script_not_found} = Engine.execute_script("item1", :on_use, %{})
      assert {:error, :script_not_found} = Engine.execute_script("item2", :on_use, %{})
    end
  end

  describe "player context passing" do
    test "script can access player data" do
      script_code = """
      return {
        on_use = function()
          local char_id = getcharid(0)
          local account_id = getcharid(3)
          local job = getbasejob()
          local base_level = getbaselevel()
          local job_level = getjoblevel()
          
          -- These should match the player state we pass in
          return char_id == 150000 and 
                 account_id == 2000001 and
                 job == 4001 and
                 base_level == 99 and
                 job_level == 70
        end
      }
      """

      player_state = %{
        char_id: 150_000,
        account_id: 2_000_001,
        job: 4001,
        base_level: 99,
        job_level: 70
      }

      Engine.load_script("context_test", script_code)
      assert {:ok, true} = Engine.execute_script("context_test", :on_use, player_state)
    end
  end
end

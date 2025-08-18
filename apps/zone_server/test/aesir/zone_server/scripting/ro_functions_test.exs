defmodule Aesir.ZoneServer.Scripting.ROFunctionsTest do
  use ExUnit.Case, async: true
  alias Aesir.ZoneServer.Scripting.ROFunctions
  require Lua

  setup do
    lua_state =
      Lua.new()
      |> Lua.load_api(ROFunctions)

    {:ok, lua_state: lua_state}
  end

  describe "bonus functions" do
    test "bonus/2 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{name: "TestPlayer"})

      {[result], _} = Lua.eval!(lua, "return bonus('bStr', 10)")
      assert result == true
    end

    test "bonus2/3 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return bonus2('bAddRace', 'RC_DemiHuman', 20)")
      assert result == true
    end

    test "bonus3/4 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return bonus3('bAutoSpell', 'AL_HEAL', 3, 100)")
      assert result == true
    end

    test "bonus4/5 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} =
        Lua.eval!(lua, "return bonus4('bAutoSpellOnSkill', 'SM_BASH', 'AL_HEAL', 1, 100)")

      assert result == true
    end

    test "bonus5/6 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} =
        Lua.eval!(lua, "return bonus5('bAutoSpell', 'AL_HEAL', 1, 100, 'BF_WEAPON', 1)")

      assert result == true
    end
  end

  describe "status effect functions" do
    test "sc_start/3 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return sc_start('SC_BLESSING', 60000, 10)")
      assert result == true
    end

    test "sc_start2/4 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return sc_start2('SC_POISON', 30000, 10, 1000)")
      assert result == true
    end

    test "sc_start4/6 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return sc_start4('SC_BURNING', 10000, 1, 2, 3, 4)")
      assert result == true
    end

    test "sc_end/1 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return sc_end('SC_BLESSING')")
      assert result == true
    end
  end

  describe "healing functions" do
    test "heal/2 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return heal(100, 50)")
      assert result == true
    end

    test "percentheal/2 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return percentheal(50, 25)")
      assert result == true
    end

    test "itemheal/2 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return itemheal(200, 100)")
      assert result == true
    end
  end

  describe "character info functions" do
    test "getcharid/1 returns correct IDs", %{lua_state: lua} do
      player = %{
        char_id: 150_000,
        party_id: 1,
        guild_id: 2,
        account_id: 2_000_001
      }

      lua = Lua.put_private(lua, :current_player, player)

      {[char_id], _} = Lua.eval!(lua, "return getcharid(0)")
      assert char_id == 150_000

      {[party_id], _} = Lua.eval!(lua, "return getcharid(1)")
      assert party_id == 1

      {[guild_id], _} = Lua.eval!(lua, "return getcharid(2)")
      assert guild_id == 2

      {[account_id], _} = Lua.eval!(lua, "return getcharid(3)")
      assert account_id == 2_000_001
    end

    test "getbasejob/0 returns job", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{job: 4001})

      {[job], _} = Lua.eval!(lua, "return getbasejob()")
      assert job == 4001
    end

    test "getjoblevel/0 returns job level", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{job_level: 70})

      {[level], _} = Lua.eval!(lua, "return getjoblevel()")
      assert level == 70
    end

    test "getbaselevel/0 returns base level", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{base_level: 99})

      {[level], _} = Lua.eval!(lua, "return getbaselevel()")
      assert level == 99
    end

    test "getskilllv/1 returns skill level", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[level], _} = Lua.eval!(lua, "return getskilllv('SM_BASH')")
      # Mock value
      assert level == 10
    end
  end

  describe "item functions" do
    test "getitem/2 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return getitem(501, 10)")
      assert result == true
    end

    test "getitem2/9 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return getitem2(1201, 1, 1, 7, 0, 4001, 4002, 4003, 4004)")
      assert result == true
    end

    test "delitem/2 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return delitem(501, 5)")
      assert result == true
    end

    test "countitem/1 returns item count", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[count], _} = Lua.eval!(lua, "return countitem(501)")
      # Mock value
      assert count == 5
    end

    test "checkweight/2 returns weight check", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[can_carry], _} = Lua.eval!(lua, "return checkweight(501, 100)")
      assert can_carry == 1
    end
  end

  describe "equipment functions" do
    test "getequipid/1 returns equipment ID", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[equip_id], _} = Lua.eval!(lua, "return getequipid(2)")
      # Mock value
      assert equip_id == 1101
    end

    test "getequipname/1 returns equipment name", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[name], _} = Lua.eval!(lua, "return getequipname(2)")
      assert name == "Sword"
    end

    test "getequiprefinerycnt/1 returns refine level", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[refine], _} = Lua.eval!(lua, "return getequiprefinerycnt(2)")
      # Mock value
      assert refine == 7
    end

    test "getrefine/0 returns current refine", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[refine], _} = Lua.eval!(lua, "return getrefine()")
      assert refine == 0
    end
  end

  describe "utility functions" do
    test "rand/2 returns value in range", %{lua_state: lua} do
      {[value], _} = Lua.eval!(lua, "return rand(1, 10)")
      assert value >= 1 and value <= 10
    end

    test "mes/1 displays message", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return mes('Hello World')")
      assert result == true
    end

    test "select/1 returns selection", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[selection], _} = Lua.eval!(lua, "return select({'Option 1', 'Option 2', 'Option 3'})")
      # Mock always returns first option
      assert selection == 1
    end

    test "close/0 closes dialog", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return close()")
      assert result == true
    end
  end

  describe "world functions" do
    test "warp/3 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return warp('prontera', 155, 180)")
      assert result == true
    end

    test "save/3 executes successfully", %{lua_state: lua} do
      lua = Lua.put_private(lua, :current_player, %{})

      {[result], _} = Lua.eval!(lua, "return save('prontera', 155, 180)")
      assert result == true
    end
  end

  describe "time functions" do
    test "gettimetick/1 returns timestamp", %{lua_state: lua} do
      {[tick], _} = Lua.eval!(lua, "return gettimetick(0)")
      assert is_number(tick)
      assert tick > 0
    end

    test "gettime/1 returns time component", %{lua_state: lua} do
      # Test each time component
      for type <- 1..7 do
        {[value], _} = Lua.eval!(lua, "return gettime(#{type})")
        assert is_number(value)
        assert value >= 0
      end
    end
  end

  describe "announcement functions" do
    test "announce/2 executes successfully", %{lua_state: lua} do
      {[result], _} = Lua.eval!(lua, "return announce('Server Message', 0)")
      assert result == true
    end

    test "mapannounce/3 executes successfully", %{lua_state: lua} do
      {[result], _} = Lua.eval!(lua, "return mapannounce('prontera', 'Map Message', 0)")
      assert result == true
    end

    test "getusers/1 returns user count", %{lua_state: lua} do
      {[count], _} = Lua.eval!(lua, "return getusers(0)")
      # Mock value
      assert count == 100
    end

    test "getmapusers/1 returns map user count", %{lua_state: lua} do
      {[count], _} = Lua.eval!(lua, "return getmapusers('prontera')")
      # Mock value
      assert count == 10
    end
  end
end

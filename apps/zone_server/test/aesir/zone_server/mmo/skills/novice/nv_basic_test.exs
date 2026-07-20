defmodule Aesir.ZoneServer.Mmo.Skills.Novice.NvBasicTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Novice.NvBasic

  @skill_id 1

  test "skill_name/0" do
    assert NvBasic.skill_name() == :nv_basic
  end

  test "definition/0 carries the NV_BASIC skill_db record" do
    defn = NvBasic.definition()

    assert defn.id == @skill_id
    assert defn.name == :nv_basic
    assert defn.display_name == "Basic Skill"
    assert defn.max_level == 9
    assert defn.target_type == :passive
  end

  test "__skill_capabilities__/0 advertises only :passive" do
    assert NvBasic.__skill_capabilities__() == [:passive]
  end

  describe "passive channels are all no-ops (NV_BASIC contributes nothing)" do
    setup do
      ctx = %{
        weapon_type: :one_handed_sword,
        base_level: 1,
        job_level: 1,
        max_hp: 100,
        max_sp: 50,
        vit: 1,
        int: 1
      }

      %{ctx: ctx}
    end

    test "atk_bonus is 0", %{ctx: ctx} do
      assert NvBasic.atk_bonus(9, ctx) == 0
    end

    test "flee_bonus is 0", %{ctx: ctx} do
      assert NvBasic.flee_bonus(9, ctx) == 0
    end

    test "dex_bonus is 0", %{ctx: ctx} do
      assert NvBasic.dex_bonus(9, ctx) == 0
    end

    test "hit_bonus is 0", %{ctx: ctx} do
      assert NvBasic.hit_bonus(9, ctx) == 0
    end

    test "range_bonus is 0", %{ctx: ctx} do
      assert NvBasic.range_bonus(9, ctx) == 0
    end

    test "attack_proc is empty", %{ctx: ctx} do
      assert NvBasic.attack_proc(9, ctx) == %{}
    end

    test "regen_contribution is empty", %{ctx: ctx} do
      assert NvBasic.regen_contribution(9, ctx) == %{}
    end

    test "skill_rider is :none", %{ctx: ctx} do
      assert NvBasic.skill_rider(:sm_bash, 10, 9, ctx) == :none
    end
  end

  describe "allows_action?/2" do
    test ":trade passes at NV_BASIC level 1+" do
      assert NvBasic.allows_action?(%{@skill_id => 1}, :trade) == :ok
      assert NvBasic.allows_action?(%{@skill_id => 9}, :trade) == :ok
    end

    test ":trade is blocked when unlearned (level 0)" do
      assert NvBasic.allows_action?(%{}, :trade) == {:error, :basic_skill_level}
    end

    test ":sit is blocked below level 3" do
      assert NvBasic.allows_action?(%{}, :sit) == {:error, :basic_skill_level}
      assert NvBasic.allows_action?(%{@skill_id => 2}, :sit) == {:error, :basic_skill_level}
    end

    test ":sit passes at level 3+" do
      assert NvBasic.allows_action?(%{@skill_id => 3}, :sit) == :ok
      assert NvBasic.allows_action?(%{@skill_id => 9}, :sit) == :ok
    end

    test ":party is blocked below level 7" do
      assert NvBasic.allows_action?(%{@skill_id => 6}, :party) == {:error, :basic_skill_level}
    end

    test ":party passes at level 7+" do
      assert NvBasic.allows_action?(%{@skill_id => 7}, :party) == :ok
      assert NvBasic.allows_action?(%{@skill_id => 9}, :party) == :ok
    end

    test "an empty learned map blocks every action" do
      for action <- [:trade, :emotion, :sit, :chat_room, :party] do
        assert NvBasic.allows_action?(%{}, action) == {:error, :basic_skill_level}
      end
    end

    test "level 9 (max) passes every action" do
      for action <- [:trade, :emotion, :sit, :chat_room, :party] do
        assert NvBasic.allows_action?(%{@skill_id => 9}, action) == :ok
      end
    end
  end
end

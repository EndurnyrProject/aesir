defmodule Aesir.ZoneServer.Mmo.Skill.PassiveTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  defmodule DefaultPassive do
    use Passive, skill: :test_passive
  end

  defmodule CustomAtkPassive do
    use Passive, skill: :custom_atk

    @impl true
    def atk_bonus(level, _ctx), do: level * 10
  end

  defmodule CustomRegenPassive do
    use Passive, skill: :custom_regen

    @impl true
    def regen_contribution(_level, _ctx), do: %{hp_regen: 50}
  end

  defmodule CustomRiderPassive do
    use Passive, skill: :custom_rider

    @impl true
    def skill_rider(_target_skill, _target_level, _passive_level, _ctx),
      do: {:apply_status, :stun, []}
  end

  @ctx %{
    weapon_type: :one_handed_sword,
    base_level: 50,
    job_level: 30,
    max_hp: 1000,
    max_sp: 200,
    vit: 10,
    int: 5
  }

  describe "use Skill.Passive defaults" do
    test "skill_name/0 returns the skill atom" do
      assert DefaultPassive.skill_name() == :test_passive
    end

    test "atk_bonus/2 returns 0" do
      assert DefaultPassive.atk_bonus(1, @ctx) == 0
    end

    test "regen_contribution/2 returns empty map" do
      assert DefaultPassive.regen_contribution(1, @ctx) == %{}
    end

    test "skill_rider/4 returns :none" do
      assert DefaultPassive.skill_rider(:any, 1, 1, @ctx) == :none
    end
  end

  describe "overriding a single callback" do
    test "overriding atk_bonus replaces only that default" do
      assert CustomAtkPassive.skill_name() == :custom_atk
      assert CustomAtkPassive.atk_bonus(3, @ctx) == 30
      assert CustomAtkPassive.regen_contribution(1, @ctx) == %{}
      assert CustomAtkPassive.skill_rider(:any, 1, 1, @ctx) == :none
    end

    test "overriding regen_contribution replaces only that default" do
      assert CustomRegenPassive.skill_name() == :custom_regen
      assert CustomRegenPassive.atk_bonus(1, @ctx) == 0
      assert CustomRegenPassive.regen_contribution(1, @ctx) == %{hp_regen: 50}
      assert CustomRegenPassive.skill_rider(:any, 1, 1, @ctx) == :none
    end

    test "overriding skill_rider replaces only that default" do
      assert CustomRiderPassive.skill_name() == :custom_rider
      assert CustomRiderPassive.atk_bonus(1, @ctx) == 0
      assert CustomRiderPassive.regen_contribution(1, @ctx) == %{}
      assert CustomRiderPassive.skill_rider(:sm_bash, 6, 1, @ctx) == {:apply_status, :stun, []}
    end
  end
end

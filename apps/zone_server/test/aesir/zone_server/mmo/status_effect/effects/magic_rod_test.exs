defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicRodTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicRod
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEntry

  setup :set_mimic_private
  setup :verify_on_exit!

  @target {:player, 1000}

  defp entry(level),
    do: %StatusEntry{type: :sc_magicrod, state: %{}, val1: level, val2: 20 * level}

  defp magic_hit(opts \\ []) do
    %{
      dmg_type: :magic,
      from_caster?: true,
      skill_id: Keyword.get(opts, :skill_id, 19),
      skill_level: Keyword.get(opts, :skill_level, 10)
    }
  end

  defp stub_sp_cost(skill_id, sp_cost) do
    stub(Catalog, :by_id, fn ^skill_id ->
      {:ok,
       %Definition{
         id: skill_id,
         name: :stub,
         display_name: "Stub",
         max_level: 10,
         sp_cost: sp_cost
       }}
    end)
  end

  describe "direct magic interception" do
    test "refunds the raw spell cost times the status percentage" do
      stub_sp_cost(19, List.duplicate(30, 10))
      expect(Helpers, :restore_sp, fn @target, 30 -> :ok end)
      assert :miss == MagicRod.intercept(@target, entry(5), magic_hit())
    end

    test "lower levels refund a fraction" do
      stub_sp_cost(19, List.duplicate(30, 10))
      expect(Helpers, :restore_sp, fn @target, 6 -> :ok end)
      assert :miss == MagicRod.intercept(@target, entry(1), magic_hit())
    end

    test "an unknown skill is still intercepted without a refund" do
      stub(Catalog, :by_id, fn 9_999 -> :error end)
      expect(Helpers, :restore_sp, fn @target, 0 -> :ok end)
      assert :miss == MagicRod.intercept(@target, entry(5), magic_hit(skill_id: 9_999))
    end

    test "a direct splash is intercepted as well" do
      stub_sp_cost(17, List.duplicate(25, 10))
      expect(Helpers, :restore_sp, fn @target, 25 -> :ok end)
      assert :miss == MagicRod.intercept(@target, entry(5), magic_hit(skill_id: 17))
    end
  end

  describe "Water Ball refund" do
    test "above level 1 divides the refund by the odd level squared" do
      stub_sp_cost(86, [15, 20, 20, 25, 25])
      expect(Helpers, :restore_sp, fn @target, 1 -> :ok end)

      assert :miss ==
               MagicRod.intercept(@target, entry(5), magic_hit(skill_id: 86, skill_level: 4))
    end

    test "level 1 does not divide the refund" do
      stub_sp_cost(86, [15, 20, 20, 25, 25])
      expect(Helpers, :restore_sp, fn @target, 15 -> :ok end)

      assert :miss ==
               MagicRod.intercept(@target, entry(5), magic_hit(skill_id: 86, skill_level: 1))
    end
  end

  describe "ineligible hits" do
    test "a ground skill unit or status tick is not intercepted" do
      reject(&Helpers.restore_sp/2)

      assert :continue ==
               MagicRod.intercept(@target, entry(5), %{magic_hit() | from_caster?: false})

      assert :continue ==
               MagicRod.intercept(@target, entry(5), %{
                 magic_hit()
                 | from_caster?: false,
                   skill_id: nil
               })
    end

    test "physical, misc, and basic attacks pass through" do
      reject(&Helpers.restore_sp/2)

      assert :continue ==
               MagicRod.intercept(@target, entry(5), %{magic_hit() | dmg_type: :physical})

      assert :continue == MagicRod.intercept(@target, entry(5), %{magic_hit() | dmg_type: :misc})
      assert :continue == MagicRod.intercept(@target, entry(5), %{magic_hit() | skill_id: nil})
    end
  end
end

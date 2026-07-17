defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicRodTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicRod
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEntry

  setup :verify_on_exit!

  @target {:player, 1000}

  # Magic Rod at `level`: val2 = 20 * level, the percent of the spell's SP cost
  # gained on absorb.
  defp entry(level),
    do: %StatusEntry{type: :sc_magicrod, state: %{}, val1: level, val2: 20 * level}

  # A single-target magic hit from `skill_id` cast at `skill_level`.
  defp magic_hit(opts \\ []) do
    %{
      damage: 1_000,
      dmg_type: :magic,
      is_short: false,
      element: :fire,
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

  describe "absorb_damage/4 - single-target magic" do
    test "zeroes the damage and heals SP = spell_sp * 20 * level / 100" do
      # Fire Bolt lv10 costs 30 SP; Magic Rod lv5 => 30 * 100 / 100 = 30 SP.
      stub_sp_cost(19, List.duplicate(30, 10))
      expect(Helpers, :restore_sp, fn @target, 30 -> :ok end)

      assert {:ok, 0, %StatusEntry{}} =
               MagicRod.absorb_damage(@target, entry(5), magic_hit(), %{})
    end

    test "heals a fraction of the spell SP at lower Magic Rod levels" do
      # Magic Rod lv1 => 30 * 20 / 100 = 6 SP.
      stub_sp_cost(19, List.duplicate(30, 10))
      expect(Helpers, :restore_sp, fn @target, 6 -> :ok end)

      assert {:ok, 0, %StatusEntry{}} =
               MagicRod.absorb_damage(@target, entry(1), magic_hit(), %{})
    end

    test "absorbs the hit but gains no SP when the skill is not in the catalog" do
      stub(Catalog, :by_id, fn 9_999 -> :error end)
      expect(Helpers, :restore_sp, fn @target, 0 -> :ok end)

      hit = magic_hit(skill_id: 9_999)

      assert {:ok, 0, %StatusEntry{}} = MagicRod.absorb_damage(@target, entry(5), hit, %{})
    end
  end

  describe "absorb_damage/4 - Water Ball SP split (skill.cpp:2864-2875)" do
    test "above level 1 divides the gain by (lv ||| 1) squared" do
      # Water Ball lv4 costs 25 SP. Magic Rod lv5 => 25 * 100 / 100 = 25,
      # then 25 / ((4|1) * (4|1)) = 25 / 25 = 1 SP for the single ball absorbed.
      stub_sp_cost(86, [15, 20, 20, 25, 25])
      expect(Helpers, :restore_sp, fn @target, 1 -> :ok end)

      hit = magic_hit(skill_id: 86, skill_level: 4)

      assert {:ok, 0, %StatusEntry{}} = MagicRod.absorb_damage(@target, entry(5), hit, %{})
    end

    test "at level 1 the split does not apply" do
      # Water Ball lv1 costs 15 SP; Magic Rod lv5 => 15 * 100 / 100 = 15 SP, undivided.
      stub_sp_cost(86, [15, 20, 20, 25, 25])
      expect(Helpers, :restore_sp, fn @target, 15 -> :ok end)

      hit = magic_hit(skill_id: 86, skill_level: 1)

      assert {:ok, 0, %StatusEntry{}} = MagicRod.absorb_damage(@target, entry(5), hit, %{})
    end
  end

  # rAthena's `src == dsrc` asks whether the spell came from the caster, not
  # whether it hit one target: a direct cast's splash is still absorbed.
  describe "absorb_damage/4 - splash from a direct cast" do
    test "absorbs a Fireball splash hit and converts it to SP" do
      # Fireball lv10 costs 25 SP; Magic Rod lv5 => 25 * 100 / 100 = 25 SP.
      stub_sp_cost(17, List.duplicate(25, 10))
      expect(Helpers, :restore_sp, fn @target, 25 -> :ok end)

      hit = %{magic_hit(skill_id: 17) | from_caster?: true}

      assert {:ok, 0, %StatusEntry{}} = MagicRod.absorb_damage(@target, entry(5), hit, %{})
    end
  end

  # Over-absorbing is the dangerous failure: the hook must fail closed for every
  # hit that does not positively assert magic damage sourced from the caster.
  describe "absorb_damage/4 - hits that must pass through untouched" do
    test "does not absorb ground skill-unit magic (Storm Gust, Fire Wall)" do
      reject(&Helpers.restore_sp/2)
      hit = %{magic_hit() | from_caster?: false, skill_id: nil, skill_level: nil}

      assert {:ok, 1_000, %StatusEntry{}} = MagicRod.absorb_damage(@target, entry(5), hit, %{})
    end

    test "does not absorb a status DoT tick" do
      reject(&Helpers.restore_sp/2)

      hit = %{
        magic_hit()
        | from_caster?: false,
          skill_id: nil,
          skill_level: nil,
          element: :poison
      }

      assert {:ok, 1_000, %StatusEntry{}} = MagicRod.absorb_damage(@target, entry(5), hit, %{})
    end

    test "does not absorb physical damage" do
      reject(&Helpers.restore_sp/2)
      hit = %{magic_hit() | dmg_type: :physical}

      assert {:ok, 1_000, %StatusEntry{}} = MagicRod.absorb_damage(@target, entry(5), hit, %{})
    end

    test "does not absorb misc damage (traps)" do
      reject(&Helpers.restore_sp/2)
      hit = %{magic_hit() | dmg_type: :misc}

      assert {:ok, 1_000, %StatusEntry{}} = MagicRod.absorb_damage(@target, entry(5), hit, %{})
    end

    test "does not absorb a basic attack carrying no skill_id" do
      reject(&Helpers.restore_sp/2)
      hit = %{magic_hit() | dmg_type: :physical, skill_id: nil, skill_level: nil}

      assert {:ok, 1_000, %StatusEntry{}} = MagicRod.absorb_damage(@target, entry(5), hit, %{})
    end
  end

  describe "metadata" do
    test "is a dispellable, unsaved buff per rAthena status.yml (NoSave, no NoDispell)" do
      assert :sc_magicrod = MagicRod.id()

      assert %{no_dispel: false, no_save: true, properties: [:buff], icon: :magicrod} =
               MagicRod.metadata()
    end
  end
end

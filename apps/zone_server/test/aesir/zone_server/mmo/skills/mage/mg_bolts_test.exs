defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgBoltsTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgColdbolt
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgFirebolt
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgLightningbolt
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  @target_id 2000

  defp caster, do: %PlayerState{character_id: 1000}

  defp definition(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition
  end

  @cast_time [500, 800, 1100, 1400, 1700, 2000, 2300, 2600, 2900, 3200]
  @classic_cast_time [700, 1400, 2100, 2800, 3500, 4200, 4900, 5600, 6300, 7000]
  @fixed_cast_time [300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200]
  @after_cast_delay List.duplicate(1400, 10)
  @classic_after_cast_delay [1000, 1200, 1400, 1600, 1800, 2000, 2200, 2400, 2600, 2800]
  @sp_cost [12, 14, 16, 18, 20, 22, 24, 26, 28, 30]

  describe "metadata" do
    for {name, element} <- [
          {:mg_firebolt, :fire},
          {:mg_coldbolt, :water},
          {:mg_lightningbolt, :wind}
        ] do
      test "#{name} matches the source renewal table" do
        definition = definition(unquote(name))

        assert definition.max_level == 10
        assert definition.target_type == :target_enemy
        assert definition.damage_type == :damage
        assert definition.damage_kind == :magic
        assert definition.range == 9
        assert definition.element == unquote(element)
        assert definition.fixed_cast_time == @fixed_cast_time
        assert definition.sp_cost == @sp_cost
      end
    end

    for module <- [MgColdbolt, MgFirebolt, MgLightningbolt] do
      test "#{module} casts and locks the caster far longer per level in classic" do
        assert unquote(module).definition(:renewal).cast_time == @cast_time
        assert unquote(module).definition(:pre_renewal).cast_time == @classic_cast_time

        assert unquote(module).definition(:renewal).after_cast_delay == @after_cast_delay

        assert unquote(module).definition(:pre_renewal).after_cast_delay ==
                 @classic_after_cast_delay
      end
    end
  end

  describe "cast/4" do
    for {module, name, element} <- [
          {MgFirebolt, :mg_firebolt, :fire},
          {MgColdbolt, :mg_coldbolt, :water},
          {MgLightningbolt, :mg_lightningbolt, :wind}
        ] do
      test "#{name} issues level magic hits of its element" do
        caster = caster()
        definition = definition(unquote(name))

        expect(Combat, :execute_magic_attack, fn ^caster, @target_id, opts ->
          assert opts[:skill_id] == unquote(module).definition().id
          assert opts[:skill_level] == 7
          assert opts[:skill_ratio] == 100
          assert opts[:hit_count] == 7
          assert opts[:element] == unquote(element)
          {:ok, {:mob, @target_id}}
        end)

        assert {:ok, ^caster} =
                 unquote(module).cast(caster, {:unit, @target_id}, 7, definition)
      end

      test "#{name} propagates an attack error" do
        caster = caster()
        definition = definition(unquote(name))

        stub(Combat, :execute_magic_attack, fn ^caster, @target_id, _opts ->
          {:error, :target_out_of_range}
        end)

        assert {:error, :target_out_of_range} =
                 unquote(module).cast(caster, {:unit, @target_id}, 7, definition)
      end
    end
  end
end

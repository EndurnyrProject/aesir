defmodule Aesir.ZoneServer.Mmo.Skills.MgSoulstrikeFrostdiverTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.MgFrostdiver
  alias Aesir.ZoneServer.Mmo.Skills.MgSoulstrike
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 2000

  defp caster, do: %PlayerState{character_id: 1000}

  defp definition(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition
  end

  defp combatant(attrs) do
    base = %{
      unit_id: @target_id,
      unit_type: :mob,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{
        atk: 1,
        def: 1,
        hit: 1,
        flee: 1,
        perfect_dodge: 0,
        matk: 1,
        mdef: 1,
        soft_mdef: 1
      },
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 1,
      attack_delay_ms: 1000
    }

    Combatant.new!(Map.merge(base, attrs))
  end

  describe "catalog registration" do
    test "by_id/1 resolves the skill ids" do
      assert {:ok, %{name: :mg_soulstrike}} = Catalog.by_id(13)
      assert {:ok, %{name: :mg_frostdiver}} = Catalog.by_id(15)
    end

    test "by_name/1 resolves the skill atoms" do
      assert {:ok, %{id: 13}} = Catalog.by_name(:mg_soulstrike)
      assert {:ok, %{id: 15}} = Catalog.by_name(:mg_frostdiver)
    end

    test "active_module_for/1 resolves the modules" do
      assert {:ok, MgSoulstrike} = Catalog.active_module_for(:mg_soulstrike)
      assert {:ok, MgFrostdiver} = Catalog.active_module_for(:mg_frostdiver)
    end
  end

  describe "soul strike metadata" do
    test "matches the rAthena renewal table" do
      definition = definition(:mg_soulstrike)

      assert definition.max_level == 10
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.damage_kind == :magic
      assert definition.range == 9
      assert definition.element == :ghost
      assert definition.cast_time == List.duplicate(400, 10)
      assert definition.fixed_cast_time == List.duplicate(100, 10)
      assert definition.after_cast_delay == List.duplicate(1400, 10)
      assert definition.sp_cost == [18, 14, 24, 20, 30, 26, 36, 32, 42, 38]
    end
  end

  describe "soul strike cast/4" do
    test "hit counts follow the level table" do
      caster = caster()
      definition = definition(:mg_soulstrike)
      target = combatant(%{})

      for {hits, level} <- Enum.with_index([1, 1, 2, 2, 3, 3, 4, 4, 5, 5], 1) do
        stub(Combat, :resolve_combatant, fn @target_id -> {:ok, target} end)

        expect(Combat, :execute_magic_attack, fn ^caster, @target_id, opts ->
          assert opts[:hit_count] == hits
          assert opts[:element] == :ghost
          assert opts[:skill_ratio] == 100
          :ok
        end)

        assert {:ok, ^caster} =
                 MgSoulstrike.cast(caster, {:unit, @target_id}, level, definition)
      end
    end

    test "non-undead target uses base 100 ratio" do
      caster = caster()
      definition = definition(:mg_soulstrike)
      target = combatant(%{race: :formless, element: {:neutral, 1}})

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, target} end)

      expect(Combat, :execute_magic_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 100
        :ok
      end)

      assert {:ok, ^caster} = MgSoulstrike.cast(caster, {:unit, @target_id}, 8, definition)
    end

    test "undead-race target adds 5*level ratio" do
      caster = caster()
      definition = definition(:mg_soulstrike)
      target = combatant(%{race: :undead, element: {:neutral, 1}})

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, target} end)

      expect(Combat, :execute_magic_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 100 + 5 * 8
        :ok
      end)

      assert {:ok, ^caster} = MgSoulstrike.cast(caster, {:unit, @target_id}, 8, definition)
    end

    test "undead-element target adds 5*level ratio" do
      caster = caster()
      definition = definition(:mg_soulstrike)
      target = combatant(%{race: :formless, element: {:undead, 1}})

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, target} end)

      expect(Combat, :execute_magic_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 100 + 5 * 3
        :ok
      end)

      assert {:ok, ^caster} = MgSoulstrike.cast(caster, {:unit, @target_id}, 3, definition)
    end

    test "propagates an attack error" do
      caster = caster()
      definition = definition(:mg_soulstrike)
      target = combatant(%{})

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, target} end)

      stub(Combat, :execute_magic_attack, fn ^caster, @target_id, _opts ->
        {:error, :target_out_of_range}
      end)

      assert {:error, :target_out_of_range} =
               MgSoulstrike.cast(caster, {:unit, @target_id}, 5, definition)
    end
  end

  describe "frost diver metadata" do
    test "matches the rAthena renewal table" do
      definition = definition(:mg_frostdiver)

      assert definition.max_level == 10
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.damage_kind == :magic
      assert definition.range == 9
      assert definition.element == :water
      assert definition.cast_time == List.duplicate(640, 10)
      assert definition.fixed_cast_time == List.duplicate(160, 10)
      assert definition.after_cast_delay == List.duplicate(500, 10)
      assert definition.sp_cost == [25, 24, 23, 22, 21, 20, 19, 18, 17, 16]
    end
  end

  describe "frost diver cast/4" do
    test "ratio is 100 + 10*level with a single hit" do
      caster = caster()
      definition = definition(:mg_frostdiver)

      expect(Combat, :execute_magic_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 100 + 10 * 6
        assert opts[:hit_count] == 1
        assert opts[:element] == :water
        {:error, :target_out_of_range}
      end)

      assert {:error, :target_out_of_range} =
               MgFrostdiver.cast(caster, {:unit, @target_id}, 6, definition)
    end

    test "applies sc_freeze for 3000*level ms when the roll succeeds" do
      # Seed {1,2,3} yields :rand.uniform(100) == 27, below every freeze chance.
      :rand.seed(:exsss, {1, 2, 3})
      caster = caster()
      definition = definition(:mg_frostdiver)

      stub(Combat, :execute_magic_attack, fn _, _, _ -> :ok end)
      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_freeze, params ->
        assert params[:duration] == 3000 * 4
        :ok
      end)

      assert {:ok, ^caster} = MgFrostdiver.cast(caster, {:unit, @target_id}, 4, definition)
    end

    test "does not apply sc_freeze when the roll fails" do
      # Seed {6,7,8} yields :rand.uniform(100) == 87, above every freeze chance.
      :rand.seed(:exsss, {6, 7, 8})
      caster = caster()
      definition = definition(:mg_frostdiver)

      stub(Combat, :execute_magic_attack, fn _, _, _ -> :ok end)
      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = MgFrostdiver.cast(caster, {:unit, @target_id}, 4, definition)
    end

    test "does not freeze when the attack misses" do
      caster = caster()
      definition = definition(:mg_frostdiver)

      stub(Combat, :execute_magic_attack, fn _, _, _ -> {:error, :target_out_of_range} end)
      reject(&StatusInterpreter.apply_status/4)

      assert {:error, :target_out_of_range} =
               MgFrostdiver.cast(caster, {:unit, @target_id}, 4, definition)
    end
  end
end

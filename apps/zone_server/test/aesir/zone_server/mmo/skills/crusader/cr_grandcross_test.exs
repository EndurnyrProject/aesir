defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcrossTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  @skill_id 254
  @map "prontera"
  @caster_id 1000
  @mob_id 5000
  @center {100, 100}

  defp definition do
    {:ok, definition} = Catalog.by_id(@skill_id)
    definition
  end

  defp group(overrides) do
    struct(
      %Group{
        group_id: 1,
        skill_id: @skill_id,
        skill_name: :cr_grandcross,
        level: 1,
        caster_id: @caster_id,
        caster_type: :player,
        map_name: @map,
        center: @center,
        origin: @center,
        cells: translated_cross(),
        state: %{hits_caster: true}
      },
      overrides
    )
  end

  defp translated_cross do
    {ox, oy} = @center
    Enum.map(Layout.cross(2), fn {dx, dy} -> {ox + dx, oy + dy} end)
  end

  describe "definition" do
    test "Catalog.by_id/1 resolves CR_GRANDCROSS" do
      assert definition().name == :cr_grandcross
      assert definition().max_level == 10
      assert definition().target_type == :self
      assert definition().damage_type == :damage
      assert definition().element == :holy
      assert definition().range == 9
      assert definition().hit_interval == 300
      assert definition().unit_duration == List.duplicate(900, 10)
      assert definition().hp_cost_rate == List.duplicate(20, 10)
      assert definition().sp_cost == [37, 44, 51, 58, 65, 72, 79, 86, 93, 100]
    end

    test "Catalog active and ground modules resolve cr_grandcross" do
      assert {:ok, CrGrandcross} = Catalog.active_module_for(:cr_grandcross)
      assert {:ok, CrGrandcross} = Catalog.ground_module_for(:cr_grandcross)
    end

    test "cast places the field at the caster cell" do
      caster = %{x: 123, y: 456}

      expect(Unit, :place, fn ^caster, :cr_grandcross, 3, {123, 456} ->
        {:ok, :group}
      end)

      assert {:ok, ^caster} = CrGrandcross.cast(caster, :self, 3, definition())
    end
  end

  describe "cost" do
    defp game_state(current_hp, max_hp) do
      %{
        stats: %{
          derived_stats: %{max_hp: max_hp},
          current_state: %{hp: current_hp, sp: 200}
        }
      }
    end

    test "costs exactly 20% of max HP at cast" do
      cost = Cost.from_definition(game_state(1000, 1000), definition(), 1)
      assert cost.hp == 200
      assert cost.sp == 37
    end

    test "cast refused when current HP is not strictly above the cost" do
      cost = Cost.from_definition(game_state(200, 1000), definition(), 1)
      assert {:error, :insufficient_hp} = Cost.validate(game_state(200, 1000), cost)
    end

    test "cast allowed one HP above the cost" do
      cost = Cost.from_definition(game_state(201, 1000), definition(), 1)
      assert :ok = Cost.validate(game_state(201, 1000), cost)
    end
  end

  describe "on_place" do
    test "places the 9-cell cross centered on the caster and roots a player caster" do
      expect(StatusInterpreter, :apply_status, fn :player,
                                                  @caster_id,
                                                  :sc_grandcross_root,
                                                  params ->
        assert params[:duration] == 950
        :ok
      end)

      {:ok, placement} = CrGrandcross.on_place(group([]))

      assert length(placement.cells) == 9
      assert MapSet.new(placement.cells) == MapSet.new(translated_cross())
      assert placement.state == %{hits_caster: true}
      assert placement.interval == 300
      assert placement.duration == 900
      assert placement.lifecycle_policy.max_instances_per_caster == 1
    end

    test "a mob caster is not rooted" do
      reject(&StatusInterpreter.apply_status/4)

      {:ok, placement} = CrGrandcross.on_place(group(caster_type: :mob, caster_id: @mob_id))

      assert length(placement.cells) == 9
    end
  end

  describe "on_interval" do
    test "halves the caster's own self-damage, blinds an undead mob, full damage otherwise" do
      caster = %{unit_type: :player, unit_id: @caster_id}

      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, caster} end)
      stub(Combat, :resolve_combatant, fn :mob, @mob_id -> {:ok, undead_mob()} end)

      expect(Combat, :splash_targets, fn @map, @center, 2, ^caster, true ->
        [{:player, @caster_id}, {:mob, @mob_id}]
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, @caster_id -> {:ok, {100, 100, @map}}
        :mob, @mob_id -> {:ok, {101, 100, @map}}
      end)

      expect(Combat, :apply_skill_unit_damage, 2, fn _caster,
                                                     unit_type,
                                                     _target_id,
                                                     @skill_id,
                                                     3,
                                                     :holy,
                                                     ratio,
                                                     opts ->
        assert ratio == 220

        case unit_type do
          :player -> assert opts[:damage_scale] == 0.5
          :mob -> assert opts[:damage_scale] == 1
        end

        :ok
      end)

      expect(StatusInterpreter, :apply_status, fn :mob, @mob_id, :sc_blind, params ->
        assert params[:duration] == 18_000
        :ok
      end)

      assert {:ok, _group} = CrGrandcross.on_interval(group(level: 3), 0)
    end

    test "does not target the caster when a mob casts the field" do
      caster = %{unit_type: :mob, unit_id: @mob_id}

      stub(Combat, :resolve_combatant, fn @mob_id -> {:ok, caster} end)

      expect(Combat, :splash_targets, fn @map, @center, 2, ^caster, false -> [] end)

      reject(&Combat.apply_skill_unit_damage/8)

      assert {:ok, _group} =
               CrGrandcross.on_interval(group(caster_type: :mob, caster_id: @mob_id), 0)
    end

    test "does not blind a non-undead, non-demon mob" do
      caster = %{unit_type: :player, unit_id: @caster_id}

      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, caster} end)
      stub(Combat, :resolve_combatant, fn :mob, @mob_id -> {:ok, plant_mob()} end)

      expect(Combat, :splash_targets, fn @map, @center, 2, ^caster, true ->
        [{:mob, @mob_id}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id -> {:ok, {101, 100, @map}} end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _t, _i, _s, _l, _e, _r, _o -> :ok end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, _group} = CrGrandcross.on_interval(group([]), 0)
    end

    test "excludes targets standing off the cross footprint (square corners)" do
      caster = %{unit_type: :player, unit_id: @caster_id}

      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, caster} end)

      expect(Combat, :splash_targets, fn @map, @center, 2, ^caster, true ->
        [{:mob, @mob_id}]
      end)

      # {102, 102} sits inside the 5x5 splash square but not on a cross cell.
      stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id -> {:ok, {102, 102, @map}} end)

      reject(&Combat.apply_skill_unit_damage/8)

      assert {:ok, _group} = CrGrandcross.on_interval(group([]), 0)
    end
  end

  describe "MagicDamageCalculator grand cross formula" do
    test "hybrid base, ratio, mdef subtraction, double holy attribute fix" do
      attacker = %{
        unit_type: :player,
        unit_id: 1,
        combat_stats: %{atk: 200, matk_min: 100, matk_max: 100, matk: 100}
      }

      defender = %{
        unit_type: :mob,
        unit_id: 2,
        combat_stats: %{mdef: 10, soft_mdef: 5},
        element: {:undead, 1}
      }

      # hybrid base = (200 + 100) / 2 = 150; ratio 140 -> 210; minus (10 + 5) = 195.
      mod = ElementModifiers.get_modifier(:holy, :undead, 1, 0)
      assert mod == 1.25
      expected = trunc(195 * mod * mod)

      {:ok, %{damage: damage, is_critical: false}} =
        MagicDamageCalculator.calculate_magic_damage(attacker, defender,
          skill_id: @skill_id,
          skill_ratio: 140,
          element: :holy
        )

      assert damage == expected
    end

    test "the holy fix is applied twice, not once" do
      attacker = %{
        unit_type: :player,
        unit_id: 1,
        combat_stats: %{atk: 200, matk_min: 100, matk_max: 100, matk: 100}
      }

      defender = %{
        unit_type: :mob,
        unit_id: 2,
        combat_stats: %{mdef: 0, soft_mdef: 0},
        element: {:undead, 1}
      }

      {:ok, %{damage: damage}} =
        MagicDamageCalculator.calculate_magic_damage(attacker, defender,
          skill_id: @skill_id,
          skill_ratio: 100,
          element: :holy
        )

      single = trunc(150 * 1.25)
      double = trunc(150 * 1.25 * 1.25)
      assert damage == double
      refute damage == single
    end
  end

  defp undead_mob, do: %{unit_type: :mob, unit_id: @mob_id, race: :undead, element: {:undead, 1}}
  defp plant_mob, do: %{unit_type: :mob, unit_id: @mob_id, race: :plant, element: {:earth, 1}}
end

defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcrossTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CombatStats

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

    stub(Combat, :prepare_skill_unit_hit, fn _caster, {type, id}, 254 ->
      {:ok, %{target: combatant(type, id)}}
    end)

    stub(Combat, :deliver_skill_unit_hit, fn _prepared, _damage, _opts -> :ok end)
    :ok
  end

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
    test "places the 9-cell cross centered on the caster without rooting (root is applied in cast)" do
      reject(&StatusInterpreter.apply_status/4)

      {:ok, placement} = CrGrandcross.on_place(group([]))

      assert length(placement.cells) == 9
      assert MapSet.new(placement.cells) == MapSet.new(translated_cross())
      assert placement.state == %{hits_caster: true}
      assert placement.interval == 300
      assert placement.duration == 900
      assert placement.lifecycle_policy.max_instances_per_caster == 1
    end

    test "a mob caster placement is not rooted" do
      reject(&StatusInterpreter.apply_status/4)

      {:ok, placement} = CrGrandcross.on_place(group(caster_type: :mob, caster_id: @mob_id))

      assert length(placement.cells) == 9
    end
  end

  describe "cast rooting and shield suppression" do
    setup do
      Mimic.copy(Stats)
      :ok
    end

    test "a player cast roots the caster and suppresses their shield DEF/MDEF for the window" do
      caster = %PlayerState{character_id: @caster_id, x: 100, y: 100}

      stub(Unit, :place, fn ^caster, :cr_grandcross, 1, {100, 100} -> {:ok, :group} end)
      stub(Stats, :shield_defense_contribution, fn _stats -> %{def: 7, mdef: 3} end)

      expect(StatusInterpreter, :apply_status, fn :player,
                                                  @caster_id,
                                                  :sc_grandcross_root,
                                                  params ->
        assert params[:duration] == 950
        assert params[:val1] == 7
        assert params[:val2] == 3
        :ok
      end)

      assert {:ok, ^caster} = CrGrandcross.cast(caster, :self, 1, definition())
    end

    test "a non-player (mob) self-cast is not rooted" do
      caster = %{x: 5, y: 5}

      stub(Unit, :place, fn ^caster, :cr_grandcross, 1, {5, 5} -> {:ok, :group} end)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = CrGrandcross.cast(caster, :self, 1, definition())
    end
  end

  describe "on_interval" do
    test "self damage has one half-rate, blinds an undead mob, full damage otherwise" do
      caster = combatant(:player, @caster_id)

      stub(Combat, :resolve_combatant, fn
        :player, @caster_id -> {:ok, caster}
        :mob, @mob_id -> {:ok, undead_mob()}
      end)

      expect(Combat, :splash_targets, fn @map, @center, 2, ^caster, true ->
        [{:player, @caster_id}, {:mob, @mob_id}]
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, @caster_id -> {:ok, {100, 100, @map}}
        :mob, @mob_id -> {:ok, {101, 100, @map}}
      end)

      expect(Combat, :deliver_skill_unit_hit, 2, fn %{target: target}, damage, opts ->
        assert opts == [skill_level: 3, element: :holy]

        case target.unit_type do
          :player -> assert damage == mode_value(178, 255)
          :mob -> assert damage == mode_value(445, 766)
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

      stub(Combat, :resolve_combatant, fn :mob, @mob_id -> {:ok, caster} end)

      expect(Combat, :splash_targets, fn @map, @center, 2, ^caster, false -> [] end)

      reject(&Combat.deliver_skill_unit_hit/3)

      assert {:ok, _group} =
               CrGrandcross.on_interval(group(caster_type: :mob, caster_id: @mob_id), 0)
    end

    test "does not blind a non-undead, non-demon mob" do
      caster = combatant(:player, @caster_id)

      stub(Combat, :resolve_combatant, fn
        :player, @caster_id -> {:ok, caster}
        :mob, @mob_id -> {:ok, plant_mob()}
      end)

      expect(Combat, :splash_targets, fn @map, @center, 2, ^caster, true ->
        [{:mob, @mob_id}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id -> {:ok, {101, 100, @map}} end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, _group} = CrGrandcross.on_interval(group([]), 0)
    end

    test "excludes targets standing off the cross footprint (square corners)" do
      caster = combatant(:player, @caster_id)

      stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:ok, caster} end)

      expect(Combat, :splash_targets, fn @map, @center, 2, ^caster, true ->
        [{:mob, @mob_id}]
      end)

      # {102, 102} sits inside the 5x5 splash square but not on a cross cell.
      stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id -> {:ok, {102, 102, @map}} end)

      reject(&Combat.deliver_skill_unit_hit/3)

      assert {:ok, _group} = CrGrandcross.on_interval(group([]), 0)
    end
  end

  describe "skill-owned formula through the field callback" do
    test "hybrid defense and enemy holy stages never use ordinary calculators or display ATK" do
      caster = combatant(:player, @caster_id)
      reject(&DamageCalculator.calculate_damage/3)
      reject(&MagicDamageCalculator.calculate_magic_damage/3)

      for display <- [200, 9_999] do
        caster = %{caster | combat_stats: Map.put(caster.combat_stats, :atk, display)}
        assert delivered_damage(caster) == mode_value(257, 487)
      end
    end

    test "physical percentage-ignore is captured without turning it into magic ignore" do
      caster = combatant(:player, @caster_id)
      caster = %{caster | equip_modifiers: %{{:ignore_def_race, :brute} => 50}}
      assert delivered_damage(caster) == mode_value(281, 535)
    end

    test "selected weapon snapshots supply refine, primary stat and left-only magnitude" do
      caster = combatant(:player, @caster_id)

      caster = %{
        caster
        | combat_stats:
            Map.merge(caster.combat_stats, %{
              max_weapon_damage: true,
              physical_attack: %{caster.combat_stats.physical_attack | str: 30, dex: 60}
            })
      }

      right = %WeaponHand{
        item_id: 1,
        subtype: :dagger,
        element: :fire,
        base_atk: 100,
        weapon_level: 3,
        refine_atk: 10,
        overrefine_band: 0,
        slot: :right_hand
      }

      # The dagger's 75% medium-size penalty applies before the holy weapon stage.
      assert delivered_damage(%{caster | right_hand: right}) == mode_value(400, 708)

      assert delivered_damage(%{caster | left_hand: %{right | slot: :left_hand}}) ==
               mode_value(290, 708)

      assert delivered_damage(%{caster | right_hand: %{right | subtype: :bow}}) ==
               mode_value(466, 771)
    end
  end

  test "one weapon, overrefine and MATK draw per field target" do
    caster = combatant(:player, @caster_id)

    hand = %WeaponHand{
      item_id: 1,
      subtype: :dagger,
      element: :neutral,
      base_atk: 100,
      weapon_level: 3,
      refine_atk: 10,
      overrefine_band: 3,
      slot: :right_hand
    }

    caster = %{
      caster
      | right_hand: hand,
        combat_stats:
          Map.merge(caster.combat_stats, %{
            matk_min: 100,
            matk_max: 111,
            physical_attack: %{caster.combat_stats.physical_attack | str: 30, dex: 60}
          })
    }

    :rand.seed(:exsss, {11, 22, 33})
    :rand.uniform(mode_value(31, 16))
    :rand.uniform(3)
    :rand.uniform(11)
    expected_state = :rand.export_seed()

    :rand.seed(:exsss, {11, 22, 33})
    assert delivered_damage(caster) > 0
    assert :rand.export_seed() == expected_state
  end

  test "real PlayerState snapshots reach shared preparation and exact self/enemy delivery" do
    states =
      Map.new([@caster_id, @mob_id], fn id ->
        stats =
          struct!(
            CombatStats,
            Map.merge(combatant(:player, id).combat_stats, %{matk_min: 100, matk_max: 100})
          )

        state =
          PlayerStateFixture.build(%{
            character_id: id,
            account_id: id,
            map_name: @map,
            x: 100,
            y: 100,
            stats: %{
              combat_stats: stats,
              current_state: %{hp: 1000, sp: 100},
              derived_stats: %{max_hp: 1000, max_sp: 100}
            }
          })

        {id, state}
      end)

    caster = PlayerState.to_combatant(states[@caster_id])
    stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:ok, caster} end)

    stub(Combat, :splash_targets, fn @map, @center, 2, ^caster, true ->
      [{:player, @caster_id}, {:player, @mob_id}]
    end)

    stub(TargetResolver, :resolve, fn :player, id ->
      {:ok, self(), Map.fetch!(states, id), :player}
    end)

    stub(SpatialIndex, :get_unit_position, fn :player, _id -> {:ok, {100, 100, @map}} end)

    stub(Combat, :prepare_skill_unit_hit, fn a, ref, id ->
      Mimic.call_original(Combat, :prepare_skill_unit_hit, [a, ref, id])
    end)

    stub(Combat, :deliver_skill_unit_hit, fn prepared, damage, opts ->
      Mimic.call_original(Combat, :deliver_skill_unit_hit, [prepared, damage, opts])
    end)

    stub(Broadcast, :to_in_range, fn _, _, _, _, packet ->
      send(self(), {:packet, packet.target_id, packet.damage})
      :ok
    end)

    stub(PlayerSession, :apply_damage, fn _, damage, {:player, @caster_id} ->
      send(self(), {:hp_damage, damage})
      :ok
    end)

    assert {:ok, _} = CrGrandcross.on_interval(group([]), 0)
    self_damage = mode_value(82, 108)
    enemy_damage = mode_value(165, 217)
    assert_received {:packet, @caster_id, ^self_damage}
    assert_received {:packet, @mob_id, ^enemy_damage}
    assert_received {:hp_damage, ^self_damage}
    assert_received {:hp_damage, ^enemy_damage}
  end

  defp delivered_damage(caster) do
    stub(Combat, :resolve_combatant, fn
      :player, @caster_id -> {:ok, caster}
      :mob, @mob_id -> {:ok, undead_mob()}
    end)

    stub(Combat, :splash_targets, fn @map, @center, 2, ^caster, true -> [{:mob, @mob_id}] end)
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id -> {:ok, {101, 100, @map}} end)
    stub(StatusInterpreter, :apply_status, fn :mob, @mob_id, :sc_blind, _ -> :ok end)

    stub(Combat, :deliver_skill_unit_hit, fn _prepared,
                                             damage,
                                             [skill_level: 1, element: :holy] ->
      send(self(), {:skill_damage, damage})
      :ok
    end)

    assert {:ok, _} = CrGrandcross.on_interval(group([]), 0)
    assert_received {:skill_damage, damage}
    damage
  end

  defp combatant(type, id) do
    base =
      case type do
        :player -> CombatTestHelper.create_player_combatant(unit_id: id)
        :mob -> CombatTestHelper.create_mob_combatant(unit_id: id)
      end

    stats =
      Map.merge(base.combat_stats, %{matk: 100, def: 20, soft_def: 10, mdef: 10, soft_mdef: 5})

    stats =
      if type == :player,
        do: %{stats | physical_attack: %{stats.physical_attack | status_atk: 100}},
        else: stats

    %{base | combat_stats: stats, element: {:undead, 1}, position: @center, map_name: @map}
  end

  defp mode_value(renewal, pre_renewal),
    do: if(GameMode.mode() == :renewal, do: renewal, else: pre_renewal)

  defp undead_mob, do: %{unit_type: :mob, unit_id: @mob_id, race: :undead, element: {:undead, 1}}
  defp plant_mob, do: %{unit_type: :mob, unit_id: @mob_id, race: :plant, element: {:earth, 1}}
end

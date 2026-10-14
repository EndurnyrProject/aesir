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
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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
        cells: Layout.grand_cross(@center),
        state: %{hits_caster: true, cell_charges: Map.new(Layout.grand_cross(@center), &{&1, 3})}
      },
      overrides
    )
  end

  defp strike(group, target), do: CrGrandcross.on_unit_hit(group, @center, target, 0)

  describe "definition" do
    test "renewal adds a fixed cast, a short delay, and a cooldown; classic a long cast and delay" do
      renewal = CrGrandcross.definition(:renewal)
      classic = CrGrandcross.definition(:pre_renewal)

      assert renewal.cast_time == List.duplicate(1_000, 10)
      assert renewal.fixed_cast_time == List.duplicate(500, 10)
      assert renewal.after_cast_delay == List.duplicate(500, 10)
      assert renewal.cooldown == List.duplicate(1_000, 10)
      assert renewal.duration == List.duplicate(18_000, 10)

      assert classic.cast_time == List.duplicate(3_000, 10)
      assert classic.fixed_cast_time == []
      assert classic.after_cast_delay == List.duplicate(1_500, 10)
      assert classic.cooldown == []
      assert classic.duration == List.duplicate(30_000, 10)
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

    test "costs exactly 20% of current HP at cast" do
      cost = Cost.from_definition(game_state(1000, 1000), definition(), 1)
      assert cost.hp == 200
      assert cost.sp == 37

      assert Cost.from_definition(game_state(500, 1000), definition(), 1).hp == 100
    end

    test "a share of current HP always leaves HP above the cost" do
      cost = Cost.from_definition(game_state(200, 1000), definition(), 1)
      assert cost.hp == 40
      assert :ok = Cost.validate(game_state(200, 1000), cost)
    end

    test "a cast at 1 HP costs no HP" do
      cost = Cost.from_definition(game_state(1, 1000), definition(), 1)
      assert cost.hp == 0
      assert :ok = Cost.validate(game_state(1, 1000), cost)
    end
  end

  describe "on_place" do
    test "places the 29-cell diamond centered on the caster with three charges a cell, without rooting (root is applied in cast)" do
      reject(&StatusInterpreter.apply_status/4)

      {:ok, placement} = CrGrandcross.on_place(group([]))

      assert length(placement.cells) == 29
      assert placement.cells == Layout.grand_cross(@center)
      assert placement.state.cell_charges == Map.new(placement.cells, &{&1, 3})
      assert placement.state.hits_caster == (GameMode.mode() == :pre_renewal)
      assert placement.interval == 300
      assert placement.duration == 950
      assert placement.unit_range == 0
      assert placement.path_check
      assert placement.lifecycle_policy.max_instances_per_caster == 1
    end

    test "a mob caster placement is not rooted" do
      reject(&StatusInterpreter.apply_status/4)

      {:ok, placement} = CrGrandcross.on_place(group(caster_type: :mob, caster_id: @mob_id))

      assert length(placement.cells) == 29
    end
  end

  describe "castend self lock" do
    setup do
      stub(StatusStorage, :get_status, fn :player, @caster_id, :sc_stripshield -> nil end)
      :ok
    end

    test "a player's cast bars shield changes and holds the caster for 950 ms" do
      caster = %PlayerState{character_id: @caster_id, x: 100, y: 100}
      test_pid = self()

      stub(Unit, :place, fn ^caster, :cr_grandcross, 1, {100, 100} -> {:ok, :group} end)

      stub(StatusInterpreter, :apply_status, fn :player, @caster_id, status, params ->
        send(test_pid, {:started, status, params[:duration]})
        :ok
      end)

      assert {:ok, ^caster} = CrGrandcross.cast(caster, :self, 1, definition())
      assert_received {:started, :sc_stripshield, 950}
      assert_received {:started, :sc_ankle, 950}
    end

    test "a longer held shield strip skips the whole lock, and automatic casts lock nothing" do
      caster = %PlayerState{character_id: @caster_id, x: 100, y: 100}
      later = System.monotonic_time(:millisecond) + 60_000
      stub(Unit, :place, fn ^caster, :cr_grandcross, 1, {100, 100} -> {:ok, :group} end)

      stub(StatusStorage, :get_status, fn :player, @caster_id, :sc_stripshield ->
        %StatusEntry{type: :sc_stripshield, expires_at: later}
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = CrGrandcross.cast(caster, :self, 1, definition())

      stub(StatusStorage, :get_status, fn :player, @caster_id, :sc_stripshield -> nil end)

      assert {:ok, ^caster} =
               CrGrandcross.cast_with_origin(caster, :self, 1, definition(), :auto)
    end

    test "a non-player (mob) self-cast is not locked" do
      caster = %{x: 5, y: 5}

      stub(Unit, :place, fn ^caster, :cr_grandcross, 1, {5, 5} -> {:ok, :group} end)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = CrGrandcross.cast(caster, :self, 1, definition())
    end
  end

  describe "unit_targets/3" do
    @tag game_mode: :renewal
    test "renewal never offers the caster to its own field" do
      caster = CombatTestHelper.create_mob_combatant(unit_id: @mob_id)
      stub(Combat, :resolve_combatant, fn :mob, @mob_id -> {:ok, caster} end)
      group = group(caster_type: :mob, caster_id: @mob_id, state: %{hits_caster: false})

      assert CrGrandcross.unit_targets(group, @center, [{:mob, @mob_id}]) == []
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal offers the caster to its own field, a monster included" do
      caster = CombatTestHelper.create_mob_combatant(unit_id: @mob_id)
      stub(Combat, :resolve_combatant, fn :mob, @mob_id -> {:ok, caster} end)
      group = group(caster_type: :mob, caster_id: @mob_id)

      assert CrGrandcross.unit_targets(group, @center, [{:mob, @mob_id}]) == [{:mob, @mob_id}]
    end

    test "offers nobody while the caster is gone" do
      stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:error, :not_found} end)

      assert CrGrandcross.unit_targets(group([]), @center, [{:mob, @mob_id}]) == []
    end
  end

  describe "on_unit_hit" do
    @tag game_mode: :pre_renewal
    test "self damage has one half-rate, blinds an undead mob, full damage otherwise" do
      caster = combatant(:player, @caster_id)

      stub(Combat, :resolve_combatant, fn
        :player, @caster_id -> {:ok, caster}
        :mob, @mob_id -> {:ok, undead_mob()}
      end)

      expect(Combat, :deliver_skill_unit_hit, 2, fn %{target: target}, damage, opts ->
        assert opts[:skill_level] == 3
        assert opts[:element] == :holy

        case target.unit_type do
          :player -> assert damage == 255
          :mob -> assert damage == 766
        end

        opts[:additional_effect].(caster, {target.unit_type, target.unit_id})
        :ok
      end)

      expect(StatusInterpreter, :apply_status, fn :mob, @mob_id, :sc_blind, params ->
        assert params[:duration] == 30_000
        assert params[:val1] == 3
        :ok
      end)

      assert {:ok, group} = strike(group(level: 3), {:player, @caster_id})
      assert {:ok, _group} = strike(group, {:mob, @mob_id})
    end

    @tag game_mode: :pre_renewal
    test "a monster's own field hits it for nothing, a miss that never blinds it" do
      # The fixture monster is undead-element.
      caster = combatant(:mob, @mob_id)
      stub(Combat, :resolve_combatant, fn :mob, @mob_id -> {:ok, caster} end)

      expect(Combat, :deliver_skill_unit_hit, fn _prepared, 0, _opts -> :ok end)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{state: %{cell_charges: %{@center => 2}}}} =
               strike(group(caster_type: :mob, caster_id: @mob_id), {:mob, @mob_id})
    end

    test "does not blind a non-undead, non-demon mob" do
      caster = combatant(:player, @caster_id)

      stub(Combat, :resolve_combatant, fn
        :player, @caster_id -> {:ok, caster}
        :mob, @mob_id -> {:ok, plant_mob()}
      end)

      stub(Combat, :deliver_skill_unit_hit, fn _prepared, _damage, opts ->
        opts[:additional_effect].(caster, {:mob, @mob_id})
        :ok
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, _group} = strike(group([]), {:mob, @mob_id})
    end

    test "spends a charge per hit and removes a cell out of charges after its pass" do
      caster = combatant(:player, @caster_id)

      stub(Combat, :resolve_combatant, fn
        :player, @caster_id -> {:ok, caster}
        :mob, @mob_id -> {:ok, plant_mob()}
      end)

      assert {:ok, %Group{state: %{cell_charges: %{@center => 2}}} = group} =
               strike(group([]), {:mob, @mob_id})

      assert {:ok, group} = strike(group, {:mob, @mob_id})

      assert {:ok, %Group{state: %{cell_charges: %{@center => 0}}},
              [{:after_cell, {:remove_cells, 1, [@center]}}]} = strike(group, {:mob, @mob_id})
    end

    test "hits nothing while the caster is gone" do
      stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:error, :not_found} end)
      reject(&Combat.deliver_skill_unit_hit/3)

      assert {:ok, %Group{state: %{cell_charges: %{@center => 3}}}} =
               strike(group([]), {:mob, @mob_id})
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

  test "real PlayerState snapshots reach shared preparation and exact enemy delivery, and classic self delivery" do
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

    stub(PlayerSession, :apply_damage, fn _, damage, {:player, @caster_id}, _metadata ->
      send(self(), {:hp_damage, damage})
      :ok
    end)

    assert {:ok, _} = strike(group([]), {:player, @mob_id})
    enemy_damage = mode_value(165, 217)
    assert_received {:packet, @mob_id, ^enemy_damage}
    assert_received {:hp_damage, ^enemy_damage}

    if GameMode.mode() == :pre_renewal do
      assert {:ok, _} = strike(group([]), {:player, @caster_id})
      assert_received {:packet, @caster_id, 108}
      assert_received {:hp_damage, 108}
    end
  end

  defp delivered_damage(caster) do
    stub(Combat, :resolve_combatant, fn
      :player, @caster_id -> {:ok, caster}
      :mob, @mob_id -> {:ok, undead_mob()}
    end)

    stub(StatusInterpreter, :apply_status, fn :mob, @mob_id, :sc_blind, _ -> :ok end)

    stub(Combat, :deliver_skill_unit_hit, fn _prepared, damage, opts ->
      assert opts[:skill_level] == 1
      assert opts[:element] == :holy
      send(self(), {:skill_damage, damage})
      :ok
    end)

    assert {:ok, _} = strike(group([]), {:mob, @mob_id})
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

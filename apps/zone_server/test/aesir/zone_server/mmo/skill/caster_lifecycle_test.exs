defmodule Aesir.ZoneServer.Mmo.Skill.CasterLifecycleTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  setup :setup_ets_tables

  defmodule DynamicCost do
    alias Aesir.ZoneServer.Mmo.Skill.Cost

    def dynamic_cost(_caster, _target, _level, _definition), do: %Cost{sp: 7}
  end

  describe "player lifecycle" do
    test "mirrors learned and quest-lineage checks for success and failure" do
      definition = definition()
      caster = player(learned_skills: %{definition.id => 2})

      assert Caster.Player.knows?(caster, definition, 2, :begin) == :ok

      assert Caster.Player.knows?(caster, definition, 3, :begin) ==
               {:error, :skill_not_learned}

      assert Caster.Player.knows?(player(learned_skills: %{}), definition, 3, :completion) == :ok
    end

    test "has no interpreter-level caster state or status gate" do
      for phase <- [:begin, :completion], action_state <- [:idle, :casting, :dead] do
        assert Caster.Player.castable_state(
                 player(action_state: action_state),
                 29,
                 phase
               ) ==
                 :ok
      end
    end

    test "uses the ordinary cast origin and validates before preparing cost" do
      assert Caster.Player.cast_origin(player()) == :normal
      refute Caster.Player.cost_before_validation?()
    end

    test "mirrors full cost preparation and resource failures" do
      definition = definition(zeny_cost: [3])

      assert {:ok, prepared} =
               Caster.Player.cost(player(sp: 10, zeny: 3), DynamicCost, :self, definition, 1)

      assert prepared.cost.sp == 7
      assert prepared.commitment.sp == 7
      assert prepared.zeny == 3

      assert Caster.Player.cost(player(sp: 6), DynamicCost, :self, definition, 1) ==
               {:error, :insufficient_sp}
    end

    test "mirrors commitment and every player-owned resource debit" do
      caster =
        player(
          sp: 10,
          zeny: 5,
          inventory: %{
            0 => %InventoryItem{nameid: 717, amount: 1, equip: 0},
            1 => %InventoryItem{nameid: 1_750, amount: 2, equip: 0x008000}
          }
        )

      definition =
        definition(
          zeny_cost: [3],
          item_cost: [%{id: 717, amount: 1}],
          requires_ammo: true
        )

      {:ok, prepared} = Caster.Player.cost(caster, DynamicCost, :self, definition, 1)

      committed = Caster.Player.commit(caster, prepared)
      assert committed.stats.current_state.sp == 3
      assert committed.zeny == 2
      refute Map.has_key?(committed.inventory, 0)
      assert committed.inventory[1].amount == 1
      assert length(committed.pending_inventory_persist) == 2

      unchanged =
        Caster.Player.commit(caster, %{
          prepared
          | commitment: %Cost.Commitment{
              hp: 0,
              sp: 0,
              spheres: SpiritSpheres.new(),
              write_spheres?: false
            },
            zeny: 0,
            consume_catalysts?: false
        })

      assert unchanged.stats.current_state.sp == 10
      assert unchanged.zeny == 5
      assert unchanged.inventory[0].amount == 1
      assert unchanged.inventory[1].amount == 1
    end

    test "mirrors cooldown readiness and storage" do
      now = System.monotonic_time(:millisecond)

      assert Caster.Player.cooldown_ready?(
               player(skill_cooldowns: %{1 => now - 1}),
               1,
               now,
               :begin
             )

      refute Caster.Player.cooldown_ready?(
               player(skill_cooldowns: %{1 => now + 10_000}),
               1,
               now,
               :begin
             )

      assert Caster.Player.cooldown_ready?(
               player(skill_cooldowns: %{1 => now + 10_000}),
               1,
               now,
               :completion
             )

      assert Caster.Player.put_cooldown(player(), 1, 0).skill_cooldowns == %{}

      assert Caster.Player.put_cooldown(player(), 1, now + 10_000).skill_cooldowns[1] ==
               now + 10_000
    end

    test "mirrors act-delay readiness" do
      now = System.monotonic_time(:millisecond)
      assert Caster.Player.act_ready?(player(act_delay_until: now - 1), now)
      refute Caster.Player.act_ready?(player(act_delay_until: now + 10_000), now)
    end

    test "cast stats match the player interpreter inputs without modifiers" do
      caster = player(base_stats: %{dex: 0, int: 0})

      assert Caster.Player.cast_stats(caster, 29) == expected_player_cast_stats(caster, 29)
    end

    test "cast stats match the player interpreter inputs with a per-skill equip modifier" do
      caster =
        player(
          equipment_modifiers: %{
            {:skill_varcast_rate, 29} => -30,
            varcast_rate: -10,
            fixed_cast: 25
          }
        )

      assert Caster.Player.cast_stats(caster, 29) == expected_player_cast_stats(caster, 29)
      refute Caster.Player.cast_stats(caster, 29) == Caster.Player.cast_stats(caster, 30)
    end
  end

  describe "homunculus lifecycle" do
    test "mirrors species-tree knowledge for success and failure" do
      caster = homunculus(learned_skills: %{8_001 => 2})

      assert Caster.Homunculus.knows?(caster, definition(id: 8_001), 2, :begin) == :ok

      assert Caster.Homunculus.knows?(caster, definition(id: 8_001), 3, :completion) ==
               {:error, :skill_not_learned}
    end

    test "separates phase-aware caster state from skill-specific status gates" do
      caster = homunculus()

      assert Caster.Homunculus.castable_state(caster, 8_001, :begin) == :ok

      assert Caster.Homunculus.castable_state(
               homunculus(action_state: :casting),
               8_001,
               :begin
             ) == {:error, :busy}

      assert Caster.Homunculus.castable_state(
               homunculus(action_state: :casting),
               8_001,
               :completion
             ) == :ok

      assert Caster.Homunculus.castable_state(caster, 8_001, :completion) ==
               {:error, :busy}

      :ok = StatusStorage.apply_status(:homunculus, caster.world_gid, :sc_stun)

      assert Caster.Homunculus.castable_state(caster, 8_001, :begin) == :ok
      assert Caster.Homunculus.castable_status(caster, 8_001) == {:error, :status_blocked}
      assert Caster.Homunculus.completion_revalidates_definition?()
      assert Caster.Homunculus.valid_caster_result?(caster)
      refute Caster.Homunculus.valid_caster_result?(:malformed)
    end

    test "uses the Homunculus cast origin and prepares cost before validation" do
      assert Caster.Homunculus.cast_origin(homunculus()) == :homunculus
      assert Caster.Homunculus.cost_before_validation?()
    end

    test "mirrors SP cost preparation and failures" do
      assert {:ok, %{sp_cost: 5}} =
               Caster.Homunculus.cost(
                 homunculus(sp: 10),
                 DynamicCost,
                 :self,
                 definition(sp_cost: [5]),
                 1
               )

      assert Caster.Homunculus.cost(
               homunculus(sp: 4),
               DynamicCost,
               :self,
               definition(sp_cost: [5]),
               1
             ) ==
               {:error, :insufficient_sp}
    end

    test "mirrors SP commitment" do
      prepared = %{sp_cost: 5}
      assert Caster.Homunculus.commit(homunculus(sp: 10), prepared).sp == 5
      assert Caster.Homunculus.commit(homunculus(sp: 10), %{sp_cost: 0}).sp == 10
    end

    test "mirrors cooldown readiness and storage" do
      now = System.monotonic_time(:millisecond)

      assert Caster.Homunculus.cooldown_ready?(
               homunculus(cooldowns: %{1 => now - 1}),
               1,
               now,
               :begin
             )

      refute Caster.Homunculus.cooldown_ready?(
               homunculus(cooldowns: %{1 => now + 10_000}),
               1,
               now,
               :completion
             )

      assert Caster.Homunculus.put_cooldown(homunculus(), 1, 0).cooldowns == %{}

      assert Caster.Homunculus.put_cooldown(homunculus(), 1, now + 10_000).cooldowns[1] ==
               now + 10_000
    end

    test "mirrors action readiness" do
      now = System.monotonic_time(:millisecond)
      assert Caster.Homunculus.act_ready?(homunculus(), now)
      refute Caster.Homunculus.act_ready?(homunculus(action_state: :attacking), now)
    end

    test "cast stats match the homunculus interpreter inputs without modifiers" do
      caster = homunculus(dex: -1, int: -2)

      assert Caster.Homunculus.cast_stats(caster, 8_001) ==
               expected_homunculus_cast_stats(caster)
    end

    test "cast stats match the homunculus interpreter inputs with an active cast modifier" do
      caster = homunculus(dex: 20, int: 30)

      :ok =
        StatusStorage.apply_status(:homunculus, caster.world_gid, :sc_test_cast_stats,
          state: %{cast_time_reduction: 35}
        )

      assert Caster.Homunculus.cast_stats(caster, 8_001) ==
               expected_homunculus_cast_stats(caster)
    end
  end

  test "mob adapter does not implement lifecycle" do
    refute Caster.Mob.module_info(:attributes)[:behaviour]
           |> List.wrap()
           |> List.flatten()
           |> Enum.member?(Aesir.ZoneServer.Mmo.Skill.Caster.Lifecycle)
  end

  defp definition(overrides \\ []) do
    struct!(
      Definition,
      Keyword.merge(
        [
          id: 29,
          name: :test_skill,
          display_name: "Test",
          max_level: 5,
          target_type: :self,
          sp_cost: [0]
        ],
        overrides
      )
    )
  end

  defp player(overrides \\ []) do
    base_stats =
      Keyword.get(overrides, :base_stats, %{str: 1, agi: 1, vit: 1, int: 30, dex: 20, luk: 1})

    equipment_modifiers = Keyword.get(overrides, :equipment_modifiers, %{})

    state = %PlayerState{
      character_id: 101,
      action_state: :idle,
      movement_state: :standing,
      act_delay_until: 0,
      skill_cooldowns: %{},
      zeny: 100,
      inventory: %{},
      pending_inventory_persist: [],
      spirit_spheres: SpiritSpheres.new(),
      stats: %PlayerStats{
        base_stats: base_stats,
        current_state: %{hp: 100, sp: 100},
        progression: %PlayerProgression{job_id: 0, learned_skills: %{29 => 5}},
        equipment: %Equipment{},
        modifiers: %Modifiers{equipment: equipment_modifiers}
      }
    }

    overrides
    |> Keyword.drop([:base_stats, :equipment_modifiers, :sp, :learned_skills])
    |> then(&struct!(state, &1))
    |> put_in(
      [Access.key!(:stats), Access.key!(:current_state), :sp],
      Keyword.get(overrides, :sp, 100)
    )
    |> put_in(
      [Access.key!(:stats), Access.key!(:progression), Access.key!(:learned_skills)],
      Keyword.get(overrides, :learned_skills, %{29 => 5})
    )
  end

  defp expected_player_cast_stats(caster, skill_id) do
    base_stats = caster.stats.base_stats

    %{
      dex: base_stats.dex,
      int: base_stats.int,
      varcast_reductions: status_reductions(:player, caster.character_id),
      varcast_rate:
        merged_modifier(:player, caster.character_id) +
          equip_modifier(caster, :varcast_rate) +
          equip_modifier(caster, {:skill_varcast_rate, skill_id}),
      fixed_cast: equip_modifier(caster, :fixed_cast)
    }
  end

  defp expected_homunculus_cast_stats(caster) do
    %{
      dex: max(caster.dex, 0),
      int: max(caster.int, 0),
      varcast_reductions: status_reductions(:homunculus, caster.world_gid),
      varcast_rate: merged_modifier(:homunculus, caster.world_gid),
      fixed_cast: 0
    }
  end

  defp status_reductions(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.flat_map(fn entry ->
      case Map.get(entry.state || %{}, :cast_time_reduction) do
        nil -> []
        value -> [value]
      end
    end)
  end

  defp merged_modifier(unit_type, unit_id) do
    unit_type
    |> ModifierCalculator.get_all_modifiers(unit_id)
    |> Map.get(:varcast_rate, 0)
  end

  defp equip_modifier(caster, key) do
    caster.stats.modifiers.equipment
    |> Map.get(key, 0)
  end

  defp homunculus(overrides \\ []) do
    struct!(
      %HomunculusState{
        id: 201,
        owner_character_id: 101,
        class_id: 6_001,
        name: "Lif",
        world_gid: 301,
        lifecycle: :active,
        hp: 100,
        sp: 100,
        action_state: :idle,
        movement_state: :standing
      },
      overrides
    )
  end
end

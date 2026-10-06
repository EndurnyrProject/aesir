defmodule Aesir.ZoneServer.Mmo.Skill.CasterLifecycleTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoemBragi
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Suffragium
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(UnitRegistry)
    :ok
  end

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

    test "an equipment-granted skill is castable at its granted level, learned or not" do
      definition = definition(id: 28)

      caster =
        [learned_skills: %{}]
        |> player()
        |> put_in([Access.key!(:stats), Access.key!(:granted_skills)], %{28 => 3})

      assert Caster.Player.knows?(caster, definition, 3, :begin) == :ok

      assert Caster.Player.knows?(caster, definition, 4, :begin) ==
               {:error, :skill_not_learned}

      assert Caster.Player.knows?(caster, definition, 3, :completion) == :ok
    end

    test "a temporary equipment grant is eligible for Foresight timing" do
      caster =
        player(learned_skills: %{})
        |> put_in([Access.key!(:stats), Access.key!(:granted_skills)], %{28 => 3})

      assert Caster.Player.cast_stats(caster, 28).effective_skill?
      refute Caster.Player.cast_stats(caster, 29).effective_skill?
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

    test "cast stats use effective player stats and source-named channels" do
      caster = player(base_stats: %{dex: 0, int: 0})

      assert %{
               caster_kind: :player,
               dex: 0,
               int: 0,
               effective_skill?: true,
               item_global_rate: 0,
               statuses: %{}
             } = Caster.Player.cast_stats(caster, 29)
    end

    test "cast stats match the player interpreter inputs with a per-skill equip modifier" do
      caster =
        player(
          equipment_modifiers: %{
            {:skill_varcast_rate, 29} => -30,
            {:skill_fixcast_rate, 29} => -40,
            varcast_rate: -10,
            fixed_cast: 25,
            fixcast_rate: -10
          }
        )

      assert %{
               item_global_rate: 10,
               item_skill_rate: -30,
               item_global_fixed_rate: 10,
               item_skill_fixed_rate: 40,
               item_global_fixed_flat: 25
             } =
               Caster.Player.cast_stats(caster, 29)

      assert Caster.Player.cast_stats(caster, 30).item_skill_rate == 0
    end

    @tag game_mode: :renewal
    test "keeps equipment and Bragi early while Suffragium remains late" do
      caster =
        player(
          equipment_modifiers: %{
            {:skill_varcast_rate, 29} => -5,
            varcast_rate: -10
          }
        )

      stub(UnitRegistry, :get_unit_info, fn :player, 101 -> {:ok, %{stats: %{}}} end)
      apply_classic_cast_statuses(:player, caster.character_id)

      assert %{item_global_rate: 10, item_skill_rate: -5, statuses: %{bragi: 20, suffragium: 20}} =
               Caster.Player.cast_stats(caster, 29)
    end

    @tag game_mode: :pre_renewal
    test "classic Suffragium contributes its 45 percent late reduction" do
      caster =
        player(
          equipment_modifiers: %{
            {:skill_varcast_rate, 29} => -5,
            varcast_rate: -10
          }
        )

      stub(UnitRegistry, :get_unit_info, fn :player, 101 -> {:ok, %{stats: %{}}} end)
      apply_classic_cast_statuses(:player, caster.character_id)

      assert %{item_global_rate: 10, item_skill_rate: -5, statuses: %{bragi: 20, suffragium: 45}} =
               Caster.Player.cast_stats(caster, 29)
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

    test "homunculus cast inputs clamp negative effective stats" do
      caster = homunculus(dex: -1, int: -2)

      assert %{caster_kind: :homunculus, dex: 0, int: 0, statuses: %{}} =
               Caster.Homunculus.cast_stats(caster, 8_001)
    end

    test "homunculus cast inputs identify Bragi by name" do
      caster = homunculus(dex: 20, int: 30)

      :ok =
        StatusStorage.apply_status(:homunculus, caster.world_gid, :sc_poembragi,
          state: %{cast_time_reduction: 35}
        )

      assert %{dex: 20, int: 30, statuses: %{bragi: 35}} =
               Caster.Homunculus.cast_stats(caster, 8_001)
    end

    @tag game_mode: :renewal
    test "keeps Bragi early while Suffragium remains late for homunculi" do
      caster = homunculus(dex: 20, int: 30)

      stub(UnitRegistry, :get_unit_info, fn :homunculus, 301 -> {:ok, %{stats: %{}}} end)
      apply_classic_cast_statuses(:homunculus, caster.world_gid)

      assert %{caster_kind: :homunculus, statuses: %{bragi: 20, suffragium: 20}} =
               Caster.Homunculus.cast_stats(caster, 8_001)
    end

    @tag game_mode: :pre_renewal
    test "classic Suffragium contributes its 45 percent late reduction for homunculi" do
      caster = homunculus(dex: 20, int: 30)

      stub(UnitRegistry, :get_unit_info, fn :homunculus, 301 -> {:ok, %{stats: %{}}} end)
      apply_classic_cast_statuses(:homunculus, caster.world_gid)

      assert %{caster_kind: :homunculus, statuses: %{bragi: 20, suffragium: 45}} =
               Caster.Homunculus.cast_stats(caster, 8_001)
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

  defp apply_classic_cast_statuses(unit_type, unit_id) do
    {:ok, bragi} =
      PoemBragi.on_apply(
        {unit_type, unit_id},
        %StatusEntry{type: :sc_poembragi, val2: 20, val3: 0, state: %{}},
        %{}
      )

    :ok =
      StatusStorage.apply_status(unit_type, unit_id, :sc_poembragi,
        val2: 20,
        state: bragi.state
      )

    {:ok, suffragium} =
      Suffragium.on_apply(
        {unit_type, unit_id},
        %StatusEntry{type: :sc_suffragium, val1: 3, state: %{}},
        %{}
      )

    :ok =
      StatusStorage.apply_status(unit_type, unit_id, :sc_suffragium,
        val1: 3,
        state: suffragium.state
      )
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

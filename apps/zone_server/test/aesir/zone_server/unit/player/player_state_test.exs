defmodule Aesir.ZoneServer.Unit.Player.PlayerStateTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  describe "new/1 char vars and zeny" do
    test "loads vars, an empty temp_vars, and zeny from the character" do
      character = %Character{
        id: 1,
        name: "VarHero",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1,
        zeny: 5_000,
        vars: %{"sphmask_q" => 1}
      }

      assert %PlayerState{vars: %{"sphmask_q" => 1}, temp_vars: %{}, zeny: 5_000} =
               PlayerState.new(character)
    end

    test "defaults vars to an empty map when the character has nil vars" do
      character = %Character{
        id: 2,
        name: "NilVars",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1,
        zeny: 0,
        vars: nil
      }

      assert %PlayerState{vars: %{}, temp_vars: %{}, zeny: 0} = PlayerState.new(character)
    end
  end

  describe "state transitions" do
    setup do
      character = %Character{
        id: 1,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1
      }

      state = PlayerState.new(character)
      {:ok, %{state: state}}
    end

    test "initial state is idle", %{state: state} do
      assert state.action_state == :idle
    end

    test "regen accumulators default to zero", %{state: state} do
      assert state.regen_accumulators == %{hp_acc: 0, sp_acc: 0, skill_hp_acc: 0, skill_sp_acc: 0}
    end

    test "can transition from idle to moving", %{state: state} do
      assert {:ok, new_state} = PlayerState.transition_to(state, :moving)
      assert new_state.action_state == :moving
    end

    test "can transition from idle to combat_moving", %{state: state} do
      assert {:ok, new_state} = PlayerState.transition_to(state, :combat_moving)
      assert new_state.action_state == :combat_moving
    end

    test "can transition from idle to attacking", %{state: state} do
      assert {:ok, new_state} = PlayerState.transition_to(state, :attacking)
      assert new_state.action_state == :attacking
    end

    test "can transition from combat_moving to attacking", %{state: state} do
      {:ok, combat_moving_state} = PlayerState.transition_to(state, :combat_moving)
      assert {:ok, attacking_state} = PlayerState.transition_to(combat_moving_state, :attacking)
      assert attacking_state.action_state == :attacking
    end

    test "cannot transition from dead to attacking", %{state: state} do
      {:ok, dead_state} = PlayerState.transition_to(state, :dead)
      assert {:error, :invalid_transition} = PlayerState.transition_to(dead_state, :attacking)
    end

    test "can always transition to dead", %{state: state} do
      {:ok, moving_state} = PlayerState.transition_to(state, :moving)
      assert {:ok, dead_state} = PlayerState.transition_to(moving_state, :dead)
      assert dead_state.action_state == :dead
    end

    test "can transition from dead to idle (resurrection)", %{state: state} do
      {:ok, dead_state} = PlayerState.transition_to(state, :dead)
      assert {:ok, idle_state} = PlayerState.transition_to(dead_state, :idle)
      assert idle_state.action_state == :idle
    end
  end

  describe "combat intent" do
    setup do
      character = %Character{
        id: 1,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1
      }

      state = PlayerState.new(character)
      {:ok, %{state: state}}
    end

    test "set_combat_intent sets combat fields", %{state: state} do
      updated_state = PlayerState.set_combat_intent(state, 12_345, 0, {150, 150})

      assert updated_state.combat_target_id == 12_345
      assert updated_state.combat_action_type == 0
      assert updated_state.last_target_position == {150, 150}
      assert updated_state.movement_intent == :combat
    end

    test "clear_combat_intent clears combat fields", %{state: state} do
      state = PlayerState.set_combat_intent(state, 12_345, 0, {150, 150})
      cleared_state = PlayerState.clear_combat_intent(state)

      assert cleared_state.combat_target_id == nil
      assert cleared_state.combat_action_type == nil
      assert cleared_state.last_target_position == nil
      assert cleared_state.movement_intent == :none
    end

    test "clear_combat_intent preserves normal movement intent", %{state: state} do
      # Set to moving state
      state = %{state | movement_state: :moving}
      state = PlayerState.set_combat_intent(state, 12_345, 0, {150, 150})

      cleared_state = PlayerState.clear_combat_intent(state)
      assert cleared_state.movement_intent == :normal
    end

    test "combat_moving? returns true for combat_moving state", %{state: state} do
      {:ok, combat_moving_state} = PlayerState.transition_to(state, :combat_moving)
      assert PlayerState.combat_moving?(combat_moving_state) == true
    end

    test "combat_moving? returns false for other states", %{state: state} do
      assert PlayerState.combat_moving?(state) == false

      {:ok, moving_state} = PlayerState.transition_to(state, :moving)
      assert PlayerState.combat_moving?(moving_state) == false
    end
  end

  describe "state transition validation" do
    test "can_transition? validates allowed transitions" do
      # From idle
      assert PlayerState.can_transition?(:idle, :moving) == true
      assert PlayerState.can_transition?(:idle, :combat_moving) == true
      assert PlayerState.can_transition?(:idle, :attacking) == true
      assert PlayerState.can_transition?(:idle, :sitting) == true

      # From moving
      assert PlayerState.can_transition?(:moving, :idle) == true
      assert PlayerState.can_transition?(:moving, :combat_moving) == true
      assert PlayerState.can_transition?(:moving, :attacking) == true

      # From combat_moving
      assert PlayerState.can_transition?(:combat_moving, :idle) == true
      assert PlayerState.can_transition?(:combat_moving, :attacking) == true
      assert PlayerState.can_transition?(:combat_moving, :moving) == true

      # From attacking
      assert PlayerState.can_transition?(:attacking, :idle) == true
      assert PlayerState.can_transition?(:attacking, :combat_moving) == true

      # Invalid transitions
      assert PlayerState.can_transition?(:sitting, :attacking) == false
      assert PlayerState.can_transition?(:dead, :moving) == false
      assert PlayerState.can_transition?(:trading, :attacking) == false

      # Special cases
      # Can always die
      assert PlayerState.can_transition?(:idle, :dead) == true
      # Resurrection
      assert PlayerState.can_transition?(:dead, :idle) == true
      # Same state
      assert PlayerState.can_transition?(:idle, :idle) == true
    end
  end

  describe "casting" do
    setup do
      character = %Character{
        id: 1,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1
      }

      state = PlayerState.new(character)
      {:ok, %{state: state}}
    end

    test "can transition from idle to casting", %{state: state} do
      assert {:ok, casting_state} = PlayerState.transition_to(state, :casting)
      assert casting_state.action_state == :casting
    end

    test "can transition from casting back to idle", %{state: state} do
      {:ok, casting_state} = PlayerState.transition_to(state, :casting)
      assert {:ok, idle_state} = PlayerState.transition_to(casting_state, :idle)
      assert idle_state.action_state == :idle
    end

    test "can transition from casting to dead", %{state: state} do
      {:ok, casting_state} = PlayerState.transition_to(state, :casting)
      assert {:ok, dead_state} = PlayerState.transition_to(casting_state, :dead)
      assert dead_state.action_state == :dead
    end

    test "casting stores the cast state_context", %{state: state} do
      context = %{
        skill_id: 83,
        skill_level: 5,
        target: {:ground, 150, 150},
        element: :water,
        started_at: 0,
        fixed_until: 200,
        total_until: 1_000,
        timer_ref: nil,
        token: 1,
        interruptible: true
      }

      assert {:ok, casting_state} = PlayerState.transition_to(state, :casting, context)
      assert casting_state.state_context == context
    end

    test "cannot transition from sitting to casting", %{state: state} do
      {:ok, sitting_state} = PlayerState.transition_to(state, :sitting)
      assert {:error, :invalid_transition} = PlayerState.transition_to(sitting_state, :casting)
      assert PlayerState.can_transition?(:sitting, :casting) == false
    end

    test "can_transition? permits the casting lifecycle pairs" do
      assert PlayerState.can_transition?(:idle, :casting) == true
      assert PlayerState.can_transition?(:casting, :idle) == true
      assert PlayerState.can_transition?(:casting, :dead) == true
    end
  end

  describe "act_ready?/2" do
    test "a zero act_delay_until is always ready" do
      state = %PlayerState{act_delay_until: 0}
      assert PlayerState.act_ready?(state, 0) == true
      assert PlayerState.act_ready?(state, 1_000_000) == true
    end

    test "a future act_delay_until is not ready" do
      state = %PlayerState{act_delay_until: 5_000}
      assert PlayerState.act_ready?(state, 4_999) == false
    end

    test "a past or reached act_delay_until is ready" do
      state = %PlayerState{act_delay_until: 5_000}
      assert PlayerState.act_ready?(state, 5_000) == true
      assert PlayerState.act_ready?(state, 6_000) == true
    end
  end

  describe "to_combatant/1 weapon type resolution" do
    setup do
      character = %Character{
        id: 1,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1
      }

      {:ok, %{state: PlayerState.new(character)}}
    end

    defp with_weapon(state, nameid, equip) do
      worn = %InventoryItem{nameid: nameid, amount: 1, equip: equip, identify: 1}
      equipment = Stats.equipment_from_inventory([worn])
      put_in(state.stats.equipment, equipment)
    end

    test "resolves a two-handed sword from the equipped weapon", %{state: state} do
      # Balmung (id 1161), subtype two_handed_sword, worn on both hands (bitmask 34).
      combatant = PlayerState.to_combatant(with_weapon(state, 1161, 34))
      assert combatant.weapon.type == :two_handed_sword
    end

    test "resolves a one-handed sword from the equipped weapon", %{state: state} do
      # Sword (id 1101), subtype one_handed_sword, worn on the right hand (bitmask 2).
      combatant = PlayerState.to_combatant(with_weapon(state, 1101, 2))
      assert combatant.weapon.type == :one_handed_sword
    end

    test "an unarmed player resolves to :fist", %{state: state} do
      combatant = PlayerState.to_combatant(state)
      assert combatant.weapon.type == :fist
      assert combatant.attack_range == 1
    end

    test "adds the passive range bonus to the weapon's attack range", %{state: state} do
      state = put_in(state.stats.modifiers.passive, %{range: 2})
      combatant = PlayerState.to_combatant(state)

      # fist range 1 + 2 passive range = 3
      assert combatant.attack_range == 3
    end

    test "carries the player's attack delay as attack_delay_ms", %{state: state} do
      combatant = PlayerState.to_combatant(state)

      assert combatant.attack_delay_ms == AttackSpeed.calculate_delay_from_stats(state.stats)
    end

    test "carries matk, mdef and soft_mdef from the player's combat stats", %{state: state} do
      combatant = PlayerState.to_combatant(state)

      assert combatant.combat_stats.matk == state.stats.combat_stats.matk
      assert combatant.combat_stats.mdef == state.stats.combat_stats.mdef
      assert combatant.combat_stats.soft_mdef == state.stats.combat_stats.soft_mdef
    end

    test "defaults divine_protection_level and demon_bane_level to 0 with no learned skills",
         %{state: state} do
      combatant = PlayerState.to_combatant(state)

      assert combatant.divine_protection_level == 0
      assert combatant.demon_bane_level == 0
    end

    test "carries AL_DP and AL_DEMONBANE levels from learned skills onto the combatant",
         %{state: state} do
      state = put_in(state.stats.progression.learned_skills, %{22 => 5, 23 => 3})
      combatant = PlayerState.to_combatant(state)

      assert combatant.divine_protection_level == 5
      assert combatant.demon_bane_level == 3
    end
  end

  describe "to_combatant/1 weapon element resolution" do
    setup do
      character = %Character{
        id: 1,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1
      }

      {:ok, %{state: PlayerState.new(character)}}
    end

    defp with_ammo(state, nameid) do
      worn = %InventoryItem{nameid: nameid, amount: 1, equip: 0x008000, identify: 1}
      equipment = Stats.equipment_from_inventory([worn])
      put_in(state.stats.equipment, equipment)
    end

    test "weapon.element is :neutral with no arrow equipped", %{state: state} do
      combatant = PlayerState.to_combatant(state)
      assert combatant.weapon.element == :neutral
    end

    test "weapon.element is :fire when Fire Arrow (1752) is in the ammo slot", %{state: state} do
      combatant = PlayerState.to_combatant(with_ammo(state, 1752))
      assert combatant.weapon.element == :fire
    end

    test "weapon.element is :neutral for Arrow (1750) which has no attack_element", %{
      state: state
    } do
      combatant = PlayerState.to_combatant(with_ammo(state, 1750))
      assert combatant.weapon.element == :neutral
    end
  end

  describe "indexed inventory" do
    test "from_list assigns contiguous indices ordered by id" do
      items = [
        %InventoryItem{id: 30, nameid: 501},
        %InventoryItem{id: 10, nameid: 1201},
        %InventoryItem{id: 20, nameid: 2301}
      ]

      inventory = PlayerState.from_list(items)

      assert %{
               0 => %InventoryItem{id: 10},
               1 => %InventoryItem{id: 20},
               2 => %InventoryItem{id: 30}
             } = inventory
    end

    test "to_list returns items ordered by index" do
      inventory = PlayerState.from_list([%InventoryItem{id: 5}, %InventoryItem{id: 3}])

      assert [%InventoryItem{id: 3}, %InventoryItem{id: 5}] = PlayerState.to_list(inventory)
    end

    test "get_by_index returns the item or nil" do
      inventory = PlayerState.from_list([%InventoryItem{id: 7, nameid: 909}])

      assert %InventoryItem{nameid: 909} = PlayerState.get_by_index(inventory, 0)
      assert PlayerState.get_by_index(inventory, 1) == nil
    end

    test "lowest_free_index returns the smallest unused index" do
      inventory = %{0 => %InventoryItem{}, 1 => %InventoryItem{}, 3 => %InventoryItem{}}

      assert PlayerState.lowest_free_index(inventory) == 2
      assert PlayerState.lowest_free_index(%{}) == 0
    end

    test "put_item and delete_index update the map" do
      item = %InventoryItem{id: 1, nameid: 501}
      inventory = PlayerState.put_item(%{}, 0, item)

      assert %{0 => ^item} = inventory
      assert PlayerState.delete_index(inventory, 0) == %{}
    end

    test "client_index and server_index are exact inverses with a +2 offset" do
      assert PlayerState.client_index(0) == 2
      assert PlayerState.server_index(2) == 0
      assert PlayerState.server_index(PlayerState.client_index(7)) == 7
    end
  end

  describe "warp cooldown" do
    setup do
      character = %Character{
        id: 1,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1
      }

      {:ok, %{state: PlayerState.new(character)}}
    end

    test "last_warp_at is nil in a freshly-constructed state", %{state: state} do
      assert state.last_warp_at == nil
    end

    test "within_warp_cooldown? returns false when last_warp_at is nil", %{state: state} do
      assert PlayerState.within_warp_cooldown?(state, 500) == false
    end

    test "mark_warp sets last_warp_at to a monotonic integer and trips the cooldown", %{
      state: state
    } do
      marked = PlayerState.mark_warp(state)

      assert is_integer(marked.last_warp_at)
      assert PlayerState.within_warp_cooldown?(marked, 500) == true
    end

    test "within_warp_cooldown? returns false once the cooldown has elapsed", %{state: state} do
      past = System.monotonic_time(:millisecond) - 1_000
      state = %{state | last_warp_at: past}

      assert PlayerState.within_warp_cooldown?(state, 500) == false
    end
  end

  describe "state entry handlers" do
    setup do
      character = %Character{
        id: 1,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1
      }

      state = PlayerState.new(character)
      {:ok, %{state: state}}
    end

    test "transitioning to idle clears combat intent", %{state: state} do
      # Set combat intent
      state = PlayerState.set_combat_intent(state, 12_345, 0, {150, 150})
      {:ok, combat_state} = PlayerState.transition_to(state, :combat_moving)

      # Transition to idle should clear combat intent
      {:ok, idle_state} = PlayerState.transition_to(combat_state, :idle)

      assert idle_state.combat_target_id == nil
      assert idle_state.combat_action_type == nil
      assert idle_state.last_target_position == nil
    end

    test "transitioning to moving sets normal movement intent", %{state: state} do
      assert state.movement_intent == :none

      {:ok, moving_state} = PlayerState.transition_to(state, :moving)
      assert moving_state.movement_intent == :normal
    end

    test "transitioning to combat_moving sets combat movement intent", %{state: state} do
      {:ok, combat_moving_state} = PlayerState.transition_to(state, :combat_moving)
      assert combat_moving_state.movement_intent == :combat
    end
  end
end

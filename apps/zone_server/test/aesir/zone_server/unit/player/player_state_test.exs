defmodule Aesir.ZoneServer.Unit.Player.PlayerStateTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

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

      assert %PlayerState{
               vars: %{"sphmask_q" => 1},
               temp_vars: %{},
               zeny: 5_000,
               last_song: nil,
               plagiarized: nil
             } = PlayerState.new(character)
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

    test "yields empty cart defaults" do
      character = %Character{
        id: 3,
        name: "Carter",
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

      assert %PlayerState{
               cart: %{},
               cart_type: 0,
               pending_cart_persist: [],
               pending_cart_notify: []
             } = PlayerState.new(character)
    end
  end

  describe "new/1 pvp counters" do
    test "copies explicit counters and defaults unset ones to zero" do
      assert %PlayerState{pvp_point: 0, pvp_won: 0, pvp_lost: 0} = %PlayerState{}

      character = %Character{
        id: 1,
        name: "PvpHero",
        account_id: 1,
        pvp_point: -5,
        pvp_won: 3,
        pvp_lost: 1
      }

      assert %PlayerState{pvp_point: -5, pvp_won: 3, pvp_lost: 1} = PlayerState.new(character)

      defaulted = %Character{id: 2, name: "PvpZero", account_id: 1}

      assert %PlayerState{pvp_point: 0, pvp_won: 0, pvp_lost: 0} = PlayerState.new(defaulted)
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

    test "initial state is idle with a zero deferred epoch", %{state: state} do
      assert state.action_state == :idle
      assert state.deferred_epoch == 0
    end

    test "death advances the deferred epoch once per death transition", %{state: state} do
      assert {:ok, first_death} = PlayerState.transition_to(state, :dead)
      assert first_death.deferred_epoch == 1

      assert {:ok, still_dead} = PlayerState.transition_to(first_death, :dead)
      assert still_dead.deferred_epoch == 1

      assert {:ok, revived} = PlayerState.transition_to(still_dead, :idle)
      assert revived.deferred_epoch == 1

      assert {:ok, second_death} = PlayerState.transition_to(revived, :dead)
      assert second_death.deferred_epoch == 2
    end

    test "relocation advances the deferred epoch but ordinary movement does not", %{state: state} do
      walked = PlayerState.update_position(state, 101, 100)
      assert walked.deferred_epoch == 0

      same_map = PlayerState.relocate(walked, "prontera", 120, 130)
      assert same_map.deferred_epoch == 1

      cross_map = PlayerState.relocate(same_map, "geffen", 50, 60)
      assert cross_map.deferred_epoch == 2
    end

    test "regen accumulators default to zero", %{state: state} do
      assert state.regen_accumulators == %{hp_acc: 0, sp_acc: 0, skill_hp_acc: 0, skill_sp_acc: 0}
    end

    test "walk delays block movement until their monotonic expiry", %{state: state} do
      delayed = PlayerState.apply_walk_delay(state, 1_600, 10_000)
      extended = PlayerState.apply_walk_delay(delayed, 500, 10_500)

      assert extended.walk_delay_until == 11_600
      assert PlayerState.walk_delayed?(extended, 11_599)
      refute PlayerState.walk_delayed?(extended, 11_600)
    end

    test "an unset delay does not block a negative monotonic clock", %{state: state} do
      now = System.monotonic_time(:millisecond)

      refute PlayerState.walk_delayed?(state, now)

      delayed = PlayerState.apply_walk_delay(state, 1_600, now)
      assert delayed.walk_delay_until == now + 1_600
      assert PlayerState.walk_delayed?(delayed, now)
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

    test "set_continuous_timer stores the timer reference", %{state: state} do
      ref = Process.send_after(self(), :never, 60_000)
      updated_state = PlayerState.set_continuous_timer(state, ref)

      assert updated_state.continuous_attack_timer == ref
      Process.cancel_timer(ref)
    end

    test "set_continuous_timer cancels a previously scheduled swing", %{state: state} do
      old_ref = Process.send_after(self(), :never, 60_000)
      state = PlayerState.set_continuous_timer(state, old_ref)

      new_ref = Process.send_after(self(), :never, 60_000)
      updated_state = PlayerState.set_continuous_timer(state, new_ref)

      assert Process.read_timer(old_ref) == false
      assert updated_state.continuous_attack_timer == new_ref
      Process.cancel_timer(new_ref)
    end

    test "clear_combat_intent cancels and nils the auto-attack timer", %{state: state} do
      ref = Process.send_after(self(), :never, 60_000)
      state = PlayerState.set_combat_intent(state, 12_345, 7, {150, 150})
      state = PlayerState.set_continuous_timer(state, ref)

      cleared_state = PlayerState.clear_combat_intent(state)

      assert Process.read_timer(ref) == false
      assert cleared_state.continuous_attack_timer == nil
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
      game_mode = {
        Application.fetch_env(:commons, :game_mode),
        :persistent_term.get(GameMode, nil)
      }

      on_exit(fn -> restore_game_mode(game_mode) end)

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

    test "exports the player's optional weapon hands", %{state: state} do
      worn = %InventoryItem{nameid: 1101, amount: 1, equip: 2, identify: 1}
      state = put_in(state.stats, Stats.apply_equipment_modifiers(state.stats, [worn]))

      combatant = PlayerState.to_combatant(state)

      assert %WeaponHand{item_id: 1101, slot: :right_hand} = combatant.right_hand
      assert combatant.left_hand == nil
    end

    test "an unarmed player's combatant has no weapon hand snapshots", %{state: state} do
      combatant = PlayerState.to_combatant(state)

      assert combatant.right_hand == nil
      assert combatant.left_hand == nil
    end

    test "an unarmed player resolves to :fist", %{state: state} do
      combatant = PlayerState.to_combatant(state)
      assert combatant.weapon.type == :fist
      assert combatant.attack_range == 1
    end

    test "uses the active game mode race and leaves secondary groups empty", %{state: state} do
      set_game_mode(:renewal)
      assert %{race: :player_human, race2: []} = PlayerState.to_combatant(state)

      set_game_mode(:pre_renewal)
      assert %{race: :demi_human, race2: []} = PlayerState.to_combatant(state)
    end

    test "adds the passive range bonus to the weapon's attack range", %{state: state} do
      state = put_in(state.stats.modifiers.passive, %{range: 2})
      combatant = PlayerState.to_combatant(state)

      # fist range 1 + 2 passive range = 3
      assert combatant.attack_range == 3
    end

    test "defaults the defense element to neutral 1", %{state: state} do
      assert PlayerState.to_combatant(state).element == {:neutral, 1}
    end

    test "an element_override status modifier changes the defense element", %{state: state} do
      state =
        put_in(state.stats.modifiers.status_effects, %{element_override: {:holy, 1}})

      assert PlayerState.to_combatant(state).element == {:holy, 1}
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

    test "defaults divine_protection_level, demon_bane_level, beast_bane_level and dragonology_level to 0 with no learned skills",
         %{state: state} do
      combatant = PlayerState.to_combatant(state)

      assert combatant.divine_protection_level == 0
      assert combatant.demon_bane_level == 0
      assert combatant.beast_bane_level == 0
      assert combatant.dragonology_level == 0
      assert combatant.skin_temper_level == 0
    end

    test "carries Skin Temper level from learned skills onto the combatant", %{state: state} do
      state = put_in(state.stats.progression.learned_skills, %{109 => 5})

      assert PlayerState.to_combatant(state).skin_temper_level == 5
    end

    test "carries AL_DP, AL_DEMONBANE and HT_BEASTBANE levels from learned skills onto the combatant",
         %{state: state} do
      state = put_in(state.stats.progression.learned_skills, %{22 => 5, 23 => 3, 126 => 4})
      combatant = PlayerState.to_combatant(state)

      assert combatant.divine_protection_level == 5
      assert combatant.demon_bane_level == 3
      assert combatant.beast_bane_level == 4
    end

    test "carries SA_DRAGONOLOGY level from learned skills onto the combatant",
         %{state: state} do
      state = put_in(state.stats.progression.learned_skills, %{284 => 5})
      combatant = PlayerState.to_combatant(state)

      assert combatant.dragonology_level == 5
    end

    test "player combatant class is always :normal", %{state: state} do
      assert PlayerState.to_combatant(state).class == :normal
    end

    test "carries the live equipment modifier map as equip_modifiers", %{state: state} do
      state = put_in(state.stats.modifiers.equipment, %{atk: 10, addrace_brute: 20})
      combatant = PlayerState.to_combatant(state)

      assert combatant.equip_modifiers == %{atk: 10, addrace_brute: 20}
    end

    test "carries the current equipment autobonus registration map", %{state: state} do
      registrations = %{{11, 0} => %{trigger: :attack, rate: 250}}

      state =
        state
        |> put_in([Access.key(:stats), Access.key(:equip_autobonuses)], registrations)
        |> put_in([Access.key(:stats), Access.key(:active_autobonuses)], %{{11, 0} => 3})

      combatant = PlayerState.to_combatant(state)

      assert combatant.equip_autobonuses == registrations
      assert is_map(combatant.equip_autobonuses)
    end

    test "an on-foot player's combatant is not riding", %{state: state} do
      refute PlayerState.to_combatant(state).riding
    end

    test "the :riding option bit threads onto the combatant's riding flag", %{state: state} do
      riding_bit = Aesir.ZoneServer.Mmo.Option.id(:riding)
      combatant = PlayerState.to_combatant(%{state | option: riding_bit})

      assert combatant.riding
    end

    test "a mounted spear hits a medium target at the large (100%) modifier", %{state: state} do
      riding_bit = Aesir.ZoneServer.Mmo.Option.id(:riding)
      # Javelin (id 1401), subtype one_handed_spear, worn on the right hand (bitmask 2).
      mounted = PlayerState.to_combatant(%{with_weapon(state, 1401, 2) | option: riding_bit})
      on_foot = PlayerState.to_combatant(with_weapon(state, 1401, 2))

      assert mounted.weapon.type == :one_handed_spear
      assert mounted.riding
      refute on_foot.riding

      assert SizeModifiers.get_modifier(mounted.weapon.type, :medium, mounted.riding) == 100
      assert SizeModifiers.get_modifier(on_foot.weapon.type, :medium, on_foot.riding) == 75
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

  defp set_game_mode(mode) do
    Application.put_env(:commons, :game_mode, mode)
    :persistent_term.erase(GameMode)
  end

  defp restore_game_mode({configured_mode, cached_mode}) do
    case configured_mode do
      {:ok, mode} -> Application.put_env(:commons, :game_mode, mode)
      :error -> Application.delete_env(:commons, :game_mode)
    end

    if cached_mode do
      :persistent_term.put(GameMode, cached_mode)
    else
      :persistent_term.erase(GameMode)
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

defmodule Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandlerTest do
  use ExUnit.Case, async: false
  import Bitwise
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ParamChange
  alias Aesir.Net.SkillList
  alias Aesir.Net.SpriteChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MountHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(SkillTree)
    StatusStorage.remove_status(:player, 1000, :sc_riding)
    StatusStorage.remove_status(:player, 1000, :sc_falcon)

    on_exit(fn ->
      StatusStorage.remove_status(:player, 1000, :sc_riding)
      StatusStorage.remove_status(:player, 1000, :sc_falcon)
    end)

    :ok
  end

  {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
  @knight_id knight_id
  {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
  @novice_id novice_id
  {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
  @swordman_id swordman_id
  {:ok, merchant_id} = AvailableJobs.job_name_to_id(:merchant)
  @merchant_id merchant_id
  {:ok, dragon_knight_id} = AvailableJobs.job_name_to_id(:dragon_knight)
  @dragon_knight_id dragon_knight_id
  {:ok, dragon_knight2_id} = AvailableJobs.job_name_to_id(:dragon_knight2)
  @dragon_knight2_id dragon_knight2_id
  {:ok, rune_knight_id} = AvailableJobs.job_name_to_id(:rune_knight)
  @rune_knight_id rune_knight_id
  @unknown_job_id 99_999

  setup do
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)

    stub(UnitRegistry, :get_unit_info, fn :player, 1000 ->
      {:ok,
       %{
         unit_id: 1000,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{level: 50, base_level: 50, str: 10, agi: 1, vit: 1, int: 1, dex: 1, luk: 1}
       }}
    end)

    stub(CharacterPersistence, :update_character, fn 1000, _attrs, async: true -> {:ok, %{}} end)
    stub(Broadcast, :to_player, fn _char_id, _packet -> :ok end)
    stub(Broadcast, :to_visible_players, fn _game_state, _packet, _opts -> :ok end)

    :ok
  end

  defp state do
    base = PlayerState.new(character())
    %{connection_pid: self(), game_state: base}
  end

  defp state_with(progression_overrides) do
    base = PlayerState.new(character())
    progression = struct(base.stats.progression, progression_overrides)
    game_state = %{base | stats: %{base.stats | progression: progression}}
    %{connection_pid: self(), game_state: game_state}
  end

  defp state_with_gs(progression_overrides, gs_overrides) do
    base = PlayerState.new(character())
    progression = struct(base.stats.progression, progression_overrides)
    game_state = struct(%{base | stats: %{base.stats | progression: progression}}, gs_overrides)
    %{connection_pid: self(), game_state: game_state}
  end

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp character do
    %Aesir.Commons.Models.Character{
      id: 1000,
      account_id: 2000,
      name: "Swordy",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 10,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 50,
      class: 1
    }
  end

  describe "handle_add_base_level/2 trait-point grant" do
    test "leveling 200 -> 201 grants +3 trait points" do
      state = state_with(job_id: @dragon_knight_id, base_level: 200)

      {:noreply, new_state} = ProgressionHandler.handle_add_base_level(1, state)

      assert new_state.game_state.stats.progression.trait_point == 3
    end

    test "leveling 204 -> 205 grants +7 trait points" do
      state = state_with(job_id: @dragon_knight_id, base_level: 204)

      {:noreply, new_state} = ProgressionHandler.handle_add_base_level(1, state)

      assert new_state.game_state.stats.progression.trait_point == 7
    end

    test "leveling below 201 grants 0 trait points" do
      state = state_with(job_id: @swordman_id, base_level: 50)

      {:noreply, new_state} = ProgressionHandler.handle_add_base_level(1, state)

      assert new_state.game_state.stats.progression.trait_point == 0
    end

    test "a non-4th-job character gains 0 trait points across a level-up" do
      state = state_with(job_id: @swordman_id, base_level: 90)

      {:noreply, new_state} = ProgressionHandler.handle_add_base_level(20, state)

      assert new_state.game_state.stats.progression.base_level == 99
      assert new_state.game_state.stats.progression.trait_point == 0
    end

    test "trait_point is persisted" do
      test_pid = self()

      stub(CharacterPersistence, :update_character, fn 1000, attrs, async: true ->
        send(test_pid, {:persisted, attrs})
        {:ok, %{}}
      end)

      state = state_with(job_id: @dragon_knight_id, base_level: 200)

      ProgressionHandler.handle_add_base_level(1, state)

      assert_received {:persisted, %{trait_point: 3}}
    end

    test "trait_point is synced as a ParamChange" do
      state = state_with(job_id: @dragon_knight_id, base_level: 200)

      ProgressionHandler.handle_add_base_level(1, state)

      trait_point = StatusParams.trait_point()

      assert_received {:send, _channel,
                       {:param_change, %ParamChange{var_id: ^trait_point, value: 3}}}
    end
  end

  describe "apply_job_change/2 with a valid job id" do
    test "updates progression.job_id, recomputes stats, and returns {:ok, new_state}" do
      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@knight_id, state())

      assert new_state.game_state.stats.progression.job_id == @knight_id
    end

    test "broadcasts the base-look SpriteChange to the player" do
      test_pid = self()

      stub(Broadcast, :to_player, fn 1000, packet ->
        send(test_pid, {:to_player, packet})
        :ok
      end)

      ProgressionHandler.apply_job_change(@knight_id, state())

      assert_received {:to_player, %SpriteChange{gid: 1000, val: @knight_id}}
    end

    test "sends a refreshed SkillList built from the new progression" do
      ProgressionHandler.apply_job_change(@knight_id, state())

      assert_received {:send, :bulk, {:skill_list, %SkillList{}}}
    end

    test "publishes the numeric job and final healed vitals to the party" do
      state = state_with_gs([job_id: @swordman_id], party_id: 7)

      expect(Manager, :sync_member, fn 7, 1000, member ->
        assert %Member{
                 char_id: 1000,
                 name: "Swordy",
                 job_id: @knight_id,
                 base_level: 50,
                 hp: hp,
                 max_hp: max_hp,
                 sp: sp,
                 max_sp: max_sp,
                 ap: ap,
                 max_ap: max_ap,
                 online: true,
                 map_name: "prontera"
               } = member

        assert hp == max_hp
        assert sp == max_sp
        assert ap == max_ap
        {:ok, %{}}
      end)

      assert {:ok, _new_state} = ProgressionHandler.apply_job_change(@knight_id, state)
    end

    test "publishes a job-only party transition" do
      state = state_with_gs([job_id: @swordman_id], party_id: 7)
      stats = state.game_state.stats

      current = %{
        stats.current_state
        | hp: stats.derived_stats.max_hp,
          sp: stats.derived_stats.max_sp,
          ap: stats.derived_stats.max_ap
      }

      state = put_in(state.game_state.stats.current_state, current)
      stub(Stats, :calculate_stats, fn unchanged, 1000 -> unchanged end)

      expect(Manager, :sync_member, fn 7, 1000, %Member{job_id: @knight_id} ->
        {:ok, %{}}
      end)

      assert {:ok, _new_state} = ProgressionHandler.apply_job_change(@knight_id, state)
    end
  end

  describe "apply_job_change/2 with an unknown job id" do
    test "returns {:error, :unknown_job} without mutating state" do
      original = state()

      assert {:error, :unknown_job} =
               ProgressionHandler.apply_job_change(@unknown_job_id, original)
    end

    test "does not broadcast, persist, or send a skill list" do
      reject(&Broadcast.to_player/2)
      reject(&CharacterPersistence.update_character/3)

      ProgressionHandler.apply_job_change(@unknown_job_id, state())

      refute_received {:send, :bulk, {:skill_list, _}}
    end
  end

  describe "apply_job_change/2 rAthena cleanup" do
    test "prunes out-of-tree skills without refunding, keeps in-tree skills" do
      sm_bash = catalog_id(:sm_bash)
      tf_steal = catalog_id(:tf_steal)

      state =
        state_with(
          job_id: @novice_id,
          learned_skills: %{sm_bash => 3, tf_steal => 5},
          skill_point: 2,
          job_level: 40,
          job_exp: 500
        )

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@swordman_id, state)
      progression = new_state.game_state.stats.progression

      assert progression.learned_skills == %{sm_bash => 3}
      assert progression.skill_point == 2
    end

    test "resets job level to 1 and job exp to 0" do
      state = state_with(job_id: @novice_id, job_level: 40, job_exp: 500)

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@swordman_id, state)
      progression = new_state.game_state.stats.progression

      assert progression.job_level == 1
      assert progression.job_exp == 0
    end

    test "a change to the current job is a no-op returning state unchanged" do
      state =
        state_with(
          job_id: @novice_id,
          job_level: 40,
          learned_skills: %{catalog_id(:nv_basic) => 9}
        )

      assert {:ok, ^state} = ProgressionHandler.apply_job_change(@novice_id, state)
      refute_received {:send, :bulk, {:skill_list, _}}
    end
  end

  describe "apply_job_change/2 cart guard" do
    test "blocks the change (empty cart) when it would drop MC_PUSHCART, mutating nothing" do
      reject(&CharacterPersistence.update_character/3)
      reject(&Broadcast.to_player/2)

      state =
        state_with_gs(
          [job_id: @novice_id, learned_skills: %{catalog_id(:mc_pushcart) => 5}],
          cart_type: 1,
          cart: %{}
        )

      assert {:error, :cart_active} = ProgressionHandler.apply_job_change(@swordman_id, state)
      refute_received {:send, :bulk, {:skill_list, _}}
    end

    test "blocks the change (loaded cart) when it would drop MC_PUSHCART" do
      reject(&CharacterPersistence.update_character/3)

      cart = %{0 => %InventoryItem{id: 9, nameid: 501, amount: 3}}

      state =
        state_with_gs(
          [job_id: @novice_id, learned_skills: %{catalog_id(:mc_pushcart) => 5}],
          cart_type: 1,
          cart: cart
        )

      assert {:error, :cart_active} = ProgressionHandler.apply_job_change(@swordman_id, state)
    end

    test "proceeds when no cart is mounted even though MC_PUSHCART is dropped" do
      state =
        state_with_gs(
          [job_id: @novice_id, learned_skills: %{catalog_id(:mc_pushcart) => 5}],
          cart_type: 0
        )

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@swordman_id, state)
      assert new_state.game_state.stats.progression.learned_skills == %{}
    end
  end

  describe "apply_job_change/2 equipment re-check" do
    test "force-unequips items the new job cannot wear, keeps wearable ones" do
      test_pid = self()

      stub(ItemManagement, :get_item_by_id, fn
        1101 ->
          {:ok,
           %ItemDefinition{
             id: 1101,
             aegis_name: "Restricted",
             name: "Restricted",
             jobs: [:acolyte]
           }}

        1201 ->
          {:ok, %ItemDefinition{id: 1201, aegis_name: "Wearable", name: "Wearable", jobs: []}}

        _ ->
          {:error, :not_found}
      end)

      stub(EquipmentHandler, :handle_unequip, fn index, st ->
        send(test_pid, {:unequipped, index})
        {:noreply, st}
      end)

      inventory = %{
        0 => %InventoryItem{id: 1, nameid: 1101, amount: 1, equip: 16},
        1 => %InventoryItem{id: 2, nameid: 1201, amount: 1, equip: 32}
      }

      state = state_with_gs([job_id: @novice_id], inventory: inventory)

      ProgressionHandler.apply_job_change(@swordman_id, state)

      assert_received {:unequipped, 0}
      refute_received {:unequipped, 1}
    end
  end

  describe "apply_job_change/2 riding dismount" do
    test "force-dismounts a mounted Peco-Peco when the new job's tree drops KN_RIDING" do
      riding_bit = Option.id(:riding)
      kn_riding = catalog_id(:kn_riding)
      kn_cavalier = catalog_id(:kn_cavaliermastery)

      :ok = StatusStorage.apply_status(:player, 1000, :sc_riding, val1: 3)

      state =
        state_with_gs(
          [job_id: @knight_id, learned_skills: %{kn_riding => 1, kn_cavalier => 3}],
          option: riding_bit
        )

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@merchant_id, state)

      refute MountHandler.riding?(new_state)
      assert new_state.game_state.option == 0
      refute StatusStorage.has_status?(:player, 1000, :sc_riding)
    end

    test "keeps the mount when the new job's tree still grants KN_RIDING" do
      riding_bit = Option.id(:riding)
      kn_riding = catalog_id(:kn_riding)
      kn_cavalier = catalog_id(:kn_cavaliermastery)

      :ok = StatusStorage.apply_status(:player, 1000, :sc_riding, val1: 3)

      state =
        state_with_gs(
          [job_id: @swordman_id, learned_skills: %{kn_riding => 1, kn_cavalier => 3}],
          option: riding_bit
        )

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@knight_id, state)

      assert MountHandler.riding?(new_state)
      assert new_state.game_state.option == riding_bit
      assert StatusStorage.has_status?(:player, 1000, :sc_riding)
    end

    test "is a no-op when the player is not mounted" do
      kn_riding = catalog_id(:kn_riding)
      state = state_with(job_id: @swordman_id, learned_skills: %{kn_riding => 1})

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@knight_id, state)

      refute MountHandler.riding?(new_state)
      refute StatusStorage.has_status?(:player, 1000, :sc_riding)
    end
  end

  describe "reset_skills/1" do
    test "refunds learned levels into skill points and clears them" do
      sm_bash = catalog_id(:sm_bash)

      state = state_with(job_id: @swordman_id, learned_skills: %{sm_bash => 4}, skill_point: 1)

      assert {:ok, new_state} = ProgressionHandler.reset_skills(state)
      progression = new_state.game_state.stats.progression

      assert progression.learned_skills == %{}
      assert progression.skill_point == 5
    end

    test "re-sends the skill list" do
      state = state_with(job_id: @swordman_id, learned_skills: %{catalog_id(:sm_bash) => 2})

      ProgressionHandler.reset_skills(state)

      assert_received {:send, :bulk, {:skill_list, %SkillList{}}}
    end

    test "syncs recalculated stats to the client (not just the skill list)" do
      state = state_with(job_id: @swordman_id, learned_skills: %{catalog_id(:sm_bash) => 2})

      ProgressionHandler.reset_skills(state)

      aspd = StatusParams.aspd()
      assert_received {:send, _channel, {:param_change, %ParamChange{var_id: ^aspd}}}
    end

    test "publishes maxima changed by the refunded passive against the pre-reset snapshot" do
      state =
        state_with_gs(
          [job_id: @swordman_id, learned_skills: %{catalog_id(:sm_bash) => 2}],
          party_id: 7
        )

      stats = state.game_state.stats
      derived = %{stats.derived_stats | max_hp: 500}
      current = %{stats.current_state | hp: 500}

      state =
        put_in(state.game_state.stats, %{stats | derived_stats: derived, current_state: current})

      stub(Stats, :calculate_stats, fn recalculated, 1000 ->
        %{recalculated | derived_stats: %{recalculated.derived_stats | max_hp: 250}}
      end)

      expect(Manager, :sync_member, fn 7, 1000, member ->
        assert %Member{hp: 250, max_hp: 250} = member
        {:ok, %{}}
      end)

      assert {:ok, _new_state} = ProgressionHandler.reset_skills(state)
    end

    test "is blocked while a cart is mounted, mutating nothing" do
      reject(&CharacterPersistence.update_character/3)

      state =
        state_with_gs(
          [job_id: @merchant_id, learned_skills: %{catalog_id(:mc_pushcart) => 5}],
          cart_type: 1
        )

      assert {:error, :cart_active} = ProgressionHandler.reset_skills(state)
      refute_received {:send, :bulk, {:skill_list, _}}
    end
  end

  describe "reset_skills/1 riding dismount" do
    test "force-dismounts a mounted Peco-Peco (KN_RIDING is never exempt from the refund)" do
      riding_bit = Option.id(:riding)
      kn_riding = catalog_id(:kn_riding)

      :ok = StatusStorage.apply_status(:player, 1000, :sc_riding, val1: 2)

      state =
        state_with_gs(
          [job_id: @swordman_id, learned_skills: %{kn_riding => 1}],
          option: riding_bit
        )

      assert {:ok, new_state} = ProgressionHandler.reset_skills(state)

      refute MountHandler.riding?(new_state)
      assert new_state.game_state.option == 0
      refute StatusStorage.has_status?(:player, 1000, :sc_riding)
    end

    test "is a no-op when the player is not mounted" do
      kn_riding = catalog_id(:kn_riding)
      state = state_with(job_id: @swordman_id, learned_skills: %{kn_riding => 1})

      assert {:ok, new_state} = ProgressionHandler.reset_skills(state)

      refute MountHandler.riding?(new_state)
      refute StatusStorage.has_status?(:player, 1000, :sc_riding)
    end
  end

  describe "reset_skills/1 falcon dismissal" do
    test "force-dismisses the Falcon when the refund drops HT_FALCON" do
      falcon_bit = Option.id(:falcon)
      ht_falcon = catalog_id(:ht_falcon)

      :ok = StatusStorage.apply_status(:player, 1000, :sc_falcon)

      state =
        state_with_gs(
          [job_id: @swordman_id, learned_skills: %{ht_falcon => 1}],
          option: falcon_bit
        )

      assert {:ok, new_state} = ProgressionHandler.reset_skills(state)

      refute FalconHandler.falcon?(new_state)
      assert new_state.game_state.option == 0
      refute StatusStorage.has_status?(:player, 1000, :sc_falcon)
    end

    test "is a no-op when no Falcon is equipped" do
      ht_falcon = catalog_id(:ht_falcon)
      state = state_with(job_id: @swordman_id, learned_skills: %{ht_falcon => 1})

      assert {:ok, new_state} = ProgressionHandler.reset_skills(state)

      refute FalconHandler.falcon?(new_state)
      assert new_state.game_state.option == 0
      refute StatusStorage.has_status?(:player, 1000, :sc_falcon)
    end
  end

  describe "apply_job_change/2 falcon dismissal" do
    test "force-dismisses the Falcon when the new job's tree drops HT_FALCON" do
      falcon_bit = Option.id(:falcon)
      riding_bit = Option.id(:riding)
      ht_falcon = catalog_id(:ht_falcon)

      :ok = StatusStorage.apply_status(:player, 1000, :sc_falcon)

      state =
        state_with_gs(
          [job_id: @swordman_id, learned_skills: %{ht_falcon => 1}],
          option: riding_bit ||| falcon_bit
        )

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@merchant_id, state)

      refute FalconHandler.falcon?(new_state)
      assert new_state.game_state.option == riding_bit
      refute StatusStorage.has_status?(:player, 1000, :sc_falcon)
    end
  end

  describe "apply_job_change/2 4th-job gating" do
    test "rejects a wrong-parent char with requirements_not_met, mutating nothing" do
      reject(&CharacterPersistence.update_character/3)
      reject(&Broadcast.to_player/2)

      state = state_with(job_id: @swordman_id, base_level: 200, job_level: 70)

      assert {:error, :requirements_not_met} =
               ProgressionHandler.apply_job_change(@dragon_knight_id, state)

      refute_received {:send, :bulk, {:skill_list, _}}
    end

    test "rejects when base level is below 200" do
      state = state_with(job_id: @rune_knight_id, base_level: 199, job_level: 70)

      assert {:error, :requirements_not_met} =
               ProgressionHandler.apply_job_change(@dragon_knight_id, state)
    end

    test "rejects when job level is below the parent's max job level" do
      state = state_with(job_id: @rune_knight_id, base_level: 200, job_level: 69)

      assert {:error, :requirements_not_met} =
               ProgressionHandler.apply_job_change(@dragon_knight_id, state)
    end

    test "allows an eligible rune_knight (base 200, job 70) to become dragon_knight" do
      state = state_with(job_id: @rune_knight_id, base_level: 200, job_level: 70)

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@dragon_knight_id, state)
      assert new_state.game_state.stats.progression.job_id == @dragon_knight_id
    end
  end

  describe "apply_job_change/2 trait-point grant and zeroing" do
    test "entering a trait job from a non-trait job grants +7 trait points" do
      state = state_with(job_id: @rune_knight_id, base_level: 200, job_level: 70, trait_point: 0)

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@dragon_knight_id, state)
      assert new_state.game_state.stats.progression.trait_point == 7
    end

    test "changing into an alt-variant trait id is rejected and grants nothing" do
      reject(&CharacterPersistence.update_character/3)

      state = state_with(job_id: @novice_id, base_level: 200, job_level: 50, trait_point: 0)

      assert {:error, :requirements_not_met} =
               ProgressionHandler.apply_job_change(@dragon_knight2_id, state)
    end

    test "on a successful 4th-job change, ap == max_ap and max_ap > 0" do
      state = state_with(job_id: @rune_knight_id, base_level: 200, job_level: 70)

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@dragon_knight_id, state)
      max_ap = new_state.game_state.stats.derived_stats.max_ap

      assert max_ap > 0
      assert new_state.game_state.stats.current_state.ap == max_ap
    end

    test "leaving a trait job for a non-trait job zeroes the six trait stats and trait_point" do
      test_pid = self()

      stub(CharacterPersistence, :update_character, fn 1000, attrs, async: true ->
        send(test_pid, {:persisted, attrs})
        {:ok, %{}}
      end)

      base = PlayerState.new(character())

      progression =
        struct(base.stats.progression,
          job_id: @dragon_knight_id,
          base_level: 200,
          trait_point: 20
        )

      base_stats =
        struct(base.stats.base_stats, pow: 15, sta: 12, wis: 8, spl: 6, con: 4, crt: 3)

      stats = %{base.stats | progression: progression, base_stats: base_stats}
      state = %{connection_pid: self(), game_state: %{base | stats: stats}}

      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@swordman_id, state)
      result = new_state.game_state.stats

      assert result.progression.trait_point == 0
      assert result.base_stats.pow == 0
      assert result.base_stats.sta == 0
      assert result.base_stats.wis == 0
      assert result.base_stats.spl == 0
      assert result.base_stats.con == 0
      assert result.base_stats.crt == 0

      assert_received {:persisted,
                       %{
                         trait_point: 0,
                         pow: 0,
                         sta: 0,
                         wis: 0,
                         spl: 0,
                         con: 0,
                         crt: 0
                       }}
    end
  end

  describe "reset_stats/1" do
    test "on a level-210 dragon_knight resets classic to 1, trait to 0, restores pools with +7" do
      state = state_with(job_id: @dragon_knight_id, base_level: 210)

      assert {:ok, new_state} = ProgressionHandler.reset_stats(state)
      stats = new_state.game_state.stats

      assert stats.base_stats.str == 1
      assert stats.base_stats.agi == 1
      assert stats.base_stats.vit == 1
      assert stats.base_stats.int == 1
      assert stats.base_stats.dex == 1
      assert stats.base_stats.luk == 1

      assert stats.base_stats.pow == 0
      assert stats.base_stats.sta == 0
      assert stats.base_stats.wis == 0
      assert stats.base_stats.spl == 0
      assert stats.base_stats.con == 0
      assert stats.base_stats.crt == 0

      assert stats.progression.status_point == StatPoint.points_at(210)
      assert stats.progression.trait_point == StatPoint.trait_points_at(210) + 7
    end

    test "on a non-trait job restores classic points and no +7 trait bonus" do
      state = state_with(job_id: @swordman_id, base_level: 90)

      assert {:ok, new_state} = ProgressionHandler.reset_stats(state)
      stats = new_state.game_state.stats

      assert stats.base_stats.str == 1
      assert stats.progression.status_point == StatPoint.points_at(90)
      assert stats.progression.trait_point == StatPoint.trait_points_at(90)
    end

    test "persists all twelve stat columns and both pools" do
      test_pid = self()

      stub(CharacterPersistence, :update_character, fn 1000, attrs, async: true ->
        send(test_pid, {:persisted, attrs})
        {:ok, %{}}
      end)

      state = state_with(job_id: @dragon_knight_id, base_level: 210)

      ProgressionHandler.reset_stats(state)

      assert_received {:persisted,
                       %{
                         str: 1,
                         agi: 1,
                         vit: 1,
                         int: 1,
                         dex: 1,
                         luk: 1,
                         pow: 0,
                         sta: 0,
                         wis: 0,
                         spl: 0,
                         con: 0,
                         crt: 0,
                         status_point: _,
                         trait_point: _
                       }}
    end

    test "syncs the recalculated classic stats to the client" do
      state = state_with(job_id: @dragon_knight_id, base_level: 210)

      ProgressionHandler.reset_stats(state)

      str = StatusParams.str()
      assert_received {:send, _channel, {:param_change, %ParamChange{var_id: ^str, value: 1}}}
    end
  end

  describe "handle_change_job/2" do
    test "returns {:noreply, new_state} on a valid job id" do
      assert {:noreply, new_state} = ProgressionHandler.handle_change_job(@knight_id, state())

      assert new_state.game_state.stats.progression.job_id == @knight_id
    end

    test "returns {:noreply, state} unchanged on an unknown job id" do
      original = state()

      assert {:noreply, ^original} =
               ProgressionHandler.handle_change_job(@unknown_job_id, original)
    end
  end
end

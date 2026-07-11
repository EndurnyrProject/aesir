defmodule Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandlerTest do
  use ExUnit.Case, async: true
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
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
  @knight_id knight_id
  {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
  @novice_id novice_id
  {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
  @swordman_id swordman_id
  {:ok, merchant_id} = AvailableJobs.job_name_to_id(:merchant)
  @merchant_id merchant_id
  @unknown_job_id 99_999

  setup do
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
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

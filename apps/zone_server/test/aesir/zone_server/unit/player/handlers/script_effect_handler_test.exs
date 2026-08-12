defmodule Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandlerTest do
  @moduledoc """
  The single-writer effect seam: `{:script_apply, op}` applied to the
  authoritative session `PlayerState`. Each op mutates state, persists, and
  pushes the relevant proto to the client, returning the fresh `game_state` (or
  an error that mutates nothing).
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ParamChange
  alias Aesir.Net.QuestAdded
  alias Aesir.Net.QuestRemoved
  alias Aesir.Net.QuestStateChanged
  alias Aesir.Net.SpriteChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @sphmask_id 7114
  @zeny_param 20

  @hunt %QuestDefinition{
    id: 7393,
    title: "Shiny Silver Blade",
    targets: [%{mob_id: 2314, count: 10}]
  }

  @other_hunt %QuestDefinition{id: 8000, title: "Twin Objective", targets: []}

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(Items)
    Mimic.copy(InventoryOps)
    Mimic.copy(CharacterPersistence)
    Mimic.copy(Broadcast)
    Mimic.copy(UnitRegistry)
    Mimic.copy(StorageHandler)
    Mimic.copy(QuestPersistence)

    stub(CharacterPersistence, :update_character, fn _, _, _ -> {:ok, %Character{}} end)
    stub(Broadcast, :to_player, fn _char_id, _packet -> :ok end)
    stub(Broadcast, :to_visible_players, fn _game_state, _packet, _opts -> :ok end)
    stub(UnitRegistry, :update_unit_state, fn :player, _char_id, _game_state -> :ok end)

    defs = [@hunt, @other_hunt]
    index = %{all: defs, by_id: Map.new(defs, &{&1.id, &1})}
    :persistent_term.put(Quests, index)
    on_exit(fn -> :persistent_term.erase(Quests) end)

    :ok
  end

  describe "{:set_char_var, key, value}" do
    test "puts the string-keyed value into vars, persists, and returns the new game_state" do
      test_pid = self()

      expect(CharacterPersistence, :update_character, fn 1000, %{vars: vars}, async: true ->
        send(test_pid, {:persisted_vars, vars})
        {:ok, %Character{}}
      end)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:set_char_var, :sphmask_q, 1}, base_state())

      assert {:ok, game_state} = reply
      assert game_state.vars == %{"sphmask_q" => 1}
      assert new_state.game_state.vars == %{"sphmask_q" => 1}
      assert_received {:persisted_vars, %{"sphmask_q" => 1}}
    end
  end

  describe "{:set_temp_var, key, value}" do
    test "puts the string-keyed value into temp_vars without persisting" do
      reject(&CharacterPersistence.update_character/3)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:set_temp_var, :quest_step, 3}, base_state())

      assert {:ok, game_state} = reply
      assert game_state.temp_vars == %{"quest_step" => 3}
      assert new_state.game_state.temp_vars == %{"quest_step" => 3}
    end
  end

  describe "{:set_look, type, value}" do
    test "writes and persists the appearance field, then pushes a SpriteChange to self and observers" do
      test_pid = self()

      expect(CharacterPersistence, :update_character, fn 1000, %{hair: 5}, async: true ->
        send(test_pid, {:persisted_look, :hair})
        {:ok, %Character{}}
      end)

      expect(Broadcast, :to_visible_players, fn _gs, %SpriteChange{type: 1, val: 5}, _opts ->
        send(test_pid, :look_broadcast)
        :ok
      end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:set_look, 1, 5}, base_state())

      assert {:ok, game_state} = reply
      assert game_state.hair == 5
      assert new_state.game_state.hair == 5

      assert_received {:persisted_look, :hair}
      assert_received :look_broadcast

      assert_received {:send, _ch,
                       {:sprite_change, %SpriteChange{gid: 1000, type: 1, val: 5, val2: 0}}}
    end

    test "maps each supported look type to its persisted appearance field" do
      for {type, field, value} <- [
            {1, :hair, 5},
            {3, :head_bottom, 7},
            {5, :head_mid, 4},
            {6, :hair_color, 2},
            {7, :clothes_color, 3},
            {12, :robe, 6}
          ] do
        expect(CharacterPersistence, :update_character, fn 1000,
                                                           %{^field => ^value},
                                                           async: true ->
          {:ok, %Character{}}
        end)

        {reply, new_state} = ScriptEffectHandler.apply_op({:set_look, type, value}, base_state())
        assert {:ok, game_state} = reply
        assert Map.get(game_state, field) == value
        assert Map.get(new_state.game_state, field) == value
      end
    end
  end

  describe "{:pay_zeny, amount}" do
    test "debits, pushes the zeny param, persists, returns the new game_state" do
      test_pid = self()

      expect(CharacterPersistence, :update_character, fn 1000, %{zeny: zeny}, async: true ->
        send(test_pid, {:persisted_zeny, zeny})
        {:ok, %Character{}}
      end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:pay_zeny, 500}, base_state(zeny: 1_000))

      assert {:ok, game_state} = reply
      assert game_state.zeny == 500
      assert new_state.game_state.zeny == 500
      assert_received {:send, _ch, {:param_change, %ParamChange{var_id: @zeny_param, value: 500}}}
      assert_received {:persisted_zeny, 500}
    end

    test "rejects :not_enough_zeny when short and debits nothing" do
      reject(&CharacterPersistence.update_character/3)

      state = base_state(zeny: 100)
      {reply, new_state} = ScriptEffectHandler.apply_op({:pay_zeny, 500}, state)

      assert reply == {:error, :not_enough_zeny}
      assert new_state == state
      refute_received {:send, _ch, {:param_change, _}}
    end
  end

  describe "{:credit_zeny, amount}" do
    test "credits, pushes the zeny param, persists, returns the new game_state" do
      test_pid = self()

      expect(CharacterPersistence, :update_character, fn 1000, %{zeny: zeny}, async: true ->
        send(test_pid, {:persisted_zeny, zeny})
        {:ok, %Character{}}
      end)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:credit_zeny, 500}, base_state(zeny: 1_000))

      assert {:ok, game_state} = reply
      assert game_state.zeny == 1_500
      assert new_state.game_state.zeny == 1_500

      assert_received {:send, _ch,
                       {:param_change, %ParamChange{var_id: @zeny_param, value: 1_500}}}

      assert_received {:persisted_zeny, 1_500}
    end

    test "clamps the credited total to MAX_ZENY" do
      {reply, new_state} =
        ScriptEffectHandler.apply_op({:credit_zeny, 500}, base_state(zeny: 999_999_999))

      assert {:ok, game_state} = reply
      assert game_state.zeny == 1_000_000_000
      assert new_state.game_state.zeny == 1_000_000_000
    end
  end

  describe "{:give_item, item_id, qty}" do
    test "adds via InventoryOps, emits ItemAdded, returns the new game_state" do
      definition = item_definition(@sphmask_id)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)

      added = %InventoryItem{nameid: @sphmask_id, amount: 1}

      expect(InventoryOps, :add, fn 1000, %{}, _stats, ^definition, 1 ->
        {:ok, %{0 => added}, {:added, 0, added}}
      end)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:give_item, @sphmask_id, 1}, base_state())

      assert {:ok, game_state} = reply
      assert game_state.inventory == %{0 => added}
      assert new_state.game_state.inventory == %{0 => added}
      assert_received {:send, _ch, {:item_added, %ItemAdded{}}}
    end

    test "rejects :inventory_full and mutates nothing" do
      definition = item_definition(@sphmask_id)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)
      stub(InventoryOps, :add, fn _, _, _, _, _ -> {:error, :inventory_full} end)

      state = base_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:give_item, @sphmask_id, 1}, state)

      assert reply == {:error, :inventory_full}
      assert new_state == state
      refute_received {:send, _ch, {:item_added, _}}
    end

    test "rejects :item_not_found for an unknown item id" do
      stub(Items, :by_id, fn _ -> :error end)
      reject(&InventoryOps.add/6)

      state = base_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:give_item, 9_999_999, 1}, state)

      assert reply == {:error, :item_not_found}
      assert new_state == state
    end
  end

  describe "{:give_items_atomic, grants}" do
    test "commits the batch inventory through the single-writer handler" do
      added = %InventoryItem{nameid: 501, amount: 1}

      expect(InventoryOps, :add_many, fn 1000, %{}, [{definition, 1, _opts}] ->
        assert definition.id == 501
        {:ok, %{0 => added}}
      end)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:give_items_atomic, [group_grant(501)]}, base_state())

      assert {:ok, game_state} = reply
      assert game_state.inventory == %{0 => added}
      assert new_state.game_state.inventory == %{0 => added}
    end

    test "surfaces insufficient_space and leaves state untouched" do
      reject(&InventoryOps.add_many/3)
      state = base_state()
      grant = %{group_grant(1101) | amount: 101}

      assert ScriptEffectHandler.apply_op({:give_items_atomic, [grant]}, state) ==
               {{:error, :insufficient_space}, state}
    end
  end

  describe "{:give_item_rental, item_id, seconds, opts}" do
    test "adds one time-limited rental item" do
      definition = item_definition(@sphmask_id, type: :weapon)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)

      seconds = 60
      expected_expiry = NaiveDateTime.add(NaiveDateTime.utc_now(), seconds, :second)

      expect(InventoryOps, :add, fn 1000, %{}, _stats, ^definition, 1, %{expire_time: expiry} ->
        assert abs(NaiveDateTime.diff(expiry, expected_expiry, :second)) <= 2

        added = %InventoryItem{nameid: @sphmask_id, amount: 1, expire_time: expiry}
        {:ok, %{0 => added}, {:added, 0, added}}
      end)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:give_item_rental, @sphmask_id, seconds, []}, base_state())

      assert {:ok, game_state} = reply
      assert map_size(game_state.inventory) == 1
      assert %InventoryItem{expire_time: expire_time} = game_state.inventory[0]
      assert expire_time != nil
      assert new_state.game_state.inventory == game_state.inventory
      assert_received {:send, _ch, {:item_added, %ItemAdded{}}}
    end

    test "rejects a non-positive duration without adding an item" do
      definition = item_definition(@sphmask_id, type: :weapon)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)
      reject(&InventoryOps.add/6)

      state = base_state()

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:give_item_rental, @sphmask_id, 0, []}, state)

      assert reply == {:error, :bad_duration}
      assert new_state == state
      refute_received {:send, _ch, {:item_added, _}}
    end

    test "rejects a non-rentable item type without adding an item" do
      definition = item_definition(@sphmask_id, type: :usable)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)
      reject(&InventoryOps.add/6)

      state = base_state()

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:give_item_rental, @sphmask_id, 60, []}, state)

      assert reply == {:error, :not_rentable}
      assert new_state == state
      refute_received {:send, _ch, {:item_added, _}}
    end

    test "passes rental item attributes to the inventory add" do
      definition = item_definition(@sphmask_id, type: :armor)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)

      random_options = %{"1" => %{val: 5, parm: 10}}

      expect(InventoryOps, :add, fn 1000,
                                    %{},
                                    _stats,
                                    ^definition,
                                    1,
                                    %{
                                      expire_time: expiry,
                                      refine: 7,
                                      card0: 4001,
                                      random_options: ^random_options
                                    } ->
        added = %InventoryItem{
          nameid: @sphmask_id,
          amount: 1,
          expire_time: expiry,
          refine: 7,
          card0: 4001,
          random_options: random_options
        }

        {:ok, %{0 => added}, {:added, 0, added}}
      end)

      {reply, new_state} =
        ScriptEffectHandler.apply_op(
          {:give_item_rental, @sphmask_id, 60,
           [refine: 7, card0: 4001, random_options: random_options]},
          base_state()
        )

      assert {:ok, game_state} = reply

      assert %InventoryItem{refine: 7, card0: 4001, random_options: ^random_options} =
               game_state.inventory[0]

      assert new_state.game_state.inventory == game_state.inventory
    end

    test "rejects a full inventory without adding an item" do
      definition = item_definition(@sphmask_id, type: :weapon)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)
      stub(InventoryOps, :add, fn _, _, _, _, _, _ -> {:error, :inventory_full} end)

      state = base_state()

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:give_item_rental, @sphmask_id, 60, []}, state)

      assert reply == {:error, :inventory_full}
      assert new_state == state
      refute_received {:send, _ch, {:item_added, _}}
    end
  end

  describe "{:give_item_bound, item_id, qty, bound}" do
    for {bound, value} <- [account: 1, char: 4] do
      test "adds a #{bound}-bound item" do
        definition = item_definition(@sphmask_id)
        stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)

        added = %InventoryItem{nameid: @sphmask_id, amount: 1, bound: unquote(value)}

        expect(InventoryOps, :add, fn 1000,
                                      %{},
                                      _stats,
                                      ^definition,
                                      1,
                                      %{bound: unquote(value)} ->
          {:ok, %{0 => added}, {:added, 0, added}}
        end)

        {reply, new_state} =
          ScriptEffectHandler.apply_op(
            {:give_item_bound, @sphmask_id, 1, unquote(value)},
            base_state()
          )

        assert {:ok, game_state} = reply
        assert game_state.inventory == %{0 => added}
        assert new_state.game_state.inventory == %{0 => added}
        assert_received {:send, _ch, {:item_added, %ItemAdded{}}}
      end
    end
  end

  describe "{:delitem, item_id, qty}" do
    test "removes the held stack via InventoryOps, emits ItemRemoved, returns new game_state" do
      held = %InventoryItem{id: 1, nameid: @sphmask_id, amount: 3}
      state = base_state(inventory: %{0 => held})

      expect(InventoryOps, :remove, fn 1000, %{0 => ^held}, 0, 2 ->
        {:ok, %{0 => %{held | amount: 1}}, {:reduced, 0, 1}}
      end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:delitem, @sphmask_id, 2}, state)

      assert {:ok, game_state} = reply
      assert game_state.inventory[0].amount == 1
      assert new_state.game_state.inventory[0].amount == 1
      assert_received {:send, _ch, {:item_removed, %ItemRemoved{amount: 2}}}
    end

    test "rejects :not_enough_items when the player holds fewer, mutating nothing" do
      state = base_state(inventory: %{0 => %InventoryItem{nameid: @sphmask_id, amount: 1}})
      reject(&InventoryOps.remove/4)

      {reply, new_state} = ScriptEffectHandler.apply_op({:delitem, @sphmask_id, 5}, state)

      assert reply == {:error, :not_enough_items}
      assert new_state == state
      refute_received {:send, _ch, {:item_removed, _}}
    end
  end

  describe "{:give_item2, item_id, qty, attrs}" do
    test "adds via InventoryOps with the attribute map, emits ItemAdded, returns the new game_state" do
      definition = item_definition(@sphmask_id)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)

      attrs = %{identify: 1, refine: 4, card0: 4001}
      added = %InventoryItem{nameid: @sphmask_id, amount: 1}

      expect(InventoryOps, :add, fn 1000, %{}, _stats, ^definition, 1, ^attrs ->
        {:ok, %{0 => added}, {:added, 0, added}}
      end)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:give_item2, @sphmask_id, 1, attrs}, base_state())

      assert {:ok, game_state} = reply
      assert game_state.inventory == %{0 => added}
      assert new_state.game_state.inventory == %{0 => added}
      assert_received {:send, _ch, {:item_added, %ItemAdded{}}}
    end

    test "rejects :inventory_full and mutates nothing" do
      definition = item_definition(@sphmask_id)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)
      stub(InventoryOps, :add, fn _, _, _, _, _, _ -> {:error, :inventory_full} end)

      state = base_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:give_item2, @sphmask_id, 1, %{}}, state)

      assert reply == {:error, :inventory_full}
      assert new_state == state
      refute_received {:send, _ch, {:item_added, _}}
    end

    test "rejects :item_not_found for an unknown item id" do
      stub(Items, :by_id, fn _ -> :error end)
      reject(&InventoryOps.add/6)

      state = base_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:give_item2, 9_999_999, 1, %{}}, state)

      assert reply == {:error, :item_not_found}
      assert new_state == state
    end
  end

  describe "{:delequip, index, nameid}" do
    test "unequips then removes the item, emits ItemRemoved, returns the new game_state" do
      sword = %InventoryItem{id: 1, nameid: 1201, equip: 2, amount: 1}
      state = base_state(inventory: %{0 => sword})

      Mimic.copy(EquipmentHandler)

      expect(EquipmentHandler, :handle_unequip, fn 0, st -> {:noreply, st} end)

      expect(InventoryOps, :remove, fn 1000, %{0 => ^sword}, 0, 1 ->
        {:ok, %{}, {:removed, 0}}
      end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:delequip, 0, 1201}, state)

      assert {:ok, game_state} = reply
      assert game_state.inventory == %{}
      assert new_state.game_state.inventory == %{}
      assert_received {:send, _ch, {:item_removed, %ItemRemoved{amount: 1}}}
    end

    test "rejects :not_equipped when the item is not worn, mutating nothing" do
      state =
        base_state(inventory: %{0 => %InventoryItem{nameid: 1201, equip: 0, amount: 1}})

      reject(&InventoryOps.remove/4)

      {reply, new_state} = ScriptEffectHandler.apply_op({:delequip, 0, 1201}, state)

      assert reply == {:error, :not_equipped}
      assert new_state == state
      refute_received {:send, _ch, {:item_removed, _}}
    end

    test "rejects :no_item when the slot is empty or the nameid changed" do
      state =
        base_state(inventory: %{0 => %InventoryItem{nameid: 1201, equip: 2, amount: 1}})

      reject(&InventoryOps.remove/4)

      {reply, new_state} = ScriptEffectHandler.apply_op({:delequip, 0, 9999}, state)

      assert reply == {:error, :no_item}
      assert new_state == state
    end
  end

  describe "{:disable_items}" do
    test "sets the item-use suppression flag on the game_state" do
      state = base_state()

      {reply, new_state} = ScriptEffectHandler.apply_op({:disable_items}, state)

      assert {:ok, game_state} = reply
      assert game_state.disable_item_use == true
      assert new_state.game_state.disable_item_use == true
    end
  end

  describe "{:nude}" do
    test "unequips every worn slot by folding the single-item unequip, skipping bare items" do
      test_pid = self()

      state =
        base_state(
          inventory: %{
            0 => %InventoryItem{nameid: 1201, equip: 2},
            1 => %InventoryItem{nameid: 2301, equip: 16},
            2 => %InventoryItem{nameid: 909, equip: 0}
          }
        )

      Mimic.copy(EquipmentHandler)

      expect(EquipmentHandler, :handle_unequip, 2, fn index, st ->
        send(test_pid, {:unequipped, index})
        {:noreply, st}
      end)

      {reply, _new_state} = ScriptEffectHandler.apply_op({:nude}, state)

      assert {:ok, _game_state} = reply
      assert_received {:unequipped, 0}
      assert_received {:unequipped, 1}
      refute_received {:unequipped, 2}
    end

    test "is a no-op when nothing is equipped" do
      state = base_state(inventory: %{0 => %InventoryItem{nameid: 909, equip: 0}})

      Mimic.copy(EquipmentHandler)
      reject(&EquipmentHandler.handle_unequip/2)

      {reply, new_state} = ScriptEffectHandler.apply_op({:nude}, state)

      assert reply == {:ok, state.game_state}
      assert new_state == state
    end
  end

  describe "{:change_job, job_id}" do
    test "updates progression.job_id and returns the new game_state" do
      {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:change_job, knight_id}, job_change_state())

      assert {:ok, game_state} = reply
      assert game_state.stats.progression.job_id == knight_id
      assert new_state.game_state.stats.progression.job_id == knight_id
    end

    test "rejects :unknown_job and mutates nothing" do
      reject(&CharacterPersistence.update_character/3)

      state = job_change_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:change_job, 99_999}, state)

      assert reply == {:error, :unknown_job}
      assert new_state == state
    end
  end

  describe "{:grant_skill, skill_id_or_name, level}" do
    test "delegates to SkillLearningHandler.grant_skill/3 and returns its game_state" do
      state = base_state()
      granted_state = %{state | game_state: %{state.game_state | zeny: 1}}

      expect(SkillLearningHandler, :grant_skill, fn 9001, 3, ^state -> {:ok, granted_state} end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:grant_skill, 9001, 3}, state)

      assert reply == {:ok, granted_state.game_state}
      assert new_state == granted_state
    end

    test "returns the handler's error unchanged and mutates nothing" do
      state = base_state()

      expect(SkillLearningHandler, :grant_skill, fn 9001, 1, ^state ->
        {:error, :not_grantable}
      end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:grant_skill, 9001, 1}, state)

      assert reply == {:error, :not_grantable}
      assert new_state == state
    end
  end

  describe "{:openstorage}" do
    test "delegates to StorageHandler.open/1 and returns its game_state" do
      state = base_state()
      opened_state = %{state | game_state: %{state.game_state | storage: %{}}}

      expect(StorageHandler, :open, fn ^state -> {:noreply, opened_state} end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:openstorage}, state)

      assert {:ok, game_state} = reply
      assert game_state.storage == %{}
      assert new_state.game_state.storage == %{}
    end
  end

  describe "{:setcart, type}" do
    test "type 0 delegates to CartHandler.unmount/1" do
      state = base_state()

      Mimic.copy(CartHandler)
      expect(CartHandler, :unmount, fn ^state -> {:noreply, state} end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:setcart, 0}, state)

      assert reply == {:ok, state.game_state}
      assert new_state == state
    end

    test "a non-zero type delegates to CartHandler.mount/1 when no cart is on" do
      state = base_state()

      Mimic.copy(CartHandler)
      expect(CartHandler, :mount, fn ^state -> {:noreply, state} end)

      {reply, _new_state} = ScriptEffectHandler.apply_op({:setcart, 1}, state)

      assert reply == {:ok, state.game_state}
    end

    test "a non-zero type is a no-op success when already mounted" do
      state = base_state()
      state = %{state | game_state: %{state.game_state | cart_type: 2}}

      Mimic.copy(CartHandler)
      reject(&CartHandler.mount/1)

      {reply, new_state} = ScriptEffectHandler.apply_op({:setcart, 1}, state)

      assert reply == {:ok, state.game_state}
      assert new_state == state
    end
  end

  describe "{:setquest, quest_id}" do
    test "adds the quest active with zeroed counters, upserts, pushes QuestAdded" do
      test_pid = self()

      expect(QuestPersistence, :upsert, fn 1000, {7393, entry} ->
        send(test_pid, {:upserted, entry})
        :ok
      end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:setquest, 7393}, base_state())

      assert {:ok, game_state} = reply
      assert %Entry{state: :active, counts: [0]} = game_state.quest_log[7393]
      assert new_state.game_state.quest_log == game_state.quest_log

      assert_received {:send, _ch,
                       {:quest_added, %QuestAdded{quest: %{quest_id: 7393, state: 1}}}}

      assert_received {:upserted, %Entry{state: :active, counts: [0]}}
    end

    test "rejects :already_started and mutates nothing" do
      reject(&QuestPersistence.upsert/2)

      state = base_state(quest_log: %{7393 => %Entry{state: :active, counts: [0]}})
      {reply, new_state} = ScriptEffectHandler.apply_op({:setquest, 7393}, state)

      assert reply == {:error, :already_started}
      assert new_state == state
      refute_received {:send, _ch, {:quest_added, _}}
    end

    test "rejects :unknown_quest for an id absent from quest_db" do
      reject(&QuestPersistence.upsert/2)

      state = base_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:setquest, 99_999}, state)

      assert reply == {:error, :unknown_quest}
      assert new_state == state
    end
  end

  describe "{:erasequest, quest_id}" do
    test "removes the quest, deletes the persisted row, pushes QuestRemoved" do
      test_pid = self()

      expect(QuestPersistence, :delete, fn 1000, 7393 ->
        send(test_pid, :deleted)
        :ok
      end)

      state = base_state(quest_log: %{7393 => %Entry{state: :active, counts: [3]}})
      {reply, new_state} = ScriptEffectHandler.apply_op({:erasequest, 7393}, state)

      assert {:ok, game_state} = reply
      assert game_state.quest_log == %{}
      assert new_state.game_state.quest_log == %{}
      assert_received {:send, _ch, {:quest_removed, %QuestRemoved{quest_id: 7393}}}
      assert_received :deleted
    end

    test "rejects :not_started and mutates nothing" do
      reject(&QuestPersistence.delete/2)

      state = base_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:erasequest, 7393}, state)

      assert reply == {:error, :not_started}
      assert new_state == state
      refute_received {:send, _ch, {:quest_removed, _}}
    end
  end

  describe "{:completequest, quest_id}" do
    test "marks the quest complete keeping counters, upserts, pushes QuestStateChanged" do
      test_pid = self()

      expect(QuestPersistence, :upsert, fn 1000, {7393, entry} ->
        send(test_pid, {:upserted, entry})
        :ok
      end)

      state = base_state(quest_log: %{7393 => %Entry{state: :active, counts: [10]}})
      {reply, new_state} = ScriptEffectHandler.apply_op({:completequest, 7393}, state)

      assert {:ok, game_state} = reply
      assert %Entry{state: :complete, counts: [10]} = game_state.quest_log[7393]
      assert new_state.game_state.quest_log == game_state.quest_log

      assert_received {:send, _ch,
                       {:quest_state_changed, %QuestStateChanged{quest_id: 7393, state: 2}}}

      assert_received {:upserted, %Entry{state: :complete, counts: [10]}}
    end

    test "rejects :not_started for an absent quest, mutating nothing" do
      reject(&QuestPersistence.upsert/2)

      state = base_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:completequest, 7393}, state)

      assert reply == {:error, :not_started}
      assert new_state == state
      refute_received {:send, _ch, {:quest_state_changed, _}}
    end
  end

  describe "{:changequest, old_id, new_id}" do
    test "swaps the quest, deletes the old row, upserts the new row, pushes both deltas" do
      test_pid = self()

      expect(QuestPersistence, :delete, fn 1000, 7393 ->
        send(test_pid, :deleted)
        :ok
      end)

      expect(QuestPersistence, :upsert, fn 1000, {8000, entry} ->
        send(test_pid, {:upserted, entry})
        :ok
      end)

      state = base_state(quest_log: %{7393 => %Entry{state: :active, counts: [4]}})
      {reply, new_state} = ScriptEffectHandler.apply_op({:changequest, 7393, 8000}, state)

      assert {:ok, game_state} = reply
      refute Map.has_key?(game_state.quest_log, 7393)
      assert %Entry{state: :active, counts: []} = game_state.quest_log[8000]
      assert new_state.game_state.quest_log == game_state.quest_log

      assert_received {:send, _ch, {:quest_removed, %QuestRemoved{quest_id: 7393}}}

      assert_received {:send, _ch,
                       {:quest_added, %QuestAdded{quest: %{quest_id: 8000, state: 1}}}}

      assert_received :deleted
      assert_received {:upserted, %Entry{state: :active, counts: []}}
    end

    test "rejects :not_started for an old quest that isn't held, mutating nothing" do
      reject(&QuestPersistence.delete/2)
      reject(&QuestPersistence.upsert/2)

      state = base_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:changequest, 7393, 8000}, state)

      assert reply == {:error, :not_started}
      assert new_state == state
    end
  end

  defp job_change_state do
    character = %Character{
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
      class: 0
    }

    %{connection_pid: self(), game_state: PlayerState.new(character)}
  end

  defp base_state(opts \\ []) do
    %{
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: 1000,
        account_id: 2000,
        zeny: Keyword.get(opts, :zeny, 0),
        vars: Keyword.get(opts, :vars, %{}),
        temp_vars: %{},
        inventory: Keyword.get(opts, :inventory, %{}),
        quest_log: Keyword.get(opts, :quest_log, %{}),
        stats: stats()
      }
    }
  end

  defp stats do
    %Aesir.ZoneServer.Unit.Player.Stats{
      base_stats: %Aesir.ZoneServer.Unit.Stats.BaseStats{
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1
      },
      current_state: %Aesir.ZoneServer.Unit.Stats.CurrentState{hp: 100, sp: 10},
      derived_stats: %Aesir.ZoneServer.Unit.Stats.DerivedStats{
        max_hp: 500,
        max_sp: 200,
        aspd: 150
      },
      progression: %Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression{
        base_level: 10,
        job_level: 3,
        job_id: 0
      },
      modifiers: %Aesir.ZoneServer.Unit.Player.Stats.Modifiers{
        equipment: %{},
        status_effects: %{},
        job_bonuses: %{}
      }
    }
  end

  defp group_grant(item_id) do
    %{
      item_id: item_id,
      amount: 1,
      identify?: false,
      refine: 0,
      grade: 0,
      bound: nil,
      unique_id?: false,
      duration_min: 0,
      named?: false,
      announced?: false,
      drawn: nil
    }
  end

  defp item_definition(id, opts \\ []) do
    %ItemDefinition{
      id: id,
      aegis_name: "Item_#{id}",
      name: "Item #{id}",
      weight: 10,
      type: Keyword.get(opts, :type)
    }
  end
end

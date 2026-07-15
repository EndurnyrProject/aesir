defmodule Aesir.ZoneServer.Script.DslTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ParamChange
  alias Aesir.Net.Viewpoint
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpecialEffect
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  @sp_hp 5
  @sp_sp 7
  @poring_id 1002

  setup :set_mimic_from_context

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(StatusInterpreter)
    Mimic.copy(WarpHandler)
    Mimic.copy(SkillInterpreter)
    Mimic.copy(Coordinator)
    Mimic.copy(Cell)
    Mimic.copy(MapCache)
    Mimic.copy(MapData)
    Mimic.copy(SpecialEffect)
    Mimic.copy(Emote)
    Mimic.copy(ModifierCalculator)
    Mimic.copy(Weight)
    Mimic.copy(Inventory)
    Mimic.copy(ItemManagement)
    Mimic.copy(Broadcast)
    Mimic.copy(MobSupervisor)

    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(StatusInterpreter, :apply_status, fn _, _, _, _ -> :ok end)
    stub(StatusInterpreter, :remove_status, fn _, _, _ -> :ok end)
    stub(ModifierCalculator, :get_all_modifiers, fn :player, _ -> %{} end)

    :ok
  end

  describe "heal/2" do
    test "raises hp by a rolled amount within the range, clamps at max, syncs and persists" do
      test_pid = self()

      expect(CharacterPersistence, :update_stats, fn 1, %{hp: hp}, [async: true] ->
        send(test_pid, {:persisted, hp})
        {:ok, %Character{}}
      end)

      ctx = Dsl.heal(build_ctx(hp: 100), hp: 45..65)

      assert ctx.status == :ok
      assert ctx.game_state.stats.current_state.hp in 145..165
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_hp, value: value}}}
      assert value in 145..165
      assert_received {:persisted, persisted}
      assert persisted in 145..165
    end

    test "clamps the healed hp at max_hp (no overheal)" do
      ctx = Dsl.heal(build_ctx(hp: 480), hp: 100)

      assert ctx.game_state.stats.current_state.hp == 500
    end

    test "heals sp too" do
      ctx = Dsl.heal(build_ctx(sp: 10), sp: 20)

      assert ctx.game_state.stats.current_state.sp == 30
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_sp, value: 30}}}
    end

    test "scales the healed HP delta by received_heal_rate (once)" do
      stub(ModifierCalculator, :get_all_modifiers, fn :player, _ -> %{received_heal_rate: 50} end)

      ctx = Dsl.heal(build_ctx(hp: 100), hp: 100)

      assert ctx.game_state.stats.current_state.hp == 250
    end

    test "received_heal_rate does not scale SP heals" do
      stub(ModifierCalculator, :get_all_modifiers, fn :player, _ -> %{received_heal_rate: 50} end)

      ctx = Dsl.heal(build_ctx(sp: 10), sp: 20)

      assert ctx.game_state.stats.current_state.sp == 30
    end
  end

  describe "percent_heal/2" do
    test "heals a percentage of max_hp" do
      ctx = Dsl.percent_heal(build_ctx(hp: 100), hp: 50)

      assert ctx.game_state.stats.current_state.hp == 350
    end
  end

  describe "sc_start/4" do
    test "applies the status and returns ctx unchanged" do
      test_pid = self()

      expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_blessing, params ->
        send(test_pid, {:applied, params})
        :ok
      end)

      ctx = build_ctx()
      result = Dsl.sc_start(ctx, :sc_blessing, 60_000, 10)

      assert result == ctx
      assert_received {:applied, params}
      assert params[:val1] == 10
      assert params[:duration] == 60_000
    end
  end

  describe "specialeffect2/2" do
    test "plays the area effect on the player and returns ctx unchanged" do
      test_pid = self()

      expect(SpecialEffect, :play, fn {:player, 1}, :heal2, :area ->
        send(test_pid, :played)
        :ok
      end)

      ctx = build_ctx()

      assert Dsl.specialeffect2(ctx, :heal2) == ctx
      assert_received :played
    end

    test "is a no-op on a detached ctx" do
      ctx = %{build_ctx() | game_state: nil}
      assert Dsl.specialeffect2(ctx, :heal2) == ctx
    end

    test "passes a raw numeric effect id straight through" do
      test_pid = self()

      expect(SpecialEffect, :play, fn {:player, 1}, 42, :area ->
        send(test_pid, :played)
        :ok
      end)

      assert Dsl.specialeffect2(build_ctx(), 42) == build_ctx()
      assert_received :played
    end
  end

  describe "specialeffect/2" do
    test "plays the area effect anchored on the running NPC and returns ctx unchanged" do
      test_pid = self()

      expect(SpecialEffect, :play, fn {:npc, 42}, :hit1, :area ->
        send(test_pid, :played)
        :ok
      end)

      ctx = %{build_ctx() | npc_gid: 42}

      assert Dsl.specialeffect(ctx, :hit1) == ctx
      assert_received :played
    end

    test "is a no-op when npc_gid is nil" do
      ctx = build_ctx()
      assert ctx.npc_gid == nil
      assert Dsl.specialeffect(ctx, :hit1) == ctx
    end

    test "short-circuits on an already-halted ctx" do
      ctx = Ctx.halt(%{build_ctx() | npc_gid: 42}, :boom)
      assert Dsl.specialeffect(ctx, :hit1) == ctx
    end
  end

  describe "viewpoint/6" do
    test "sends a Viewpoint marker to the invoking player, anchored on the NPC" do
      test_pid = self()

      expect(Broadcast, :to_player, fn 1, %Viewpoint{} = packet ->
        send(test_pid, {:viewpoint, packet})
        :ok
      end)

      ctx = %{build_ctx() | npc_gid: 42}

      assert Dsl.viewpoint(ctx, 1, 85, 131, 2, 65_280) == ctx

      assert_received {:viewpoint,
                       %Viewpoint{npc_id: 42, type: 1, x: 85, y: 131, id: 2, color: 65_280}}
    end

    test "defaults npc_id to 0 when the script has no npc_gid" do
      test_pid = self()

      expect(Broadcast, :to_player, fn 1, packet ->
        send(test_pid, {:viewpoint, packet})
        :ok
      end)

      assert %Ctx{} = Dsl.viewpoint(build_ctx(), 1, 10, 20, 1, 0)
      assert_received {:viewpoint, %Viewpoint{npc_id: 0}}
    end

    test "is a no-op on a detached ctx (no player to send to)" do
      reject(&Broadcast.to_player/2)
      ctx = %{build_ctx() | char_id: nil}
      assert Dsl.viewpoint(ctx, 1, 10, 20, 1, 0) == ctx
    end

    test "short-circuits on an already-halted ctx" do
      reject(&Broadcast.to_player/2)
      ctx = Ctx.halt(build_ctx(), :boom)
      assert Dsl.viewpoint(ctx, 1, 10, 20, 1, 0) == ctx
    end
  end

  describe "consumeitem/2" do
    # Red Potion (501) carries `on_use: "heal(ctx, hp: 45..65)"`, so consuming
    # it runs that heal through the same compiled item script the use path runs.
    test "runs the item's use script, applying its effect to the player" do
      result = Dsl.consumeitem(build_ctx(hp: 100), 501)

      assert result.status == :ok
      assert result.game_state.stats.current_state.hp in 145..165
    end

    test "an item with no use script is a no-op returning the ctx unchanged" do
      ctx = build_ctx()
      assert Dsl.consumeitem(ctx, 0) == ctx
    end

    test "short-circuits on an already-halted ctx without running any script" do
      ctx = Ctx.halt(build_ctx(), :boom)
      assert Dsl.consumeitem(ctx, 501) == ctx
    end
  end

  describe "killmonster/3" do
    test "kills mobs on the map by event label" do
      test_pid = self()

      expect(MobSupervisor, :kill_by_event, fn "moro_vol", "#f_boss_c::OnMobDead0" ->
        send(test_pid, :killed)
        :ok
      end)

      ctx = build_ctx()
      assert Dsl.killmonster(ctx, "moro_vol", "#f_boss_c::OnMobDead0") == ctx
      assert_received :killed
    end

    test "the \"All\" label kills every script-summoned mob" do
      test_pid = self()

      expect(MobSupervisor, :kill_by_event, fn "prontera", :all ->
        send(test_pid, :killed_all)
        :ok
      end)

      ctx = build_ctx()
      assert Dsl.killmonster(ctx, "prontera", "All") == ctx
      assert_received :killed_all
    end

    test "short-circuits on an already-halted ctx" do
      reject(&MobSupervisor.kill_by_event/2)
      ctx = Ctx.halt(build_ctx(), :boom)
      assert Dsl.killmonster(ctx, "prontera", "All") == ctx
    end
  end

  describe "getnpcid/1" do
    test "returns the running NPC's gid" do
      ctx = %{build_ctx() | npc_gid: 7777}
      assert Dsl.getnpcid(ctx) == 7777
    end

    test "returns 0 when there is no npc_gid" do
      assert Dsl.getnpcid(build_ctx()) == 0
    end
  end

  describe "playerattached/1" do
    test "returns the attached player's account id" do
      assert Dsl.playerattached(build_ctx()) == 100
    end

    test "returns 0 on a detached ctx" do
      ctx = %{build_ctx() | account_id: nil}
      assert Dsl.playerattached(ctx) == 0
    end
  end

  describe "checkweight/2" do
    setup do
      stub(ItemManagement, :get_item_by_id, fn _ -> {:error, :item_not_found} end)
      :ok
    end

    test "returns 1 when the items fit under weight and there is a free slot" do
      stub(Weight, :would_exceed?, fn _inv, _stats, _added -> false end)

      assert Dsl.checkweight(build_ctx(), [{501, 5}]) == 1
    end

    test "returns 0 when the combined weight would exceed the limit" do
      stub(Weight, :would_exceed?, fn _inv, _stats, _added -> true end)

      assert Dsl.checkweight(build_ctx(), [{501, 5}]) == 0
    end

    test "returns 0 when there are not enough free inventory slots" do
      stub(Weight, :would_exceed?, fn _inv, _stats, _added -> false end)
      stub(Inventory, :capacity, fn -> 0 end)

      assert Dsl.checkweight(build_ctx(), [{501, 1}]) == 0
    end
  end

  describe "emotion/2" do
    test "shows the emote over the npc and returns ctx unchanged" do
      test_pid = self()

      expect(Emote, :show, fn {:npc, 42}, :money ->
        send(test_pid, :shown)
        :ok
      end)

      ctx = %{build_ctx() | npc_gid: 42}

      assert Dsl.emotion(ctx, :money) == ctx
      assert_received :shown
    end

    test "is a no-op when npc_gid is nil" do
      ctx = build_ctx()
      assert ctx.npc_gid == nil
      assert Dsl.emotion(ctx, :money) == ctx
    end

    test "is a no-op on an errored ctx" do
      ctx = %{build_ctx() | npc_gid: 42, status: {:error, :boom}}
      assert Dsl.emotion(ctx, :money) == ctx
    end
  end

  describe "sc_end/2" do
    test "removes the status and returns ctx unchanged" do
      test_pid = self()

      expect(StatusInterpreter, :remove_status, fn :player, 1, :sc_poison ->
        send(test_pid, :removed)
        :ok
      end)

      ctx = build_ctx()

      assert Dsl.sc_end(ctx, :sc_poison) == ctx
      assert_received :removed
    end
  end

  describe "cure/2" do
    test "removes the status and returns ctx unchanged" do
      test_pid = self()

      expect(StatusInterpreter, :remove_status, fn :player, 1, :sc_poison ->
        send(test_pid, :removed)
        :ok
      end)

      ctx = build_ctx()

      assert Dsl.cure(ctx, :sc_poison) == ctx
      assert_received :removed
    end
  end

  describe "warp/2" do
    test "relocates the player on success" do
      relocated = %{build_game_state() | map_name: "prontera", x: 150, y: 100}

      expect(WarpHandler, :warp, fn _session, "prontera", 150, 100 ->
        {:ok, %{game_state: relocated}}
      end)

      ctx = Dsl.warp(build_ctx(), {"prontera", 150, 100})

      assert ctx.status == :ok
      assert Dsl.position(ctx) == {150, 100, "prontera"}
    end

    test "halts and leaves position unchanged when the warp fails" do
      stub(WarpHandler, :warp, fn _session, _map, _x, _y -> {:error, :map_not_found} end)

      ctx = build_ctx()
      result = Dsl.warp(ctx, {"prontera", 150, 100})

      assert result.status == {:error, :map_not_found}
      assert Dsl.position(result) == Dsl.position(ctx)
    end
  end

  describe "warp/2 :random" do
    test "relocates the player to a random walkable cell on the current map" do
      relocated = %{build_game_state() | map_name: "prontera", x: 33, y: 44}

      expect(Cell, :random_traversable, fn "prontera" -> {:ok, {33, 44}} end)

      expect(WarpHandler, :warp, fn _session, "prontera", 33, 44 ->
        {:ok, %{game_state: relocated}}
      end)

      ctx = Dsl.warp(build_ctx(), :random)

      assert ctx.status == :ok
      assert Dsl.position(ctx) == {33, 44, "prontera"}
    end

    test "halts when no walkable cell can be resolved" do
      stub(Cell, :random_traversable, fn _map -> {:error, :not_found} end)

      result = Dsl.warp(build_ctx(), :random)

      assert result.status == {:error, :not_found}
    end

    test "halts immediately when already in an error state" do
      ctx = Ctx.halt(build_ctx(), :boom)

      assert Dsl.warp(ctx, :random) == ctx
    end
  end

  describe "warp/2 :save_point" do
    test "relocates the player to their save point" do
      game_state = %{build_game_state() | save_map: "izlude", save_x: 90, save_y: 105}
      relocated = %{game_state | map_name: "izlude", x: 90, y: 105}

      expect(WarpHandler, :warp, fn _session, "izlude", 90, 105 ->
        {:ok, %{game_state: relocated}}
      end)

      ctx = Dsl.warp(%{build_ctx() | game_state: game_state}, :save_point)

      assert ctx.status == :ok
      assert Dsl.position(ctx) == {90, 105, "izlude"}
    end

    test "halts and leaves position unchanged when the warp fails" do
      stub(WarpHandler, :warp, fn _session, _map, _x, _y -> {:error, :map_not_found} end)

      game_state = %{build_game_state() | save_map: "izlude", save_x: 90, save_y: 105}
      ctx = %{build_ctx() | game_state: game_state}

      result = Dsl.warp(ctx, :save_point)

      assert result.status == {:error, :map_not_found}
      assert Dsl.position(result) == Dsl.position(ctx)
    end

    test "halts immediately when already in an error state" do
      ctx = Ctx.halt(build_ctx(), :boom)

      assert Dsl.warp(ctx, :save_point) == ctx
    end
  end

  describe "itemskill/3" do
    test "casts a skill by id and folds the returned game_state" do
      cast_state = %{build_game_state() | action_state: :casting}

      expect(SkillInterpreter, :cast, fn _gs, 14, 5, :self -> {:ok, cast_state} end)

      ctx = Dsl.itemskill(build_ctx(), 14, level: 5)

      assert ctx.status == :ok
      assert ctx.game_state.action_state == :casting
    end

    test "halts on a cast error" do
      stub(SkillInterpreter, :cast, fn _gs, _id, _lvl, _target -> {:error, :not_enough_sp} end)

      ctx = Dsl.itemskill(build_ctx(), 14, [])

      assert ctx.status == {:error, :not_enough_sp}
    end
  end

  describe "reads" do
    test "class/1 returns the job atom" do
      assert Dsl.class(build_ctx()) == :novice
    end

    test "hp/1, sp/1, max_hp/1 return current values" do
      ctx = build_ctx(hp: 123, sp: 45)

      assert Dsl.hp(ctx) == 123
      assert Dsl.sp(ctx) == 45
      assert Dsl.max_hp(ctx) == 500
    end

    test "base_level/1 and job_level/1 read progression" do
      ctx = build_ctx()

      assert Dsl.base_level(ctx) == 10
      assert Dsl.job_level(ctx) == 3
    end

    test "sex/1 returns rAthena's Sex: 1 male, 0 female" do
      assert Dsl.sex(build_ctx(sex: "M")) == 1
      assert Dsl.sex(build_ctx(sex: "F")) == 0
    end

    test "position/1 returns {x, y, map_name}" do
      assert Dsl.position(build_ctx()) == {50, 50, "prontera"}
    end

    test "is_equipped/2 returns 1 only for an equipped item id" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: 1201, equip: 2}})

      assert Dsl.is_equipped(ctx, 1201) == 1
      assert Dsl.is_equipped(ctx, 9999) == 0
    end

    test "is_equipped/2 returns 0 for a carried-but-not-equipped item" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: 1201, equip: 0}})

      assert Dsl.is_equipped(ctx, 1201) == 0
    end

    test "getequipid/2 returns the item id worn in the given EQI slot" do
      ctx =
        build_ctx(
          inventory: %{
            0 => %InventoryItem{nameid: 2301, equip: 0x10},
            1 => %InventoryItem{nameid: 5170, equip: 0x100},
            2 => %InventoryItem{nameid: 1201, equip: 0}
          }
        )

      assert Dsl.getequipid(ctx, 7) == 2301
      assert Dsl.getequipid(ctx, 6) == 5170
    end

    test "getequipid/2 returns -1 for an empty slot or an unknown slot index" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: 2301, equip: 0x10}})

      assert Dsl.getequipid(ctx, 6) == -1
      assert Dsl.getequipid(ctx, 99) == -1
    end

    test "num_suffix/2 appends the English ordinal suffix (matching rAthena)" do
      ctx = build_ctx()

      assert Dsl.num_suffix(ctx, 1) == "1st"
      assert Dsl.num_suffix(ctx, 2) == "2nd"
      assert Dsl.num_suffix(ctx, 3) == "3rd"
      assert Dsl.num_suffix(ctx, 4) == "4th"
      assert Dsl.num_suffix(ctx, 11) == "11th"
      assert Dsl.num_suffix(ctx, 12) == "12th"
      assert Dsl.num_suffix(ctx, 13) == "13th"
      assert Dsl.num_suffix(ctx, 21) == "21st"
      assert Dsl.num_suffix(ctx, 22) == "22nd"
      assert Dsl.num_suffix(ctx, 23) == "23rd"
    end

    test "insert_comma/2 groups digits in threes (matching rAthena F_InsertComma)" do
      ctx = build_ctx()

      assert Dsl.insert_comma(ctx, 1) == "1"
      assert Dsl.insert_comma(ctx, 100) == "100"
      assert Dsl.insert_comma(ctx, 1000) == "1,000"
      assert Dsl.insert_comma(ctx, 10_000) == "10,000"
      assert Dsl.insert_comma(ctx, 1_000_000) == "1,000,000"
      assert Dsl.insert_comma(ctx, 1_234_567) == "1,234,567"
      assert Dsl.insert_comma(ctx, -1000) == "-1,000"
    end
  end

  describe "summon_mob/2" do
    test "summons the requested mob on the player's map at the given coords" do
      test_pid = self()

      expect(Coordinator, :summon_mob, fn map, mob_id, x, y, _opts ->
        send(test_pid, {:summoned, map, mob_id, {x, y}})
        {:ok, 12_345}
      end)

      ctx = Dsl.summon_mob(build_ctx(), mob_id: @poring_id, at: {150, 100})

      assert ctx.status == :ok
      assert_received {:summoned, "prontera", @poring_id, {150, 100}}
    end

    test "defaults the spawn coords to the player's position" do
      test_pid = self()

      expect(Coordinator, :summon_mob, fn _map, _mob_id, x, y, _opts ->
        send(test_pid, {:summoned_at, {x, y}})
        {:ok, 12_345}
      end)

      Dsl.summon_mob(build_ctx(), mob_id: @poring_id)

      assert_received {:summoned_at, {50, 50}}
    end

    test ":map overrides the player's map and defaults :at to :random" do
      test_pid = self()

      expect(Coordinator, :summon_mob, fn map, _mob_id, x, y, _opts ->
        send(test_pid, {:summoned, map, {x, y}})
        {:ok, 12_345}
      end)

      ctx = Dsl.summon_mob(build_ctx(), mob_id: @poring_id, map: "gef_dun00")

      assert ctx.status == :ok
      assert_received {:summoned, "gef_dun00", {0, 0}}
    end

    test ":amount summons the mob once per count" do
      test_pid = self()

      expect(Coordinator, :summon_mob, 3, fn _map, mob_id, _x, _y, _opts ->
        send(test_pid, {:summoned, mob_id})
        {:ok, 12_345}
      end)

      ctx = Dsl.summon_mob(build_ctx(), mob_id: @poring_id, at: {10, 10}, amount: 3)

      assert ctx.status == :ok
      assert_received {:summoned, @poring_id}
      assert_received {:summoned, @poring_id}
      assert_received {:summoned, @poring_id}
    end

    test "at: :random passes the random-cell sentinel coords" do
      test_pid = self()

      expect(Coordinator, :summon_mob, fn _map, _mob_id, x, y, _opts ->
        send(test_pid, {:summoned_at, {x, y}})
        {:ok, 12_345}
      end)

      ctx = Dsl.summon_mob(build_ctx(), mob_id: @poring_id, at: :random)

      assert ctx.status == :ok
      assert_received {:summoned_at, {0, 0}}
    end

    test "halts :map_not_found when the target map has no coordinator" do
      stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts ->
        {:error, :map_not_found}
      end)

      ctx = Dsl.summon_mob(build_ctx(), mob_id: @poring_id, map: "no_such_map")

      assert ctx.status == {:error, :map_not_found}
    end

    test "halts on an unknown mob id without summoning" do
      stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts ->
        flunk("summon_mob should not be called for an unknown mob")
      end)

      ctx = Dsl.summon_mob(build_ctx(), mob_id: 9_999_999, at: {10, 10})

      assert ctx.status == {:error, :mob_not_found}
    end

    test "halts when the spawn fails" do
      stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts ->
        {:error, :max_children}
      end)

      ctx = Dsl.summon_mob(build_ctx(), mob_id: @poring_id, at: {10, 10})

      assert ctx.status == {:error, :max_children}
    end

    test "returns a halted ctx unchanged without summoning" do
      stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts ->
        flunk("summon_mob should not be called on a halted ctx")
      end)

      ctx = Ctx.halt(build_ctx(), :already_dead)

      assert Dsl.summon_mob(ctx, mob_id: @poring_id, at: {10, 10}) == ctx
    end

    test "threads a well-formed :event ref into the coordinator opts" do
      test_pid = self()

      expect(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, opts ->
        send(test_pid, {:summon_opts, opts})
        {:ok, 12_345}
      end)

      ctx = Dsl.summon_mob(build_ctx(), mob_id: @poring_id, at: {10, 10}, event: "Guard::OnDead")

      assert ctx.status == :ok
      assert_received {:summon_opts, opts}
      assert Keyword.get(opts, :event) == "Guard::OnDead"
    end

    test "a malformed :event ref logs a warning and spawns without it" do
      test_pid = self()

      expect(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, opts ->
        send(test_pid, {:summon_opts, opts})
        {:ok, 12_345}
      end)

      log =
        capture_log(fn ->
          ctx =
            Dsl.summon_mob(build_ctx(), mob_id: @poring_id, at: {10, 10}, event: "NoSeparator")

          assert ctx.status == :ok
        end)

      assert log =~ "malformed event ref"
      assert_received {:summon_opts, opts}
      refute Keyword.has_key?(opts, :event)
    end
  end

  describe "summon_random_mob/2" do
    test "summons a valid catalog mob at the player's position" do
      test_pid = self()
      valid_ids = MobManagement.get_all_mobs() |> MapSet.new(& &1.id)

      expect(Coordinator, :summon_mob, fn map, mob_id, x, y, _opts ->
        send(test_pid, {:summoned, map, mob_id, {x, y}})
        {:ok, 12_345}
      end)

      ctx = build_ctx()
      {x, y, _map} = Dsl.position(ctx)
      result = Dsl.summon_random_mob(ctx, at: {x, y})

      assert result.status == :ok
      assert_received {:summoned, "prontera", mob_id, {50, 50}}
      assert MapSet.member?(valid_ids, mob_id)
    end

    test "halts with :no_mobs when the catalog is empty" do
      Mimic.copy(MobManagement)
      stub(MobManagement, :get_all_mobs, fn -> [] end)

      stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts ->
        flunk("summon_mob should not be called when the catalog is empty")
      end)

      ctx = Dsl.summon_random_mob(build_ctx(), at: {50, 50})

      assert ctx.status == {:error, :no_mobs}
    end
  end

  describe "short-circuit" do
    test "a mutation on a halted ctx returns it unchanged" do
      ctx = Ctx.halt(build_ctx(), :already_dead)

      assert Dsl.heal(ctx, hp: 100) == ctx
      assert Dsl.warp(ctx, {"prontera", 1, 1}) == ctx
      assert Dsl.set_local(ctx, :x, 1) == ctx
    end
  end

  describe "todo/3" do
    test "raises NotImplementedError naming the buildin" do
      assert_raise Aesir.ZoneServer.Script.NotImplementedError,
                   ~r/getpartymember/,
                   fn -> Dsl.todo(build_ctx(), :getpartymember, [0]) end
    end

    test "Todo.const!/1 raises naming the constant" do
      assert_raise Aesir.ZoneServer.Script.NotImplementedError,
                   ~r/SOME_CONST/,
                   fn -> Aesir.ZoneServer.Script.Todo.const!(:SOME_CONST) end
    end
  end

  describe "get_temp_var/3" do
    test "reads a session temp var from the snapshot, defaulting to 0" do
      ctx = build_ctx()
      gs = %{ctx.game_state | temp_vars: %{"quest_step" => 3}}

      assert Dsl.get_temp_var(%{ctx | game_state: gs}, :quest_step) == 3
      assert Dsl.get_temp_var(ctx, :missing) == 0
    end
  end

  describe "set_local/3 and get_local/3" do
    test "round-trips a value on the ctx" do
      ctx = Dsl.set_local(build_ctx(), :price, 500)

      assert Dsl.get_local(ctx, :price) == 500
    end

    test "defaults an unset var to 0, or to the given default" do
      ctx = build_ctx()

      assert Dsl.get_local(ctx, :missing) == 0
      assert Dsl.get_local(ctx, :missing, "") == ""
    end
  end

  describe "job-change reads" do
    test "can_change_job?/1 requires learned NV_BASIC at level 9" do
      {:ok, %{id: nv_basic_id}} = Catalog.by_name(:nv_basic)

      refute Dsl.can_change_job?(build_ctx(learned_skills: %{nv_basic_id => 8}))
      assert Dsl.can_change_job?(build_ctx(learned_skills: %{nv_basic_id => 9}))
      refute Dsl.can_change_job?(build_ctx(learned_skills: %{}))
    end

    test "getskilllv/2 reads the learned level by id or catalog name, 0 when unlearned" do
      {:ok, %{id: nv_basic_id}} = Catalog.by_name(:nv_basic)
      ctx = build_ctx(learned_skills: %{nv_basic_id => 5})

      assert Dsl.getskilllv(ctx, nv_basic_id) == 5
      assert Dsl.getskilllv(ctx, :nv_basic) == 5
      assert Dsl.getskilllv(ctx, 9999) == 0
      assert Dsl.getskilllv(ctx, :unknown_skill_name) == 0
    end

    test "char_name/2 returns the character name for type 0 and map for type 3" do
      ctx = build_ctx(character_name: "Bob")

      assert Dsl.char_name(ctx, 0) == "Bob"
      assert Dsl.char_name(ctx, 3) == "prontera"
      assert Dsl.char_name(ctx, 1) == ""
    end

    test "job_name/2 humanizes a class atom and resolves a job id" do
      ctx = build_ctx(job_id: 6)

      assert Dsl.job_name(ctx, :thief) == "Thief"
      assert Dsl.job_name(ctx, :super_novice) == "Super Novice"
      assert Dsl.job_name(ctx, 6) == "Thief"
    end
  end

  defp build_ctx(opts \\ []) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      game_state: build_game_state(opts),
      source: {:item, 501}
    }
  end

  defp build_game_state(opts \\ []) do
    stats = %Stats{
      current_state: %CurrentState{
        hp: Keyword.get(opts, :hp, 100),
        sp: Keyword.get(opts, :sp, 10)
      },
      derived_stats: %DerivedStats{max_hp: 500, max_sp: 200, aspd: 150},
      progression: %PlayerProgression{
        base_level: 10,
        job_level: 3,
        job_id: Keyword.get(opts, :job_id, 0),
        learned_skills: Keyword.get(opts, :learned_skills, %{})
      }
    }

    %PlayerState{
      character_id: 1,
      account_id: 100,
      character_name: Keyword.get(opts, :character_name, "Alice"),
      sex: Keyword.get(opts, :sex, "M"),
      x: 50,
      y: 50,
      map_name: "prontera",
      stats: stats,
      inventory: Keyword.get(opts, :inventory, %{})
    }
  end
end

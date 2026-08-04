defmodule Aesir.ZoneServer.Integration.HomunculusLifSkillsTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.ParamChange
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Homunculus.Stats
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifAvoid
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifHeal
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @moduletag :integration
  @map "prontera"
  @red_slim_potion 545

  setup :verify_on_exit!
  setup {Aesir.MimicMode, :global}

  setup do
    Mimic.copy(Persistence)
    :ok
  end

  test "Healing Touch formula preserves exact integer order at ranks one, three, and five" do
    for {rank, level, int, brain, matk, expected} <- [
          {1, 1, 3, 0, 10, 10},
          {3, 20, 5, 2, 40, 86},
          {5, 99, 46, 5, 100, 578}
        ] do
      caster = formula_lif(level, int, brain, matk)

      assert {:local_effects, ^caster,
              [
                {:owner_item_cost, @red_slim_potion, 1},
                {:player, {:apply_heal, ^expected, {:homunculus, 700}}}
              ]} = HlifHeal.cast(caster, :self, rank, HlifHeal.definition())
    end
  end

  test "Healing Touch atomically commits one potion, SP, cooldown, and owner-only healing" do
    session = start_lif(potions: 2, learned_skills: %{"8001" => 3, "8003" => 2})

    :sys.replace_state(session.pid, fn state ->
      homunculus = %{
        state.homunculus
        | level: 20,
          int: 5,
          combat_stats: %{state.homunculus.combat_stats | matk_min: 40, matk_max: 40}
      }

      %{state | homunculus: homunculus}
    end)

    before = PlayerSession.get_state(session.pid)
    clear_packet_inbox()
    assert {:ok, after_state} = direct_cast(session.pid, 8_001, 3)

    assert after_state.game_state.stats.current_state.hp >
             before.game_state.stats.current_state.hp

    assert after_state.homunculus.hp == before.homunculus.hp
    assert after_state.homunculus.sp == before.homunculus.sp - 19
    assert Inventory.held_amount(after_state.game_state.inventory, @red_slim_potion) == 1
    assert after_state.homunculus.cooldowns[8_001] > System.monotonic_time(:millisecond)
    assert is_reference(after_state.homunculus_runtime.cooldown_timer_ref)

    row = Persistence.load_for_character(after_state.game_state.character_id)
    assert row.sp == after_state.homunculus.sp
    assert row.cooldowns["8001"] > 19_000
    assert row.active_remaining_ms > 0

    assert InventoryPersistence.load_inventory(row.character_id) |> hd() |> Map.fetch!(:amount) ==
             1

    assert_packet_sent_with(ItemRemoved, fn packet -> assert packet.amount == 1 end)
    refute_packet_sent(ItemUseResult)
  end

  test "missing potion leaves healing, SP, cooldown, inventory, and packets untouched" do
    session = start_lif(potions: 0, learned_skills: %{"8001" => 1})
    before = PlayerSession.get_state(session.pid)
    clear_packet_inbox()

    assert {:error, :missing_item, ^before} = direct_cast(session.pid, 8_001, 1)
    assert PlayerSession.get_state(session.pid) == before

    assert Persistence.load_for_character(before.game_state.character_id).sp ==
             before.homunculus.sp

    refute_packet_sent(ItemRemoved)
  end

  test "Healing Touch rejects a missing owner without consuming resources or notifying" do
    session = start_lif(potions: 1, learned_skills: %{"8001" => 1})
    before = PlayerSession.get_state(session.pid)
    UnitRegistry.unregister_unit(:player, before.game_state.character_id)
    clear_packet_inbox()

    assert {:error, :owner_not_found, ^before} = direct_cast(session.pid, 8_001, 1)
    assert_healing_touch_unchanged(session, before)
    refute_packet_sent(ItemRemoved)
    refute_packet_sent(ParamChange)
  end

  test "Healing Touch rejects a dead owner without consuming resources or notifying" do
    session = start_lif(potions: 1, learned_skills: %{"8001" => 1})
    owner = PlayerSession.get_state(session.pid).game_state

    dead_stats = %{owner.stats | current_state: %{owner.stats.current_state | hp: 0}}
    dead_owner = %{owner | action_state: :dead, stats: dead_stats}

    :sys.replace_state(session.pid, &%{&1 | game_state: dead_owner})
    :ok = UnitRegistry.update_unit_state(:player, dead_owner.character_id, dead_owner)
    before = PlayerSession.get_state(session.pid)
    clear_packet_inbox()

    assert {:error, :owner_dead, ^before} = direct_cast(session.pid, 8_001, 1)
    assert_healing_touch_unchanged(session, before)
    refute_packet_sent(ItemRemoved)
    refute_packet_sent(ParamChange)
  end

  test "persistence failure rolls back the staged potion cast before healing or notification" do
    session = start_lif(potions: 1, learned_skills: %{"8001" => 1})
    before = PlayerSession.get_state(session.pid)

    Mimic.expect(Persistence, :transition_with_item, fn _, _, _, _, _ ->
      {:error, {:homunculus, :forced}}
    end)

    clear_packet_inbox()

    assert {:error, {:persistence, {:homunculus, :forced}}, ^before} =
             direct_cast(session.pid, 8_001, 1)

    assert PlayerSession.get_state(session.pid) == before
    assert Inventory.held_amount(before.game_state.inventory, @red_slim_potion) == 1
    refute_packet_sent(ItemRemoved)
  end

  test "timed completion settlement failure clears casting and restores pre-settlement state" do
    session = start_lif(potions: 1, learned_skills: %{"8001" => 1})
    token = make_ref()
    timer_ref = make_ref()

    casting =
      :sys.replace_state(session.pid, fn state ->
        cast = %{token: token, skill_id: 8_001, level: 1, target: :self}
        homunculus = %{state.homunculus | action_state: :casting, casting: cast}
        runtime = %{state.homunculus_runtime | cast_timer_ref: timer_ref}
        %{state | homunculus: homunculus, homunculus_runtime: runtime}
      end)

    Mimic.expect(Persistence, :transition_with_item, fn _, _, _, _, _ ->
      {:error, {:homunculus, :forced}}
    end)

    clear_packet_inbox()
    assert {:noreply, completed} = direct_complete(session.pid, timer_ref, token)
    assert completed.homunculus.action_state == :idle
    assert completed.homunculus.casting == nil
    assert completed.homunculus_runtime.cast_timer_ref == nil

    assert completed.homunculus_runtime.cooldown_timer_ref ==
             casting.homunculus_runtime.cooldown_timer_ref

    assert completed.homunculus.sp == casting.homunculus.sp
    assert completed.homunculus.cooldowns == casting.homunculus.cooldowns
    assert completed.game_state.inventory == casting.game_state.inventory

    assert completed.game_state.stats.current_state.hp ==
             casting.game_state.stats.current_state.hp

    refute_packet_sent(ItemRemoved)
  end

  test "Urgent Escape writes only owner and Lif with exact ranked values and duration" do
    session = start_lif(learned_skills: %{"8002" => 5})
    state = PlayerSession.get_state(session.pid)
    foreign_id = state.game_state.character_id + 10_000

    assert {:ok, _cast} = direct_cast(session.pid, 8_002, 5)

    owner = StatusStorage.get_status(:player, state.game_state.character_id, :sc_avoid)
    lif = StatusStorage.get_status(:homunculus, state.homunculus.world_gid, :sc_avoid)
    assert {owner.val1, owner.val2} == {5, 50}
    assert {lif.val1, lif.val2} == {5, 200}
    assert_in_delta owner.expires_at - System.monotonic_time(:millisecond), 20_000, 200
    assert_in_delta lif.expires_at - System.monotonic_time(:millisecond), 20_000, 200
    assert eventually(fn -> PlayerSession.get_state(session.pid).game_state.walk_speed == 75 end)
    assert [^owner] = StatusStorage.get_unit_statuses(:player, state.game_state.character_id)
    assert [^lif] = StatusStorage.get_unit_statuses(:homunculus, state.homunculus.world_gid)
    assert [] = StatusStorage.get_unit_statuses(:player, foreign_id)
  end

  test "Urgent Escape fails on a missing owner before touching Lif" do
    session = start_lif(learned_skills: %{"8002" => 1})
    before = PlayerSession.get_state(session.pid)
    UnitRegistry.unregister_unit(:player, before.game_state.character_id)

    assert_raise RuntimeError, ~r/non-existent player/, fn ->
      HlifAvoid.cast(before.homunculus, :self, 1, HlifAvoid.definition())
    end

    refute StatusStorage.has_status?(:homunculus, before.homunculus.world_gid, :sc_avoid)
    assert PlayerSession.get_state(session.pid).homunculus.sp == before.homunculus.sp
  end

  test "Brain remains passive while its stats and Healing Touch bonus are derived only for Lif" do
    lif = formula_lif(20, 10, 5, 10)
    recomputed = Stats.recompute(lif)
    assert recomputed.max_sp == 525
    assert recomputed.combat_stats.sp_regen_rate == 15
    assert Stats.healing_touch_bonus_rate(recomputed) == 10

    assert {:error, :passive_skill} =
             Interpreter.begin_homunculus_cast(recomputed, 8_003, 1, :self)

    non_lif = %{recomputed | class_id: 6_002}
    assert Stats.healing_touch_bonus_rate(non_lif) == 0
  end

  test "Mental Change enforces evolved form and applies exact ranked status and cooldown" do
    original = formula_lif(20, 10, 0, 10)
    original = %{original | learned_skills: %{8_004 => 3}, sp: 300}

    assert {:error, :skill_not_learned} =
             Interpreter.begin_homunculus_cast(original, 8_004, 1, :self)

    session = start_lif(class_id: 6_009, sp: 300, learned_skills: %{"8004" => 3})
    state = PlayerSession.get_state(session.pid)
    assert {:ok, cast} = direct_cast(session.pid, 8_004, 3)

    status = StatusStorage.get_status(:homunculus, state.homunculus.world_gid, :sc_change)
    assert {status.val1, status.val2, status.val3} == {3, 90, 60}
    assert_in_delta status.expires_at - System.monotonic_time(:millisecond), 300_000, 200
    assert cast.homunculus.sp == state.homunculus.sp - 100

    assert_in_delta cast.homunculus.cooldowns[8_004] - System.monotonic_time(:millisecond),
                    1_200_000,
                    200

    assert :ok =
             StatusInterpreter.remove_status(:homunculus, state.homunculus.world_gid, :sc_change)

    Process.sleep(20)
    assert PlayerSession.get_state(session.pid).homunculus.hp == cast.homunculus.hp
    assert PlayerSession.get_state(session.pid).homunculus.sp == cast.homunculus.sp

    assert :ok =
             StatusInterpreter.apply_status(:homunculus, state.homunculus.world_gid, :sc_change,
               val1: 3,
               val2: 90,
               val3: 60,
               duration: 60_000
             )

    :ok =
      StatusStorage.update_status(
        :homunculus,
        state.homunculus.world_gid,
        :sc_change,
        &%{&1 | expires_at: System.monotonic_time(:millisecond) - 1}
      )

    assert {:noreply, _tick_state} =
             StatusTickManager.handle_info(:tick, %StatusTickManager.State{})

    assert_eventually(fn ->
      expired = PlayerSession.get_state(session.pid)
      expired.homunculus.hp == 10 and expired.homunculus.sp == 10
    end)

    assert %{hp: 10, sp: 10} = Persistence.load_for_character(state.game_state.character_id)
  end

  defp assert_healing_touch_unchanged(session, before) do
    assert PlayerSession.get_state(session.pid) == before
    assert Inventory.held_amount(before.game_state.inventory, @red_slim_potion) == 1
    assert before.homunculus.cooldowns == %{}

    persisted = Persistence.load_for_character(before.game_state.character_id)
    assert persisted.sp == before.homunculus.sp
    assert persisted.cooldowns == %{}

    assert InventoryPersistence.load_inventory(before.game_state.character_id)
           |> hd()
           |> Map.fetch!(:amount) == 1
  end

  defp direct_cast(pid, skill_id, level) do
    caller = self()

    :sys.replace_state(pid, fn state ->
      result = CastingHandler.begin(state, skill_id, level, :self)
      send(caller, {:direct_cast, result})

      case result do
        {:ok, updated} -> updated
        {:error, _reason, original} -> original
        {:stop, _reason, stopped} -> stopped
      end
    end)

    assert_receive {:direct_cast, result}
    result
  end

  defp direct_complete(pid, timer_ref, token) do
    caller = self()

    :sys.replace_state(pid, fn state ->
      result = CastingHandler.complete(timer_ref, token, state)
      send(caller, {:direct_complete, result})

      case result do
        {:noreply, updated} -> updated
        {:stop, _reason, stopped} -> stopped
      end
    end)

    assert_receive {:direct_complete, result}
    result
  end

  defp start_lif(opts) do
    character = insert_character()
    potions = Keyword.get(opts, :potions, 0)

    if potions > 0 do
      {:ok, _item} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: @red_slim_potion,
          amount: potions,
          identify: 1
        })
    end

    insert_homunculus(character.id, opts)
    character = character |> Repo.preload(:homunculus)
    session = start_player_session(character: character, map_name: @map, position: {150, 150})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp insert_character do
    suffix = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "lifskills#{suffix}",
        user_pass: "password",
        email: "lifskills#{suffix}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "LifSkills#{suffix}",
        class: 18,
        base_level: 50,
        job_level: 50,
        hp: 1_000,
        max_hp: 5_000,
        sp: 500,
        max_sp: 500,
        last_map: @map,
        last_x: 150,
        last_y: 150
      })
      |> Repo.insert()

    character
  end

  defp insert_homunculus(character_id, opts) do
    attrs = %{
      character_id: character_id,
      class_id: Keyword.get(opts, :class_id, 6_001),
      name: "Lif",
      lifecycle: "active",
      level: 20,
      hp: 100,
      max_hp: 500,
      sp: Keyword.get(opts, :sp, 300),
      max_sp: 300,
      int: 10,
      dex: 10,
      active_remaining_ms: 1_800_000,
      learned_skills: Keyword.get(opts, :learned_skills, %{})
    }

    {:ok, row} = %Homunculus{} |> Homunculus.changeset(attrs) |> Repo.insert()
    row
  end

  defp formula_lif(level, int, brain_rank, matk) do
    %Aesir.ZoneServer.Unit.Homunculus.HomunculusState{
      id: 1,
      owner_character_id: 42,
      class_id: 6_001,
      name: "Lif",
      lifecycle: :active,
      level: level,
      hp: 100,
      max_hp: 100,
      sp: 500,
      max_sp: 500,
      int: int,
      learned_skills: %{8_001 => 5, 8_003 => brain_rank},
      world_gid: 700,
      map_name: @map,
      x: 1,
      y: 1,
      combat_stats: %{
        Aesir.ZoneServer.Unit.Homunculus.HomunculusState.__struct__().combat_stats
        | matk_min: matk,
          matk_max: matk
      }
    }
  end
end

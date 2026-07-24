defmodule Aesir.ZoneServer.Integration.ItemBreakIntegrationTest do
  @moduledoc """
  End-to-end coverage of the item break/repair slice on the real stack,
  mirroring the refine integration coverage. It drives the natural weapon
  break through the genuine combat path and proves the in-game-visible
  outcome the design promises:

    1. With `Config.natural_break_rate` forced to 100% a player basic-attacking
       a mob breaks its OWN equipped weapon - the row flips `attribute == 1`,
       auto-unequips (`equip == 0`), its atk contribution drops out of the
       recomputed combat stats, and the red break system message is emitted.
    2. `@repairall` clears the broken flag (leaving the row unequipped, matching
       rAthena); re-equipping restores the weapon's atk.
    3. With `natural_break_rate == 0` repeated confirmed hits NEVER break gear.

  The natural break casts `{:break_equip, :right_hand}` to `self()` from inside
  `Combat.execute_attack/3`, so the attack MUST run inside the attacker's
  `PlayerSession`. Tests 1 and 2 therefore drive the real client attack packet
  (`%ActionRequest{action: 0}`) into the session rather than calling
  `Combat.execute_attack/3` from the test process (whose `self()` is not the
  session). Only `EquipBreak`'s hit precondition is made deterministic - by
  zeroing the mob's luck in its real registry record so perfect dodge can never
  fire - while the resolver, `Config`, and `BreakOps` all run for real.

  Test 3 exercises the resolver at rate 0 directly through
  `Combat.execute_attack/3` in a loop: at rate 0 the resolver returns no
  decisions and no cast is generated, so running it from the test process is
  faithful and lets the attack repeat without attack-speed rate limiting.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.Announcement, as: AnnouncementMsg
  alias Aesir.Net.EquipItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Gm.Commands.RepairAll
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @player_pos {150, 150}
  @mob_pos {151, 150}
  # Sword: weapon_level 1, one_handed_sword (breakable), +25 atk when equipped.
  @sword 1101
  # EQP_HAND_R equip bitmask / EquipItem position for a right-hand weapon.
  @right_hand 2

  setup do
    prev_rate = Application.get_env(:zone_server, :natural_break_rate)
    on_exit(fn -> restore_break_rate(prev_rate) end)
    :ok
  end

  describe "natural weapon break at 100% rate" do
    test "attacking a mob breaks the player's own weapon and drops its atk" do
      Application.put_env(:zone_server, :natural_break_rate, 10_000)

      character = insert_character()
      seed_inventory(character.id, nameid: @sword, amount: 1, equip: @right_hand)

      session = start_session(character)
      mob = start_undodgeable_mob()

      atk_equipped = get_player_state(session.pid).stats.combat_stats.atk

      flush_packets()
      attack(session.pid, mob.unit_id)

      broken = wait_for_break(session.pid)

      assert %InventoryItem{attribute: 1, equip: 0} = broken

      state = get_player_state(session.pid)
      assert state.stats.combat_stats.atk == atk_equipped - 25

      assert_receive {:packet_sent, %AnnouncementMsg{text: text, style: :LOCAL, color: 0xFF0000},
                      _},
                     1_000

      assert text =~ "has broken!"

      assert %InventoryItem{attribute: 1, equip: 0} =
               InventoryPersistence.load_inventory(character.id)
               |> Enum.find(&(&1.nameid == @sword))
    end
  end

  describe "@repairall then re-equip" do
    test "repair clears the broken flag and re-equipping restores atk" do
      Application.put_env(:zone_server, :natural_break_rate, 10_000)

      character = insert_character()
      seed_inventory(character.id, nameid: @sword, amount: 1, equip: @right_hand)

      session = start_session(character)
      mob = start_undodgeable_mob()

      atk_equipped = get_player_state(session.pid).stats.combat_stats.atk

      attack(session.pid, mob.unit_id)
      assert %InventoryItem{attribute: 1, equip: 0} = wait_for_break(session.pid)

      assert {:ok, _msg} = RepairAll.execute([Integer.to_string(character.id)], %{})

      repaired = wait_until(session.pid, fn item -> item.attribute == 0 end)
      assert %InventoryItem{attribute: 0, equip: 0} = repaired

      index = sword_index(session.pid)

      send(
        session.pid,
        {:message, %EquipItem{index: PlayerState.client_index(index), position: @right_hand}}
      )

      reworn = wait_until(session.pid, fn item -> item.equip == @right_hand end)
      assert %InventoryItem{attribute: 0, equip: @right_hand} = reworn
      assert get_player_state(session.pid).stats.combat_stats.atk == atk_equipped
    end
  end

  describe "natural break disabled" do
    test "repeated confirmed hits never break gear at rate 0" do
      Application.put_env(:zone_server, :natural_break_rate, 0)

      character = insert_character()
      seed_inventory(character.id, nameid: @sword, amount: 1, equip: @right_hand)

      session = start_session(character)
      mob = start_mob()

      flush_packets()

      stats = PlayerSession.get_current_stats(session.pid)
      player_state = get_player_state(session.pid)

      Enum.each(1..20, fn _ ->
        Combat.execute_attack(stats, player_state, mob.unit_id)
      end)

      state = get_player_state(session.pid)

      assert %InventoryItem{attribute: 0, equip: @right_hand} =
               item_by_nameid(state.inventory, @sword)

      refute_receive {:packet_sent, %AnnouncementMsg{text: "Your" <> _rest}, _}, 100
    end
  end

  defp attack(pid, target_id) do
    simulate_incoming_message(pid, %ActionRequest{target_id: target_id, action: 0})
  end

  # Each iteration issues a `get_player_state` call, which is a synchronous
  # barrier draining the session mailbox. The `{:break_equip, ...}` self-cast is
  # enqueued while the attack info-message is handled, which can race the first
  # barrier call; the following call is guaranteed to sit behind it, so
  # convergence takes at most two iterations. No sleeps; a never-breaking weapon
  # exhausts the bound and fails the caller's assertion.
  defp wait_for_break(pid), do: wait_until(pid, fn item -> item.attribute == 1 end)

  defp wait_until(pid, predicate) do
    Enum.reduce_while(1..30, nil, fn _, _acc ->
      item = pid |> get_player_state() |> Map.fetch!(:inventory) |> item_by_nameid(@sword)

      if item && predicate.(item), do: {:halt, item}, else: {:cont, nil}
    end)
  end

  defp start_session(character) do
    session = start_player_session(character: character, map_name: @map, position: @player_pos)
    on_exit(fn -> end_player_session(session) end)
    flush_packets()
    session
  end

  defp start_mob do
    mob =
      start_mob_session(
        map_name: @map,
        position: @mob_pos,
        hp: 1_000_000,
        max_hp: 1_000_000,
        level: 1
      )

    on_exit(fn -> end_mob_session(mob) end)
    mob
  end

  # Removes the only source of hit non-determinism against a level-1 mob:
  # perfect dodge (`luk / 5`). Hit rate is already clamped to 100 for a high-DEX
  # attacker, so with perfect dodge zeroed every confirmed swing lands and the
  # 100% break is guaranteed. This mutates only this mob's real registry record
  # (via `update_unit_state`, preserving its module and pid) so every unrelated
  # `get_unit` lookup still hits the real implementation; the resolver, Config,
  # and BreakOps stay real.
  defp start_undodgeable_mob do
    mob = start_mob()

    stats = %{mob.mob_state.mob_data.stats | luk: 0}
    mob_data = %{mob.mob_state.mob_data | stats: stats}
    mob_state = %{mob.mob_state | mob_data: mob_data}

    :ok = UnitRegistry.update_unit_state(:mob, mob.unit_id, mob_state)
    mob
  end

  defp sword_index(pid) do
    pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Enum.find_value(fn {index, item} -> if item.nameid == @sword, do: index end)
  end

  defp item_by_nameid(inventory, nameid) do
    inventory |> Map.values() |> Enum.find(&(&1.nameid == nameid))
  end

  defp insert_character do
    uniq = System.unique_integer([:positive])
    {x, y} = @player_pos

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "breaker#{uniq}",
        userid: "breaker#{uniq}",
        user_pass: "password",
        email: "breaker#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Breaker#{uniq}",
        class: 0,
        base_level: 99,
        job_level: 50,
        str: 99,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 99,
        luk: 10,
        zeny: 0,
        last_map: @map,
        last_x: x,
        last_y: y,
        save_map: @map,
        save_x: x,
        save_y: y
      })
      |> Repo.insert()

    character
  end

  defp seed_inventory(char_id, attrs) do
    attrs = attrs |> Map.new() |> Map.put_new(:identify, 1)
    {:ok, item} = InventoryPersistence.insert_item(char_id, attrs)
    item
  end

  defp restore_break_rate(nil), do: Application.delete_env(:zone_server, :natural_break_rate)

  defp restore_break_rate(value),
    do: Application.put_env(:zone_server, :natural_break_rate, value)
end

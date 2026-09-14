defmodule Aesir.ZoneServer.Integration.ItemEligibilityProgressionTest do
  use Aesir.ZoneServer.IntegrationCase

  import Bitwise

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.SkillList
  alias Aesir.Net.SpriteChange
  alias Aesir.Net.UnequipResult
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @nagan 1130
  @shield 2105
  @right_hand 2
  @left_hand 32

  setup do
    Mimic.copy(Persistence)
    Mimic.copy(PlayerEvents)
    :ok
  end

  test "job change persists cleanup for the target job before changing progression" do
    character = insert_character(:swordman, 99)
    weapon = seed_item(character.id, @nagan, @right_hand)
    session = start_session(character)
    before = settled_state(session)
    {:ok, mage_id} = AvailableJobs.job_name_to_id(:mage)

    flush_packets()

    assert {:ok, changed} =
             run_progression(session.pid, &ProgressionHandler.apply_job_change(mage_id, &1))

    assert before.game_state.inventory[0].equip == @right_hand
    assert changed.game_state.inventory[0].equip == 0
    assert changed.game_state.stats.progression.job_id == mage_id
    assert Repo.get!(InventoryItem, weapon.id).equip == 0
    assert Repo.get!(Character, character.id).class == mage_id
    assert %UnequipResult{} = assert_packet_sent(UnequipResult)
    assert Enum.any?(collect_packets_of_type(SpriteChange), &(&1.val == mage_id))
    assert %SkillList{} = assert_packet_sent(SkillList)
  end

  test "level reset persists cleanup for the target level before resetting progression" do
    character = insert_character(:swordman, 99)
    weapon = seed_item(character.id, @nagan, @right_hand)
    session = start_session(character)
    before = settled_state(session)

    flush_packets()

    assert {:ok, reset} =
             run_progression(session.pid, &ProgressionHandler.reset_level(3, &1))

    assert before.game_state.inventory[0].equip == @right_hand
    assert reset.game_state.inventory[0].equip == 0
    assert reset.game_state.stats.progression.base_level == 1
    assert Repo.get!(InventoryItem, weapon.id).equip == 0
    assert Repo.get!(Character, character.id).base_level == 1
    assert %UnequipResult{} = assert_packet_sent(UnequipResult)
  end

  test "later cleanup write failure rolls back and leaves every progression side effect unchanged" do
    character = insert_character(:swordman, 99)
    weapon = seed_item(character.id, @nagan, @right_hand)
    shield = seed_item(character.id, @shield, @left_hand)
    session = start_session(character)
    settled_state(session)
    {:ok, mage_id} = AvailableJobs.job_name_to_id(:mage)
    {:ok, riding} = Catalog.by_name(:kn_riding)
    {:ok, falcon} = Catalog.by_name(:ht_falcon)
    test_pid = self()
    shield_id = shield.id

    :ok = StatusStorage.apply_status(:player, character.id, :sc_riding, val1: 3)
    :ok = StatusStorage.apply_status(:player, character.id, :sc_falcon)

    before =
      :sys.replace_state(session.pid, fn state ->
        progression = %{
          state.game_state.stats.progression
          | learned_skills: %{riding.id => 1, falcon.id => 1},
            skill_point: 7
        }

        game_state = %{
          state.game_state
          | action_state: :vending,
            option: Option.id(:riding) ||| Option.id(:falcon),
            stats: %{state.game_state.stats | progression: progression}
        }

        %{state | game_state: game_state}
      end)

    :ok = UnitRegistry.update_unit_state(:player, character.id, before.game_state)

    stub(Persistence, :update_item, fn
      %InventoryItem{id: ^shield_id}, %{equip: 0} ->
        {:error, :later_row_failed}

      item, attrs ->
        Mimic.call_original(Persistence, :update_item, [item, attrs])
    end)

    stub(PlayerEvents, :inventory_changed, fn _character_id ->
      send(test_pid, :inventory_event)
      :ok
    end)

    stub(PlayerEvents, :progression_changed, fn _character_id ->
      send(test_pid, :progression_event)
      :ok
    end)

    Mimic.allow(Persistence, self(), session.pid)
    Mimic.allow(PlayerEvents, self(), session.pid)
    flush_packets()

    assert {:error, :later_row_failed} =
             run_progression(session.pid, &ProgressionHandler.apply_job_change(mage_id, &1))

    assert PlayerSession.get_state(session.pid) == before
    assert Repo.get!(InventoryItem, weapon.id).equip == @right_hand
    assert Repo.get!(InventoryItem, shield.id).equip == @left_hand
    assert Repo.get!(Character, character.id).class == before.game_state.stats.progression.job_id
    assert Repo.get!(Character, character.id).base_level == 99
    assert StatusStorage.has_status?(:player, character.id, :sc_riding)
    assert StatusStorage.has_status?(:player, character.id, :sc_falcon)

    assert {:ok, {_module, published, session_pid}} =
             UnitRegistry.get_unit(:player, character.id)

    assert published == before.game_state
    assert session_pid == session.pid
    refute_receive :inventory_event
    refute_receive :progression_event
    refute_packet_sent(UnequipResult)
    refute_packet_sent(SpriteChange)
    refute_packet_sent(SkillList)
    refute_receive {:packet_sent, _packet, _channel}
  end

  defp run_progression(pid, operation) do
    caller = self()

    :sys.replace_state(pid, fn state ->
      result = operation.(state)
      send(caller, {:progression_result, result})

      case result do
        {:ok, updated} -> updated
        {:error, _reason} -> state
      end
    end)

    assert_receive {:progression_result, result}
    result
  end

  defp insert_character(job, base_level) do
    unique = System.unique_integer([:positive]) |> Integer.to_string(36)
    userid = "prog#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, job_id} = AvailableJobs.job_name_to_id(job)

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Progression#{unique}",
        class: job_id,
        sex: "M",
        base_level: base_level,
        job_level: 50,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      })
      |> Repo.insert()

    character
  end

  defp seed_item(character_id, item_id, equip) do
    {:ok, item} =
      Persistence.insert_item(character_id, %{
        nameid: item_id,
        amount: 1,
        identify: 1,
        equip: equip
      })

    item
  end

  defp start_session(character) do
    session = start_player_session(character: character, map_name: "prontera")
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp settled_state(session) do
    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).quest_info_display.map == "prontera"
    end)

    PlayerSession.get_state(session.pid)
  end
end

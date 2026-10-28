defmodule Aesir.ZoneServer.Integration.ItemEligibilityRevalidationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ParamChange
  alias Aesir.Net.SkillList
  alias Aesir.Net.SpriteChange
  alias Aesir.Net.UnequipResult
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @sword 1101
  @katana 1116
  @nagan 1130
  @shield 2105
  @right_hand 2
  @left_hand 32
  @both_hand 34

  setup do
    Mimic.copy(Persistence)
    Mimic.copy(PlayerEvents)
    :ok
  end

  test "revalidates equipped items inside the owning session without changing identity" do
    character = insert_character(:swordman, 99, "M")
    katana = seed_item(character.id, @katana, 2, @both_hand)
    session = start_session(character)
    before = PlayerSession.get_state(session.pid)
    {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)

    flush_packets()

    assert {:ok, rechecked} =
             recheck(session.pid, %{job_id: novice_id, base_level: 99, sex: "M"})

    assert rechecked.game_state.inventory[0].equip == 0
    assert rechecked.game_state.inventory[0].amount == 2
    assert rechecked.game_state.inventory[0] == Repo.get!(InventoryItem, katana.id)

    assert rechecked.game_state.stats.progression.job_id ==
             before.game_state.stats.progression.job_id

    assert rechecked.game_state.stats.progression.base_level == 99

    assert %UnequipResult{
             index: index,
             wear_location: @both_hand,
             result: 0
           } = assert_packet_sent(UnequipResult)

    assert index == PlayerState.client_index(0)
    session_pid = session.pid

    assert {:ok, {PlayerState, published, ^session_pid}} =
             UnitRegistry.get_unit(:player, character.id)

    assert published == rechecked.game_state
  end

  test "atomically removes multiple items and runs the complete post-commit sync" do
    character = insert_character(:swordman, 99, "M")
    weapon = seed_item(character.id, @nagan, 2, @right_hand)
    shield = seed_item(character.id, @shield, 3, @left_hand)
    session = start_session(character)
    before = settled_state(session)
    {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
    test_pid = self()

    :ok = Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{character.id}")
    :ok = StatusStorage.apply_status(:player, character.id, :sc_aspersio, duration: 30_000)
    :ok = StatusStorage.apply_status(:player, character.id, :sc_autoguard)

    stub(Persistence, :transaction, fn fun ->
      send(test_pid, :transaction_started)
      Mimic.call_original(Persistence, :transaction, [fun])
    end)

    Mimic.allow(Persistence, self(), session.pid)
    flush_packets()

    assert {:ok, rechecked} =
             recheck(session.pid, %{job_id: novice_id, base_level: 99, sex: "M"})

    assert_receive :transaction_started
    refute_receive :transaction_started
    assert_receive :inventory_changed

    assert rechecked.game_state.inventory
           |> Enum.map(fn {index, item} -> {index, item.nameid, item.amount, item.equip} end)
           |> Enum.sort() == [{0, @nagan, 2, 0}, {1, @shield, 3, 0}]

    assert Repo.get!(InventoryItem, weapon.id).equip == 0
    assert Repo.get!(InventoryItem, shield.id).equip == 0
    assert rechecked.game_state.stats.progression == before.game_state.stats.progression
    assert rechecked.game_state.stats.granted_skills[48] == nil
    assert rechecked.game_state.stats.combat_stats.atk < before.game_state.stats.combat_stats.atk
    assert rechecked.game_state.stats.equipment.right_hand == nil
    assert rechecked.game_state.stats.equipment.left_hand == nil
    refute StatusStorage.has_status?(:player, character.id, :sc_aspersio)
    refute StatusStorage.has_status?(:player, character.id, :sc_autoguard)

    assert [%UnequipResult{} = first, %UnequipResult{} = second] =
             collect_packets_of_type(UnequipResult)

    assert [{first.index, first.wear_location}, {second.index, second.wear_location}] == [
             {PlayerState.client_index(0), @right_hand},
             {PlayerState.client_index(1), @left_hand}
           ]

    assert %SkillList{} = assert_packet_sent(SkillList)
    assert %SpriteChange{} = assert_packet_sent(SpriteChange)

    expected_weight = Weight.current_weight(rechecked.game_state.inventory)

    assert Enum.any?(collect_packets_of_type(ParamChange), fn packet ->
             packet.var_id == StatusParams.weight() and packet.value == expected_weight
           end)

    assert {:ok, {PlayerState, published, session_pid}} =
             UnitRegistry.get_unit(:player, character.id)

    assert published.inventory == rechecked.game_state.inventory
    assert published.stats.progression == rechecked.game_state.stats.progression
    assert session_pid == session.pid
  end

  test "eligible equipment is a strict no-op" do
    character = insert_character(:swordman, 99, "M")
    item = seed_item(character.id, @sword, 1, @right_hand)
    session = start_session(character)
    before = settled_state(session)
    test_pid = self()

    :ok = StatusStorage.apply_status(:player, character.id, :sc_aspersio, duration: 30_000)

    stub(Persistence, :transaction, fn _fun ->
      send(test_pid, :transaction_started)
      {:error, :unexpected_transaction}
    end)

    stub(PlayerEvents, :inventory_changed, fn _character_id ->
      send(test_pid, :inventory_event)
      :ok
    end)

    Mimic.allow(Persistence, self(), session.pid)
    Mimic.allow(PlayerEvents, self(), session.pid)
    flush_packets()

    context = %{
      job_id: before.game_state.stats.progression.job_id,
      base_level: 99,
      sex: "M"
    }

    assert {:ok, ^before} = recheck(session.pid, context)
    assert PlayerSession.get_state(session.pid) == before
    assert Repo.get!(InventoryItem, item.id).equip == @right_hand
    assert StatusStorage.has_status?(:player, character.id, :sc_aspersio)

    assert {:ok, {PlayerState, published, session_pid}} =
             UnitRegistry.get_unit(:player, character.id)

    assert published == before.game_state
    assert session_pid == session.pid
    refute_receive :transaction_started
    refute_receive :inventory_event
    refute_packet_sent(UnequipResult)
    refute_packet_sent(ParamChange)
    refute_packet_sent(SpriteChange)
    refute_packet_sent(SkillList)
  end

  test "a later-row failure rolls back persistence and suppresses every post-commit effect" do
    character = insert_character(:swordman, 99, "M")
    weapon = seed_item(character.id, @sword, 1, @right_hand)
    shield = seed_item(character.id, @shield, 1, @left_hand)
    session = start_session(character)
    before = settled_state(session)
    {:ok, mage_id} = AvailableJobs.job_name_to_id(:mage)
    test_pid = self()
    shield_id = shield.id

    :ok = StatusStorage.apply_status(:player, character.id, :sc_aspersio, duration: 30_000)
    :ok = StatusStorage.apply_status(:player, character.id, :sc_autoguard)

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

    Mimic.allow(Persistence, self(), session.pid)
    Mimic.allow(PlayerEvents, self(), session.pid)
    flush_packets()

    assert {:error, :later_row_failed} =
             recheck(session.pid, %{job_id: mage_id, base_level: 99, sex: "M"})

    assert PlayerSession.get_state(session.pid) == before
    assert Repo.get!(InventoryItem, weapon.id).equip == @right_hand
    assert Repo.get!(InventoryItem, shield.id).equip == @left_hand
    assert StatusStorage.has_status?(:player, character.id, :sc_aspersio)
    assert StatusStorage.has_status?(:player, character.id, :sc_autoguard)

    assert {:ok, {PlayerState, published, session_pid}} =
             UnitRegistry.get_unit(:player, character.id)

    assert published == before.game_state
    assert session_pid == session.pid
    refute_receive :inventory_event
    refute_packet_sent(UnequipResult)
    refute_packet_sent(ParamChange)
    refute_packet_sent(SpriteChange)
    refute_packet_sent(SkillList)
  end

  test "invalid identity and missing definitions fail before persistence" do
    character = insert_character(:swordman, 99, "M")
    session = start_session(character)
    settled_state(session)
    item = seed_item(character.id, 999_999, 1, @right_hand)

    before =
      :sys.replace_state(session.pid, fn state ->
        game_state = %{state.game_state | inventory: %{0 => item}}
        %{state | game_state: game_state}
      end)

    :ok = UnitRegistry.update_unit_state(:player, character.id, before.game_state)
    test_pid = self()

    stub(Persistence, :transaction, fn _fun ->
      send(test_pid, :transaction_started)
      {:error, :unexpected_transaction}
    end)

    Mimic.allow(Persistence, self(), session.pid)
    flush_packets()

    assert {:error, :invalid_identity} =
             recheck(session.pid, %{job_id: -1, base_level: 99, sex: "M"})

    assert {:error, {:missing_definition, 999_999}} =
             recheck(session.pid, %{
               job_id: before.game_state.stats.progression.job_id,
               base_level: 99,
               sex: "M"
             })

    assert PlayerSession.get_state(session.pid) == before
    assert Repo.get!(InventoryItem, item.id).equip == @right_hand
    refute_receive :transaction_started
    refute_packet_sent(UnequipResult)
    refute_packet_sent(ParamChange)
  end

  defp recheck(pid, context) do
    caller = self()

    :sys.replace_state(pid, fn state ->
      result = EquipmentHandler.recheck_requirements(context, state)
      send(caller, {:recheck_result, result})

      case result do
        {:ok, updated} -> updated
        {:error, _reason} -> state
      end
    end)

    assert_receive {:recheck_result, result}
    result
  end

  defp insert_character(job, base_level, sex) do
    unique = System.unique_integer([:positive]) |> Integer.to_string(36)
    userid = "reval#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: sex,
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, job_id} = AvailableJobs.job_name_to_id(job)

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Revalidation#{unique}",
        class: job_id,
        sex: sex,
        base_level: base_level,
        job_level: 1,
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

  defp seed_item(character_id, item_id, amount, equip) do
    {:ok, item} =
      Persistence.insert_item(character_id, %{
        nameid: item_id,
        amount: amount,
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

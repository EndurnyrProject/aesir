defmodule Aesir.ZoneServer.Integration.EquipStatusLifecycleIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.EquipItem
  alias Aesir.Net.UnequipItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "prontera"
  @armor EquipLocation.location_bit(:armor)
  @head_top EquipLocation.location_bit(:head_top)
  @right_hand EquipLocation.location_bit(:right_hand)
  @armor_provider 991_001
  @head_provider 991_002
  @plain_armor 991_003
  @weapon_provider 991_004
  @rental_provider 991_005
  @restricted_provider 991_006
  @card_armor_host 991_007
  @card_head_host 991_008
  @status_card 991_009
  @status :sc_summer
  @status_params {:infinite, 7}

  {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
  @swordman_id swordman_id

  setup do
    Mimic.copy(Items)

    items = %{
      @armor_provider => status_item(@armor_provider, [:armor]),
      @head_provider => status_item(@head_provider, [:head_top]),
      @plain_armor => plain_item(@plain_armor, [:armor]),
      @weapon_provider =>
        status_item(@weapon_provider, [:right_hand], type: :weapon, subtype: :one_handed_sword),
      @rental_provider => status_item(@rental_provider, [:armor]),
      @restricted_provider => status_item(@restricted_provider, [:armor], jobs: [:novice]),
      @card_armor_host => card_host(@card_armor_host, [:armor]),
      @card_head_host => card_host(@card_head_host, [:head_top]),
      @status_card => status_card()
    }

    stub(Items, :by_id, fn item_id ->
      case Map.fetch(items, item_id) do
        {:ok, item} -> {:ok, item}
        :error -> call_original(Items, :by_id, [item_id])
      end
    end)

    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "login reconstructs a worn direct status after player registration" do
    character = insert_character("StatusLogin")
    seed_item(character.id, @armor_provider, equip: @armor)

    session = start_session(character)

    assert status_state?(session.pid, character.id, @status_params)
    assert get_player_state(session.pid).stats.equip_statuses == %{@status => @status_params}
    assert StatusInterpreter.get_all_modifiers(:player, character.id) == %{}

    equipment = get_player_state(session.pid).stats.modifiers.equipment
    assert equipment.aspd_rate == 100
    assert equipment |> Map.delete(:aspd_rate) |> Map.values() |> Enum.all?(&(&1 == 0))
  end

  test "login adopts card cleanup and duplicate cards rebuild status as each host leaves" do
    character = insert_character("StatusCards")
    armor = seed_item(character.id, @card_armor_host, equip: @armor, card0: @status_card)
    head = seed_item(character.id, @card_head_host, equip: @head_top, card0: @status_card)
    session = start_session(character)
    initial_sp = get_player_state(session.pid).stats.current_state.sp

    assert initial_sp == character.sp

    assert eventually(fn ->
             state = PlayerSession.get_state(session.pid)

             status_state?(session.pid, character.id, @status_params) and
               state.applied_card_unequip_effects == %{
                 {armor.id, 0} => %{source_order: {0, 0}, effects: [{:heal, 0, 5}]},
                 {head.id, 0} => %{source_order: {1, 0}, effects: [{:heal, 0, 5}]}
               } and
               state.game_state.stats.current_state.sp == initial_sp
           end)

    assert :ok =
             StatusInterpreter.apply_status(:player, character.id, :sc_strangelights,
               caster_id: character.id,
               duration: 30_000,
               bypass_resistance: true,
               owner_refresh: :defer
             )

    unequip(session.pid, armor.id)

    assert eventually(fn ->
             state = PlayerSession.get_state(session.pid)

             status_state?(session.pid, character.id, @status_params) and
               state.applied_card_unequip_effects == %{
                 {head.id, 0} => %{source_order: {0, 0}, effects: [{:heal, 0, 5}]}
               } and
               state.game_state.stats.current_state.sp == initial_sp + 5 and
               StatusStorage.has_status?(:player, character.id, :sc_strangelights)
           end)

    unequip(session.pid, head.id)

    assert eventually(fn ->
             state = PlayerSession.get_state(session.pid)

             status_absent?(session.pid, character.id) and
               state.applied_card_unequip_effects == %{} and
               state.game_state.stats.current_state.sp == initial_sp + 10 and
               StatusStorage.has_status?(:player, character.id, :sc_strangelights)
           end)
  end

  test "equip, duplicate providers, ordinary unequip, and replacement reconcile one status" do
    character = insert_character("StatusEquip")
    armor = seed_item(character.id, @armor_provider, equip: 0)
    head = seed_item(character.id, @head_provider, equip: 0)
    plain = seed_item(character.id, @plain_armor, equip: 0)
    session = start_session(character)
    baseline_modifiers = get_player_state(session.pid).stats.modifiers.equipment

    equip(session.pid, armor.id, @armor)
    assert eventually(fn -> status_state?(session.pid, character.id, @status_params) end)

    equip(session.pid, head.id, @head_top)

    assert eventually(fn ->
             state = PlayerSession.get_state(session.pid)

             state.game_state.stats.equip_statuses == %{@status => @status_params} and
               state.applied_equip_statuses == %{@status => @status_params} and
               length(StatusStorage.get_unit_statuses(:player, character.id)) == 1
           end)

    unequip(session.pid, armor.id)
    assert eventually(fn -> status_state?(session.pid, character.id, @status_params) end)

    equip(session.pid, armor.id, @armor)
    unequip(session.pid, head.id)
    assert eventually(fn -> status_state?(session.pid, character.id, @status_params) end)

    unequip(session.pid, armor.id)
    assert eventually(fn -> status_absent?(session.pid, character.id) end)

    equip(session.pid, armor.id, @armor)
    assert eventually(fn -> status_state?(session.pid, character.id, @status_params) end)

    equip(session.pid, plain.id, @armor)

    assert eventually(fn ->
             status_absent?(session.pid, character.id) and
               inventory_item(session.pid, armor.id).equip == 0 and
               inventory_item(session.pid, plain.id).equip == @armor
           end)

    assert get_player_state(session.pid).stats.modifiers.equipment == baseline_modifiers
  end

  test "equipment breakage removes the final paired status provider" do
    character = insert_character("StatusBreak")
    row = seed_item(character.id, @weapon_provider, equip: @right_hand)
    session = start_session(character)

    assert status_state?(session.pid, character.id, @status_params)

    PlayerSession.break_equip(session.pid, :right_hand)

    assert eventually(fn ->
             match?(%InventoryItem{attribute: 1, equip: 0}, inventory_item(session.pid, row.id)) and
               status_absent?(session.pid, character.id)
           end)
  end

  test "rental expiry unequips and removes the final status provider" do
    character = insert_character("StatusRental")

    expires_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.add(2, :second)

    seed_item(character.id, @rental_provider, equip: @armor, expire_time: expires_at)
    session = start_session(character)

    assert status_state?(session.pid, character.id, @status_params)
    assert eventually(fn -> NaiveDateTime.compare(NaiveDateTime.utc_now(), expires_at) != :lt end)

    send(session.pid, :rental_expiry_tick)

    assert eventually(fn ->
             state = PlayerSession.get_state(session.pid)

             state.game_state.inventory == %{} and
               state.game_state.stats.equip_statuses == %{} and
               status_absent?(session.pid, character.id)
           end)
  end

  test "progression-forced unequip removes the final status provider" do
    character = insert_character("StatusProgress")
    row = seed_item(character.id, @restricted_provider, equip: @armor)
    session = start_session(character)

    assert status_state?(session.pid, character.id, @status_params)
    assert :ok = JobChange.request(character.id, @swordman_id)

    assert eventually(fn ->
             state = PlayerSession.get_state(session.pid)

             state.game_state.stats.progression.job_id == @swordman_id and
               inventory_item(session.pid, row.id).equip == 0 and
               state.game_state.stats.equip_statuses == %{} and
               status_absent?(session.pid, character.id)
           end)
  end

  defp status_item(id, locations, opts \\ []) do
    %ItemDefinition{
      id: id,
      aegis_name: "STATUS_ITEM_#{id}",
      name: "Status Item #{id}",
      type: Keyword.get(opts, :type, :armor),
      subtype: Keyword.get(opts, :subtype),
      jobs: Keyword.get(opts, :jobs, []),
      locations: locations,
      on_equip: [{:status_start, @status, elem(@status_params, 0), elem(@status_params, 1)}],
      on_unequip: [{:status_end, @status}]
    }
  end

  defp plain_item(id, locations) do
    %ItemDefinition{
      id: id,
      aegis_name: "PLAIN_ITEM_#{id}",
      name: "Plain Item #{id}",
      type: :armor,
      locations: locations
    }
  end

  defp card_host(id, locations) do
    %{plain_item(id, locations) | slots: 1}
  end

  defp status_card do
    %ItemDefinition{
      id: @status_card,
      aegis_name: "STATUS_CARD",
      name: "Status Card",
      type: :card,
      on_equip: [{:status_start, @status, elem(@status_params, 0), elem(@status_params, 1)}],
      on_unequip: [{:heal, 0, 5}]
    }
  end

  defp start_session(character) do
    session = start_player_session(character: character, map_name: @map, position: {150, 150})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp insert_character(name) do
    unique = System.unique_integer([:positive]) |> Integer.to_string(36)
    userid = "status#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: 0,
        base_level: 50,
        job_level: 10,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        last_map: @map,
        last_x: 150,
        last_y: 150,
        save_map: @map,
        save_x: 150,
        save_y: 150,
        learned_skills: %{}
      })
      |> Repo.insert()

    character
  end

  defp seed_item(character_id, item_id, attrs) do
    attrs = attrs |> Map.new() |> Map.merge(%{nameid: item_id, amount: 1, identify: 1})
    {:ok, item} = InventoryPersistence.insert_item(character_id, attrs)
    item
  end

  defp equip(pid, row_id, position) do
    simulate_incoming_message(pid, %EquipItem{
      index: row_id |> inventory_index(pid) |> PlayerState.client_index(),
      position: position
    })
  end

  defp unequip(pid, row_id) do
    simulate_incoming_message(pid, %UnequipItem{
      index: row_id |> inventory_index(pid) |> PlayerState.client_index()
    })
  end

  defp inventory_index(row_id, pid) do
    pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Enum.find_value(fn {index, item} -> if item.id == row_id, do: index end)
  end

  defp inventory_item(pid, row_id) do
    pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Map.values()
    |> Enum.find(&(&1.id == row_id))
  end

  defp status_state?(pid, character_id, params) do
    case StatusStorage.get_status(:player, character_id, @status) do
      %{} = status ->
        status.val1 == elem(params, 1) and
          PlayerSession.get_state(pid).applied_equip_statuses == %{@status => params}

      nil ->
        false
    end
  end

  defp status_absent?(pid, character_id) do
    not StatusStorage.has_status?(:player, character_id, @status) and
      PlayerSession.get_state(pid).applied_equip_statuses == %{}
  end
end

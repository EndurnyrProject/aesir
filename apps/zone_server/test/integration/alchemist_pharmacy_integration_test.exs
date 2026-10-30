defmodule Aesir.ZoneServer.Integration.AlchemistPharmacyIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ProductionResult
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence

  @pharmacy_skill_id 228
  @medicine_bowl_id 7134

  setup do
    previous = Application.get_env(:zone_server, :forge_rng)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:zone_server, :forge_rng, previous),
        else: Application.delete_env(:zone_server, :forge_rng)
    end)

    :ok = Catalog.reload()
  end

  test "Pharmacy brews a signed potion that Potion Pitcher can consume" do
    Application.put_env(:zone_server, :forge_rng, fn _upper -> 1 end)
    character = insert_alchemist(%{@pharmacy_skill_id => 10, 231 => 1})
    insert_items(character.id, [{@medicine_bowl_id, 1}, {7144, 1}, {507, 1}, {1093, 1}])
    session = start_session(character)

    cast(session, 10)

    # Only the recipe whose materials are held is listed: Red Potion.
    assert_receive {:packet_sent,
                    %SkillMenu{
                      src_skill_id: @pharmacy_skill_id,
                      kind: :ITEMS,
                      entry_ids: [501]
                    }, _},
                   1_000

    assert Inventory.held_amount(get_player_state(session.pid).inventory, @medicine_bowl_id) == 0

    reply(session, 501)
    assert_receive {:packet_sent, %ProductionResult{success: true, item_id: 501}, _}, 1_000

    inventory = get_player_state(session.pid).inventory
    assert Inventory.held_amount(inventory, 501) == 1
    potion = Enum.find_value(inventory, fn {_index, item} -> item.nameid == 501 && item end)
    assert ItemCraft.from_map(potion.craft) == {:ok, ItemCraft.signed(character.id)}
    assert Inventory.held_amount(inventory, 507) == 0
    assert Inventory.held_amount(inventory, 1093) == 0
    assert Inventory.held_amount(inventory, 7144) == 1

    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: 231,
      level: 1,
      target_id: character.id
    })

    assert_eventually(fn ->
      Inventory.held_amount(get_player_state(session.pid).inventory, 501) == 0
    end)
  end

  test "a failed Pharmacy attempt burns the bowl and recipe materials" do
    Application.put_env(:zone_server, :forge_rng, fn
      991 -> 1
      10_000 -> 10_000
    end)

    character = insert_alchemist(%{@pharmacy_skill_id => 1}, int: 0, dex: 0, luk: 0, job_level: 1)
    insert_items(character.id, [{@medicine_bowl_id, 1}, {7144, 1}, {507, 1}, {1093, 1}])
    session = start_session(character)

    cast(session, 1)
    assert_receive {:packet_sent, %SkillMenu{src_skill_id: @pharmacy_skill_id}, _}, 1_000

    reply(session, 501)
    assert_receive {:packet_sent, %ProductionResult{success: false, item_id: 501}, _}, 1_000

    inventory = get_player_state(session.pid).inventory
    assert Inventory.held_amount(inventory, @medicine_bowl_id) == 0
    assert Inventory.held_amount(inventory, 507) == 0
    assert Inventory.held_amount(inventory, 1093) == 0
    assert Inventory.held_amount(inventory, 501) == 0
  end

  test "Pharmacy rejects a cast without a Medicine Bowl without consuming recipe materials" do
    character = insert_alchemist(%{@pharmacy_skill_id => 1})
    insert_items(character.id, [{7144, 1}, {507, 1}, {1093, 1}])
    session = start_session(character)

    cast(session, 1)

    refute_receive {:packet_sent, %SkillMenu{src_skill_id: @pharmacy_skill_id}, _}, 100

    inventory = get_player_state(session.pid).inventory
    assert Inventory.held_amount(inventory, 7144) == 1
    assert Inventory.held_amount(inventory, 507) == 1
    assert Inventory.held_amount(inventory, 1093) == 1
  end

  test "Pharmacy rejects a Blacksmith recipe reply" do
    character = insert_alchemist(%{@pharmacy_skill_id => 1})
    # Red Potion's materials, so the Pharmacy list has something to open with.
    insert_items(character.id, [{@medicine_bowl_id, 1}, {7144, 1}, {507, 1}, {1093, 1}])
    session = start_session(character)

    cast(session, 1)
    assert_receive {:packet_sent, %SkillMenu{src_skill_id: @pharmacy_skill_id}, _}, 1_000

    reply(session, 998)
    refute_receive {:packet_sent, %ProductionResult{}, _}, 100
    assert Process.alive?(session.pid)
  end

  defp cast(session, level) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: @pharmacy_skill_id,
      level: level,
      target_id: session.character.id
    })
  end

  defp reply(session, product_id) do
    simulate_incoming_message(session.pid, %SkillMenuReply{
      src_skill_id: @pharmacy_skill_id,
      selected_id: product_id,
      extra_ids: []
    })
  end

  defp start_session(character) do
    session =
      start_player_session(character: character, map_name: "prontera", position: {150, 150})

    on_exit(fn -> end_player_session(session) end)
    flush_packets()
    Map.put(session, :character, character)
  end

  defp insert_items(character_id, items) do
    Enum.each(items, fn {nameid, amount} ->
      assert {:ok, _item} =
               Persistence.insert_item(character_id, %{
                 nameid: nameid,
                 amount: amount,
                 identify: 1
               })
    end)
  end

  defp insert_alchemist(learned, overrides \\ []) do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        username: "pharmacy#{unique}",
        userid: "pharmacy#{unique}",
        user_pass: "password",
        email: "pharmacy#{unique}@aesir.test"
      })
      |> Repo.insert!()

    attrs = %{
      account_id: account.id,
      char_num: 0,
      name: "Pharmacy#{unique}",
      class: 18,
      base_level: 99,
      job_level: 70,
      int: 99,
      dex: 99,
      luk: 99,
      hp: 500,
      max_hp: 500,
      sp: 500,
      max_sp: 500,
      learned_skills: Map.new(learned, fn {id, level} -> {Integer.to_string(id), level} end),
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150
    }

    %Character{}
    |> Character.changeset(Map.merge(attrs, Map.new(overrides)))
    |> Repo.insert!()
  end
end

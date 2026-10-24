defmodule Aesir.ZoneServer.Integration.BlacksmithForgeIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ProductionResult
  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @craft_skills [94, 95, 96] ++ Enum.to_list(98..104)

  setup do
    previous = Application.get_env(:zone_server, :forge_rng)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:zone_server, :forge_rng, previous),
        else: Application.delete_env(:zone_server, :forge_rng)
    end)

    :ok = Catalog.reload()
  end

  # The production list an item's `produce` script opens is not a skill's menu:
  # it carries src_skill_id 0 and the reply answers with the same id.
  @menu 0
  @furnace 612
  @iron_hammer 613
  @oridecon_hammer 615

  test "forges a selected family weapon with catalysts and stamps it" do
    Application.put_env(:zone_server, :forge_rng, fn _upper -> 1 end)
    character = insert_blacksmith(%{99 => 1, 97 => 5, 107 => 10})
    insert_items(character.id, [{998, 2}, {994, 1}, {1000, 1}, {@iron_hammer, 1}])
    session = start_session(character)

    use_item(session, @iron_hammer)

    assert_receive {:packet_sent,
                    %SkillMenu{src_skill_id: @menu, kind: :ITEMS, entry_ids: [1101]}, _},
                   1_000

    assert Inventory.held_amount(get_player_state(session.pid).inventory, @iron_hammer) == 0

    reply(session, 1101, [994, 1000])
    assert_receive {:packet_sent, %ProductionResult{success: true, item_id: 1101}, _}, 1_000

    state = get_player_state(session.pid)
    assert Inventory.held_amount(state.inventory, 998) == 0
    assert Inventory.held_amount(state.inventory, 994) == 0
    assert Inventory.held_amount(state.inventory, 1000) == 0

    weapon = Enum.find_value(state.inventory, fn {_slot, item} -> item.nameid == 1101 && item end)
    character_id = character.id

    assert {:ok,
            %ItemCraft{
              kind: :forged,
              element: :fire,
              star_crumbs: 1,
              creator_char_id: ^character_id
            }} = ItemCraft.from_map(weapon.craft)

    assert weapon.identify == 1
  end

  test "a failed family forge consumes inputs and grants nothing" do
    Application.put_env(:zone_server, :forge_rng, fn
      100 -> 100
      10_000 -> 10_000
    end)

    character = insert_blacksmith(%{98 => 3}, dex: 1, luk: 1, job_level: 1)
    insert_items(character.id, [{984, 4}, {999, 40}, {726, 1}, {1000, 3}, {@oridecon_hammer, 1}])
    session = start_session(character)

    use_item(session, @oridecon_hammer)
    assert_receive {:packet_sent, %SkillMenu{src_skill_id: @menu, entry_ids: entries}, _}, 1_000
    assert 1219 in entries

    reply(session, 1219, [1000, 1000, 1000])
    assert_receive {:packet_sent, %ProductionResult{success: false, item_id: 1219}, _}, 1_000

    inventory = get_player_state(session.pid).inventory
    assert Inventory.held_amount(inventory, 984) == 0
    assert Inventory.held_amount(inventory, 999) == 0
    assert Inventory.held_amount(inventory, 726) == 0
    assert Inventory.held_amount(inventory, 1000) == 0
    assert Inventory.held_amount(inventory, 1219) == 0
  end

  test "the iron hammer offers only tier-one weapons and drops an unoffered reply" do
    character = insert_blacksmith(%{98 => 3})

    insert_items(character.id, [
      {998, 50},
      {909, 10},
      {984, 4},
      {999, 40},
      {726, 1},
      {@iron_hammer, 1}
    ])

    session = start_session(character)

    use_item(session, @iron_hammer)

    assert_receive {:packet_sent, %SkillMenu{src_skill_id: @menu, entry_ids: [1201, 1204, 1207]},
                    _},
                   1_000

    reply(session, 1219, [])
    refute_receive {:packet_sent, %ProductionResult{}, _}, 100
    assert Process.alive?(session.pid)
    assert Inventory.held_amount(get_player_state(session.pid).inventory, 984) == 4
  end

  test "the furnace offers the held mineral recipes and Star Crumb always succeeds" do
    Application.put_env(:zone_server, :forge_rng, fn upper -> upper end)
    character = insert_blacksmith(%{94 => 1, 95 => 1, 96 => 1})
    insert_items(character.id, [{1001, 10}, {1002, 1}, {990, 10}, {@furnace, 1}])
    session = start_session(character)

    use_item(session, @furnace)

    assert_receive {:packet_sent, %SkillMenu{src_skill_id: @menu, entry_ids: [998, 1000, 994]},
                    _},
                   1_000

    reply(session, 1000, [])
    assert_receive {:packet_sent, %ProductionResult{success: true, item_id: 1000}, _}, 1_000

    inventory = get_player_state(session.pid).inventory
    assert Inventory.held_amount(inventory, 1000) == 1
    assert Inventory.held_amount(inventory, @furnace) == 0
  end

  # Regression guard for a silent item-loss bug in the shared inventory staging
  # drain. A forge stages its material consumption against a snapshot taken
  # before the product is added. When the product stacks onto a DIFFERENT slot
  # that already holds the same item, that snapshot is stale for the product's
  # slot. Reflecting the persisted snapshot back over the final inventory then
  # overwrote the product slot with its pre-craft amount, leaving memory and the
  # database disagreeing - and the next removal persisted the wrong amount.
  test "a forge whose product stacks onto an existing slot keeps memory and database in step" do
    Application.put_env(:zone_server, :forge_rng, fn _upper -> 1 end)
    character = insert_blacksmith(%{94 => 1})
    # An existing Iron stack the product will merge into, plus the ore to refine.
    insert_items(character.id, [{998, 3}, {1002, 1}, {@furnace, 1}])
    session = start_session(character)

    use_item(session, @furnace)
    assert_receive {:packet_sent, %SkillMenu{src_skill_id: @menu, entry_ids: [998]}, _}, 1_000

    reply(session, 998, [])
    assert_receive {:packet_sent, %ProductionResult{success: true, item_id: 998}, _}, 1_000

    in_memory = get_player_state(session.pid).inventory
    persisted = character.id |> Persistence.load_inventory() |> Enum.group_by(& &1.nameid)

    persisted_iron = persisted |> Map.get(998, []) |> Enum.map(& &1.amount) |> Enum.sum()
    persisted_ore = persisted |> Map.get(1002, []) |> Enum.map(& &1.amount) |> Enum.sum()

    assert Inventory.held_amount(in_memory, 998) == 4
    assert persisted_iron == 4
    assert Inventory.held_amount(in_memory, 1002) == 0
    assert persisted_ore == 0
    assert Map.get(persisted, @furnace, []) == []
  end

  test "all ten craft declarations expose the shared active and menu callbacks" do
    for skill_id <- @craft_skills do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert {:ok, module} = Catalog.active_module_for(definition.name)
      assert {:ok, ^module} = Catalog.menu_module_for(definition.name)
      assert function_exported?(module, :cast, 4)
      assert function_exported?(module, :on_menu_reply, 3)
    end
  end

  defp use_item(session, nameid) do
    {index, _item} =
      Enum.find(get_player_state(session.pid).inventory, fn {_index, item} ->
        item.nameid == nameid
      end)

    simulate_incoming_message(session.pid, %UseItem{index: PlayerState.client_index(index)})
  end

  defp reply(session, product_id, extras) do
    simulate_incoming_message(session.pid, %SkillMenuReply{
      src_skill_id: @menu,
      selected_id: product_id,
      extra_ids: extras
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

  defp insert_blacksmith(learned, overrides \\ []) do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        username: "forge#{unique}",
        userid: "forge#{unique}",
        user_pass: "password",
        email: "forge#{unique}@aesir.test"
      })
      |> Repo.insert!()

    attrs = %{
      account_id: account.id,
      char_num: 0,
      name: "Forge#{unique}",
      class: 10,
      base_level: 99,
      job_level: 70,
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

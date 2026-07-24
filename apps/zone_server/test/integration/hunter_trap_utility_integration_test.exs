defmodule Aesir.ZoneServer.Integration.HunterTrapUtilityIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.ItemAdded
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence

  @map "prontera"
  @hunter_class 11
  @remove_trap 124
  @falcon 127
  @spring_trap 131
  @trap_item 1065
  @origin {150, 150}

  test "concurrent Remove Trap requests reward one owned armed trap exactly once" do
    character = insert_hunter(%{learned_skills: skills(%{@remove_trap => 1})})
    session = start_hunter_session(character, @origin)
    target = {151, 150}

    assert :ok = Manager.register(trap_group(1, character.id, target))
    flush_packets()

    cast_concurrently([session, session], @remove_trap, 1, target)

    state = get_player_state(session.pid)
    assert Inventory.held_amount(state.inventory, @trap_item) == 1
    assert state.stats.current_state.sp == 95
    assert nil == Storage.get(1)

    assert [%ItemAdded{nameid: @trap_item, amount: 1}] =
             collect_packets_of_type(ItemAdded, 200)

    assert [persisted] = Persistence.load_inventory(character.id)
    assert persisted.nameid == @trap_item
    assert persisted.amount == 1
  end

  test "Remove Trap grants nothing for missing, foreign, spent, unsupported, or full targets" do
    character = insert_hunter(%{learned_skills: skills(%{@remove_trap => 1})})
    session = start_hunter_session(character, @origin)

    spent = Map.merge(armed_state(), %{armed: false, reclaimable: false})

    assert :ok = Manager.register(trap_group(10, character.id + 1, {151, 150}))
    assert :ok = Manager.register(trap_group(11, character.id, {150, 151}, spent))
    assert :ok = Manager.register(trap_group(12, character.id, {149, 150}, %{base_damage: 100}))

    for target <- [{150, 149}, {151, 150}, {150, 151}, {149, 150}] do
      cast_and_sync(session, @remove_trap, 1, target)
    end

    state = get_player_state(session.pid)
    assert Inventory.held_amount(state.inventory, @trap_item) == 0
    assert state.stats.current_state.sp == 100
    assert Enum.all?(10..12, &match?(%Group{}, Storage.get(&1)))
    assert Persistence.load_inventory(character.id) == []

    full_character = insert_hunter(%{learned_skills: skills(%{@remove_trap => 1})})
    seed_full_inventory(full_character.id)
    full_session = start_hunter_session(full_character, {160, 160})

    assert :ok = Manager.register(trap_group(20, full_character.id, {161, 160}))
    flush_packets()

    full_state = cast_and_sync(full_session, @remove_trap, 1, {161, 160})

    assert map_size(full_state.inventory) == Inventory.capacity()
    assert Inventory.held_amount(full_state.inventory, @trap_item) == 0
    assert full_state.stats.current_state.sp == 100
    assert %Group{state: %{armed: true, reclaimable: true}} = Storage.get(20)
    assert collect_packets_of_type(ItemAdded, 100) == []
  end

  test "Spring Trap gates Falcon and range, races once across sessions, and expires spent without reward" do
    target = {155, 150}
    learned = skills(%{@falcon => 1, @remove_trap => 1, @spring_trap => 2})
    no_falcon_character = insert_hunter(%{learned_skills: learned})
    no_falcon = start_hunter_session(no_falcon_character, @origin)

    assert :ok = Manager.register(trap_group(30, no_falcon_character.id + 999, target))

    no_falcon_state = cast_and_sync(no_falcon, @spring_trap, 2, target)
    assert no_falcon_state.stats.current_state.sp == 100
    assert %Group{state: %{armed: true, reclaimable: true}} = Storage.get(30)

    falcon_option = Option.id(:falcon)
    first_character = insert_hunter(%{learned_skills: learned, option: falcon_option})
    second_character = insert_hunter(%{learned_skills: learned, option: falcon_option})
    first = start_hunter_session(first_character, @origin)
    second = start_hunter_session(second_character, @origin)

    level_one_state = cast_and_sync(first, @spring_trap, 1, target)
    assert level_one_state.stats.current_state.sp == 100
    assert %Group{state: %{armed: true, reclaimable: true}} = Storage.get(30)

    flush_packets()
    cast_concurrently([first, second], @spring_trap, 2, target)

    first_state = get_player_state(first.pid)
    second_state = get_player_state(second.pid)
    assert first_state.stats.current_state.sp + second_state.stats.current_state.sp == 190
    assert Inventory.held_amount(first_state.inventory, @trap_item) == 0
    assert Inventory.held_amount(second_state.inventory, @trap_item) == 0

    assert %Group{
             visible?: true,
             expires_at: expires_at,
             state: %{armed: false, reclaimable: false}
           } = Storage.get(30)

    remover_character = insert_hunter(%{learned_skills: skills(%{@remove_trap => 1})})
    remover = start_hunter_session(remover_character, {154, 150})
    remover_state = cast_and_sync(remover, @remove_trap, 1, target)

    assert remover_state.stats.current_state.sp == 100
    assert Inventory.held_amount(remover_state.inventory, @trap_item) == 0
    assert Persistence.load_inventory(remover_character.id) == []
    assert collect_packets_of_type(ItemAdded, 100) == []

    assert :ok = Manager.tick(Manager, expires_at - 1)
    assert %Group{} = Storage.get(30)
    assert :ok = Manager.tick(Manager, expires_at)
    assert nil == Storage.get(30)
  end

  defp start_hunter_session(character, position) do
    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp insert_hunter(overrides) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "trap#{uniq}",
        userid: "trap#{uniq}",
        user_pass: "password",
        email: "trap#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "Trapper#{uniq}",
          class: @hunter_class,
          base_level: 50,
          job_level: 50,
          str: 10,
          agi: 10,
          vit: 10,
          int: 10,
          dex: 10,
          luk: 10,
          hp: 500,
          max_hp: 500,
          sp: 100,
          max_sp: 100,
          last_map: @map,
          last_x: elem(@origin, 0),
          last_y: elem(@origin, 1),
          save_map: @map,
          save_x: elem(@origin, 0),
          save_y: elem(@origin, 1)
        },
        overrides
      )

    {:ok, character} =
      %Character{}
      |> Character.changeset(attrs)
      |> Repo.insert()

    character
  end

  defp skills(levels) do
    Map.new(levels, fn {id, level} -> {Integer.to_string(id), level} end)
  end

  defp trap_group(group_id, owner_id, {x, y}, state \\ armed_state()) do
    now = System.monotonic_time(:millisecond)

    %Group{
      group_id: group_id,
      skill_id: 116,
      skill_name: :ht_landmine,
      level: 1,
      caster_id: owner_id,
      caster_type: :player,
      map_name: @map,
      center: {x, y},
      cells: [{x, y}],
      next_tick_at: now + 60_000,
      expires_at: now + 60_000,
      interval: 1_000,
      visible?: false,
      state: state
    }
  end

  defp armed_state do
    %{base_damage: 100, armed: true, reclaimable: true, trap_item: @trap_item}
  end

  defp seed_full_inventory(character_id) do
    Enum.each(1..Inventory.capacity(), fn index ->
      assert {:ok, _item} =
               Persistence.insert_item(character_id, %{nameid: 900_000 + index, amount: 1})
    end)
  end

  defp cast_and_sync(session, skill_id, level, {x, y}) do
    simulate_incoming_message(session.pid, %GroundSkillCast{
      skill_id: skill_id,
      level: level,
      x: x,
      y: y
    })

    get_player_state(session.pid)
  end

  defp cast_concurrently(sessions, skill_id, level, {x, y}) do
    sessions
    |> Enum.map(fn session ->
      Task.async(fn ->
        simulate_incoming_message(session.pid, %GroundSkillCast{
          skill_id: skill_id,
          level: level,
          x: x,
          y: y
        })

        get_player_state(session.pid)
      end)
    end)
    |> Task.await_many(2_000)
  end
end

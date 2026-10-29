defmodule Aesir.ZoneServer.Integration.CreatorSkillsIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobSkill.Db
  alias Aesir.ZoneServer.Mmo.MobSkill.Selector
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    for key <- [:forge_rng, :cultivation_rng] do
      previous = Application.get_env(:zone_server, key)

      on_exit(fn ->
        if previous,
          do: Application.put_env(:zone_server, key, previous),
          else: Application.delete_env(:zone_server, key)
      end)
    end

    :ok
  end

  test "Slim Pitcher heals the caster's party member and not a stranger" do
    caster = start_creator(learned: %{"478" => 1}, items: [{545, 2}], position: {150, 150})
    member = start_creator(name: "SlimMember", position: {152, 150})
    stranger = start_creator(name: "SlimStranger", position: {151, 151})
    set_party(caster.pid, 7)
    set_party(member.pid, 7)
    damage_to(member.pid, 1)
    damage_to(stranger.pid, 1)

    simulate_incoming_message(caster.pid, %GroundSkillCast{
      skill_id: 478,
      level: 1,
      x: 151,
      y: 150
    })

    assert_eventually(fn -> current_hp(member.pid) > 1 end, 4_000)
    assert current_hp(stranger.pid) == 1
    assert held(caster.pid, 545) == 1
  end

  test "Full Protection coats every piece another player wears" do
    caster = start_creator(learned: %{"479" => 1}, items: [{7139, 1}], position: {150, 150})

    target =
      start_creator(
        name: "FpTarget",
        position: {151, 150},
        items: [{1101, 1, 2}, {2301, 1, 16}]
      )

    target_id = target.character.id
    on_exit(fn -> StatusStorage.clear_unit_statuses(:player, target_id) end)

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: 479,
      level: 1,
      target_id: target_id
    })

    assert_eventually(
      fn ->
        StatusStorage.has_status?(:player, target_id, :sc_cp_weapon) and
          StatusStorage.has_status?(:player, target_id, :sc_cp_armor)
      end,
      4_000
    )

    refute StatusStorage.has_status?(:player, target_id, :sc_cp_shield)
    assert held(caster.pid, 7139) == 0
  end

  test "Acid Demonstration damages a monster and spends both bottles" do
    caster =
      start_creator(
        learned: %{"490" => 1},
        items: [{7135, 1}, {7136, 1}],
        position: {150, 150},
        int: 50
      )

    Mimic.allow(HitCalculations, self(), caster.pid)
    mob = spawn_test_mob(@map, {153, 150}, mob_id: 1002)
    mob_state = get_mob_state(mob.pid)
    initial_hp = mob_state.hp

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: 490,
      level: 1,
      target_id: mob_state.instance_id
    })

    assert_eventually(
      fn ->
        state = UnitRegistry.get_unit(:mob, mob_state.instance_id)
        not match?({:ok, {_module, %MobState{hp: ^initial_hp}, _pid}}, state)
      end,
      4_000
    )

    assert held(caster.pid, 7135) == 0
    assert held(caster.pid, 7136) == 0
  end

  @tag game_mode: :renewal, integration_pre_re: false
  test "Flamel casts Acid Demonstration on a player with its own INT" do
    target =
      start_player_session(
        id: 9_874,
        name: "AcidMobTarget",
        map_name: @map,
        position: {161, 150},
        hp: 1_000_000,
        max_hp: 1_000_000
      )

    initial_hp = current_hp(target.pid)
    row = Enum.find(Db.rows_for(2_222), &(&1.skill == "CR_ACIDDEMONSTRATION"))
    assert row, "Flamel keeps its Acid Demonstration row"

    flamel = spawn_test_mob(@map, {158, 150}, mob_id: 2_222)
    Mimic.allow(HitCalculations, self(), flamel.pid)
    drive_selected_cast(flamel, row, {:player, target.character.id})

    assert_eventually(fn -> current_hp(target.pid) < initial_hp end, 3_000)
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "Plant Cultivation grows the drawn mushroom on the cell" do
    # Towns refuse the skill, so it grows on a field.
    field = "prt_fild08"
    start_per_test_map(field)

    caster =
      start_creator(learned: %{"491" => 1}, items: [{921, 1}], position: {150, 150}, map: field)

    Application.put_env(:zone_server, :cultivation_rng, fn
      100 -> 51
      2 -> 1
    end)

    simulate_incoming_message(caster.pid, %GroundSkillCast{
      skill_id: 491,
      level: 1,
      x: 151,
      y: 150
    })

    assert_eventually(
      fn ->
        field
        |> SpatialIndex.units_in_area(151, 150, 151, 150)
        |> Enum.any?(fn
          {:mob, id} ->
            match?({:ok, {_, %MobState{mob_id: 1_084}, _}}, UnitRegistry.get_unit(:mob, id))

          _other ->
            false
        end)
      end,
      4_000
    )

    assert held(caster.pid, 921) == 0
  end

  test "Twilight Alchemy 1 brews 200 White Potions once granted, never with a Pharmacy list open" do
    materials = [{7134, 400}, {7144, 1}, {509, 400}, {1093, 400}]

    caster =
      start_creator(
        learned: %{"228" => 10, "496" => 1},
        items: materials,
        position: {150, 150},
        sp: 500,
        str: 99
      )

    Application.put_env(:zone_server, :forge_rng, fn _upper -> 1 end)

    :sys.replace_state(caster.pid, fn state ->
      %{state | pending_skill_menu: %{skill_id: 228, kind: :ITEMS, entry_ids: [], level: 10}}
    end)

    cast_self(caster, 496)
    barrier(caster.pid)
    assert held(caster.pid, 7134) == 400
    assert current_sp(caster.pid) == 500

    :sys.replace_state(caster.pid, &%{&1 | pending_skill_menu: nil})
    cast_self(caster, 496)

    assert_eventually(fn -> held(caster.pid, 504) == 200 end, 6_000)
    assert held(caster.pid, 7134) == 200
    assert held(caster.pid, 509) == 200
    assert current_sp(caster.pid) == 300
  end

  defp start_creator(opts) do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "cr_#{unique}",
        user_pass: "password",
        email: "creator-#{unique}@example.com"
      })
      |> Repo.insert!()

    {x, y} = Keyword.fetch!(opts, :position)

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: Keyword.get(opts, :name, "Creator#{unique}"),
        class: 4_019,
        base_level: 99,
        job_level: 50,
        hp: 5_000,
        max_hp: 5_000,
        sp: Keyword.get(opts, :sp, 300),
        max_sp: Keyword.get(opts, :sp, 300),
        str: Keyword.get(opts, :str, 1),
        int: Keyword.get(opts, :int, 1),
        dex: 99,
        learned_skills: Keyword.get(opts, :learned, %{}),
        last_map: Keyword.get(opts, :map, @map),
        last_x: x,
        last_y: y
      })
      |> Repo.insert!()

    for item <- Keyword.get(opts, :items, []), do: insert_item(character.id, item)

    character = Repo.preload(character, [:inventory_items, :homunculus])

    session =
      start_player_session(
        character: character,
        map_name: Keyword.get(opts, :map, @map),
        position: {x, y}
      )

    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    flush_packets()
    session
  end

  defp insert_item(character_id, {item_id, amount}),
    do: insert_item(character_id, {item_id, amount, 0})

  defp insert_item(character_id, {item_id, amount, equip}) do
    %InventoryItem{}
    |> InventoryItem.changeset(%{
      char_id: character_id,
      nameid: item_id,
      amount: amount,
      equip: equip,
      identify: 1
    })
    |> Repo.insert!()
  end

  defp drive_selected_cast(mob, row, target_ref) do
    test_pid = self()
    now = System.system_time(:millisecond)

    :sys.replace_state(mob.pid, fn state ->
      skill_state =
        case row.state do
          :attack -> :berserk
          :angry -> :angry
          :chase -> :rush
          :idle -> :idle
        end

      state =
        state
        |> Map.put(:skill_state, skill_state)
        |> MobState.set_target(elem(target_ref, 1))
        |> Map.put(:target_ref, target_ref)

      selected = Selector.select(state, [row], now: now, rng: fn _maximum -> 1 end)
      send(test_pid, {:selected_row, selected})

      case selected do
        {:cast, selected_row} ->
          {:ok, updated} = CastingHandler.begin_cast(state, selected_row, now)
          updated

        nil ->
          state
      end
    end)

    assert_receive {:selected_row, selected}
    assert {:cast, %{skill_id: 490}} = selected
    if row.cast_time > 0, do: send(mob.pid, {:casting, :complete})
  end

  defp set_party(pid, party_id) do
    :sys.replace_state(pid, fn state ->
      StateCommit.commit(state, %{state.game_state | party_id: party_id})
    end)
  end

  defp damage_to(pid, hp) do
    state = PlayerSession.get_state(pid).game_state
    PlayerSession.apply_damage(pid, state.stats.current_state.hp - hp, nil)
    assert_eventually(fn -> current_hp(pid) == hp end)
  end

  defp cast_self(session, skill_id),
    do:
      simulate_incoming_message(session.pid, %SkillCast{
        skill_id: skill_id,
        level: 1,
        target_id: session.character.id
      })

  defp barrier(pid), do: PlayerSession.get_state(pid)
  defp held(pid, item_id), do: Inventory.held_amount(barrier(pid).game_state.inventory, item_id)
  defp current_hp(pid), do: barrier(pid).game_state.stats.current_state.hp
  defp current_sp(pid), do: barrier(pid).game_state.stats.current_state.sp
end

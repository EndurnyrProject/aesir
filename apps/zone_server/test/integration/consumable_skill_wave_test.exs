defmodule Aesir.ZoneServer.Integration.ConsumableSkillWaveTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ItemSkillReady
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup {Aesir.MimicMode, :global}

  setup do
    ScriptCompiler.compile_all!()
    Mimic.copy(Invincibility)
    stub(Invincibility, :default_time, fn -> 60_000 end)
    :ok
  end

  test "delayed scroll ingress claims once, preserves staged levels and settles party recipients" do
    caster_character = character()
    ally_character = character()
    far_character = character()
    protected_character = character()
    assert {:ok, party} = PartyManager.create("CW#{caster_character.id}", caster_character)
    assert {:ok, _} = PartyManager.add_member(party.party_id, ally_character)
    assert {:ok, _} = PartyManager.add_member(party.party_id, far_character)
    assert {:ok, _} = PartyManager.add_member(party.party_id, protected_character)
    on_exit(fn -> ClusterTestHelper.clear_all() end)

    for id <- [606, 14_588, 14_589, 14_590, 12_311] do
      assert {:ok, _} =
               Persistence.insert_item(caster_character.id, %{nameid: id, amount: 2, identify: 1})
    end

    caster = start_member(caster_character, {150, 150})
    ally = start_member(ally_character, {164, 164}, connection_pid: self())
    far = start_member(far_character, {165, 164}, connection_pid: self())

    protected =
      start_member(protected_character, {152, 150}, invincible: true, connection_pid: self())

    id = caster.character.id
    initial_sp = get_player_state(caster.pid).stats.current_state.sp
    initial_hit = get_player_state(caster.pid).stats.combat_stats.hit
    initial_def = get_player_state(caster.pid).stats.combat_stats.def
    flush_packets()

    before = System.monotonic_time(:millisecond)
    cast_item(caster, 606, 473, 1)
    after_cast = System.monotonic_time(:millisecond)
    assert %{val1: 1, expires_at: expires_at} = StatusStorage.get_status(:player, id, :sc_provoke)
    assert expires_at >= before + 30_000 and expires_at <= after_cast + 30_000
    assert get_player_state(caster.pid).stats.combat_stats.hit == initial_hit
    assert get_player_state(caster.pid).stats.combat_stats.def == initial_def
    self_effects = collect_packets_of_type(SkillEffect)
    assert [%SkillEffect{skill_id: 6, level: 1, target_id: ^id}] = self_effects
    refute_receive {:packet_sent, %SkillEffect{skill_id: 473}, _}, 0

    for {item, skill, level, status} <- [
          {14_588, 689, 10, :sc_blessing},
          {14_589, 690, 10, :sc_increaseagi},
          {14_590, 691, 5, :sc_assumptio}
        ] do
      flush_packets()
      cast_item(caster, item, skill, level)

      assert eventually(fn ->
               StatusStorage.has_status?(:player, ally.character.id, status) and
                 get_player_state(ally.pid).stats.modifiers.status_effects ==
                   StatusInterpreter.get_all_modifiers(:player, ally.character.id)
             end)

      for recipient <- [caster, ally] do
        assert %{val1: ^level, source_id: ^id} =
                 StatusStorage.get_status(:player, recipient.character.id, status)
      end

      refute StatusStorage.has_status?(:player, far.character.id, status)
      assert Invincibility.active?({:player, protected.character.id})
      refute StatusStorage.has_status?(:player, protected.character.id, status)
      effects = collect_packets_of_type(SkillEffect)
      assert Enum.any?(effects, &(&1.skill_id == skill and &1.target_id == id and &1.result == 1))

      assert Enum.any?(
               effects,
               &(&1.skill_id == skill and &1.target_id == ally.character.id and &1.result == 1)
             )
    end

    flush_packets()
    level = if GameMode.mode() == :renewal, do: 5, else: 1
    flee = get_player_state(caster.pid).stats.combat_stats.flee
    cast_item(caster, 12_311, 693, level)

    assert Enum.any?(
             collect_packets_of_type(SkillEffect),
             &match?(%SkillEffect{skill_id: 693, level: ^level}, &1)
           )

    assert eventually(fn -> not StatusStorage.has_status?(:player, id, :sc_partyflee) end)
    assert get_player_state(caster.pid).stats.combat_stats.flee == flee
    assert get_player_state(caster.pid).stats.current_state.sp == initial_sp
    assert Process.alive?(caster.pid)
  end

  test "solo Party Flee spends one claimed item, arms cooldown and refuses another claim" do
    character = character()

    assert {:ok, _} =
             Persistence.insert_item(character.id, %{nameid: 12_311, amount: 2, identify: 1})

    caster = start_member(character, {150, 150})
    baseline = get_player_state(caster.pid).stats
    level = if GameMode.mode() == :renewal, do: 5, else: 1
    flush_packets()
    before = System.monotonic_time(:millisecond)
    cast_item(caster, 12_311, 693, level)
    after_cast = System.monotonic_time(:millisecond)
    assert %SkillCastFailed{skill_id: 693} = assert_packet_sent(SkillCastFailed)
    state = get_player_state(caster.pid)
    cooldown = state.skill_cooldowns[693]

    assert cooldown >= before + 300_000 and cooldown <= after_cast + 300_000,
           "cooldown=#{inspect(cooldown)}, before=#{before}, after=#{after_cast}"

    assert state.stats.generation == baseline.generation
    assert state.stats.combat_stats.flee == baseline.combat_stats.flee
    refute StatusStorage.has_status?(:player, character.id, :sc_partyflee)
    flush_packets()

    stage_item(caster, 12_311, 693, level)

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: 693,
      level: 99,
      target_id: character.id
    })

    PlayerSession.get_state(caster.pid)
    assert amount(caster, 12_311) == 1
    assert get_player_state(caster.pid).skill_cooldowns[693] == cooldown
    assert Enum.find(Persistence.load_inventory(character.id), &(&1.nameid == 12_311)).amount == 1
    assert collect_packets_of_type(ItemRemoved) == []
  end

  defp cast_item(caster, item, skill, level) do
    count = amount(caster, item)
    stage_item(caster, item, skill, level)

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: skill,
      level: 99,
      target_id: caster.character.id
    })

    PlayerSession.get_state(caster.pid)
    assert eventually(fn -> amount(caster, item) == count - 1 end)
    assert PlayerSession.get_state(caster.pid).pending_item_skill == nil
    assert [%ItemRemoved{amount: 1}] = collect_packets_of_type(ItemRemoved)
    assert amount(caster, item) == count - 1
  end

  defp stage_item(caster, item, skill, level) do
    count = amount(caster, item)

    {index, _} =
      Enum.find(get_player_state(caster.pid).inventory, fn {_index, row} -> row.nameid == item end)

    simulate_incoming_message(caster.pid, %UseItem{index: PlayerState.client_index(index)})
    PlayerSession.get_state(caster.pid)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)

    assert %ItemSkillReady{skill_id: ^skill, level: ^level, target_kind: :SELF} =
             assert_packet_sent(ItemSkillReady)

    assert amount(caster, item) == count

    assert %{skill_id: ^skill, level: ^level} =
             PlayerSession.get_state(caster.pid).pending_item_skill
  end

  defp amount(caster, item) do
    get_player_state(caster.pid).inventory
    |> Map.values()
    |> Enum.filter(&(&1.nameid == item))
    |> Enum.reduce(0, &(&1.amount + &2))
  end

  defp start_member(character, position, opts \\ []) do
    session =
      start_player_session(
        [character: Repo.get!(Character, character.id), position: position] ++ opts
      )

    on_exit(fn -> if Process.alive?(session.pid), do: GenServer.stop(session.pid, :normal) end)
    session
  end

  defp character do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "cw#{unique}",
        user_pass: "password",
        email: "cw#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "CW#{unique}",
      class: 0,
      base_level: 50,
      job_level: 10,
      learned_skills: %{"1" => 3},
      str: 1,
      agi: 1,
      vit: 0,
      int: 1,
      dex: 1,
      luk: 0,
      hp: 200,
      sp: 50,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150
    })
    |> Repo.insert!()
  end
end

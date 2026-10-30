defmodule Aesir.ZoneServer.Integration.WhitesmithCartTerminationIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence

  test "real_cart_termination_charges_and_honors_defenses" do
    session = start_player_session(character: character())
    on_exit(fn -> end_player_session(session) end)
    target = start_mob_session(position: {151, 150}, max_hp: 10_000, vit: 0, luk: 0)

    stub(DamageCalculator, :calculate_damage, fn _, _, _ ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)
    stub(Resistance, :roll_rate, fn _ -> true end)

    for module <- [DamageCalculator, HitCalculations, Resistance],
        do: Mimic.allow(module, self(), session.pid)

    before = get_player_state(session.pid)
    cast(session, target.unit_id)
    assert_receive {:packet_sent, %SkillCastFailed{skill_id: 485}, _}, 1_000
    assert get_player_state(session.pid).stats.current_state.sp == before.stats.current_state.sp
    assert get_player_state(session.pid).zeny == before.zeny

    assert :ok = PlayerSession.apply_status(session.pid, :sc_cartboost, val1: 1, duration: 60_000)
    cast(session, target.unit_id)
    assert eventually(fn -> StatusStorage.has_status?(:mob, target.unit_id, :sc_stun) end)
    paid = get_player_state(session.pid)
    price = if GameMode.mode() == :renewal, do: 1_200, else: 1_500
    assert paid.zeny == before.zeny - price
    assert paid.stats.current_state.sp == before.stats.current_state.sp - 15
    assert StatusStorage.has_status?(:player, session.character.id, :sc_cartboost)

    Interpreter.remove_status(:mob, target.unit_id, :sc_stun)
    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :miss end)
    cast(session, target.unit_id)
    assert eventually(fn -> get_player_state(session.pid).zeny == before.zeny - 2 * price end)
    refute StatusStorage.has_status?(:mob, target.unit_id, :sc_stun)
    assert StatusStorage.has_status?(:player, session.character.id, :sc_cartboost)

    plain_char =
      character() |> Character.changeset(%{learned_skills: %{"485" => 10}}) |> Repo.update!()

    plain = start_player_session(character: plain_char)
    on_exit(fn -> end_player_session(plain) end)

    for module <- [DamageCalculator, HitCalculations, Resistance],
        do: Mimic.allow(module, self(), plain.pid)

    assert :ok = PlayerSession.apply_status(plain.pid, :sc_cartboost, val1: 1, duration: 60_000)
    cast(plain, target.unit_id)
    assert eventually(fn -> get_player_state(plain.pid).zeny == plain_char.zeny - 1_500 end)
  end

  test "delayed_devotion_blocks_cart_termination_stun" do
    devotee = start_player_session(character: character())
    crusader = start_player_session(character: character(), position: {151, 150})

    on_exit(fn ->
      end_player_session(devotee)
      end_player_session(crusader)
    end)

    source = start_mob_session(position: {149, 150})

    stub(DamageCalculator, :calculate_damage, fn _, _, _ ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)
    stub(Resistance, :roll_rate, fn _ -> flunk("delayed Devotion hit attempted native stun") end)
    link = make_ref()

    :ok =
      StatusStorage.apply_status(:player, devotee.character.id, :sc_devotion,
        state: %{peer: {:player, crusader.character.id}, link_id: link, range: 7}
      )

    :ok =
      StatusStorage.apply_status(:player, crusader.character.id, :sc_devoted_by,
        state: %{
          links: %{
            devotee.character.id => %{peer: {:player, devotee.character.id}, link_id: link}
          }
        }
      )

    hp = get_player_state(crusader.pid).stats.current_state.hp
    state = %{get_mob_state(source.pid) | target_ref: {:player, devotee.character.id}}

    assert :ok =
             Executor.execute(state, %{
               skill_id: 485,
               skill: :ws_carttermination,
               level: 10,
               target: :target
             })

    assert eventually(fn -> get_player_state(crusader.pid).stats.current_state.hp == hp - 40 end)
    refute StatusStorage.has_status?(:player, devotee.character.id, :sc_stun)
    refute StatusStorage.has_status?(:player, crusader.character.id, :sc_stun)
  end

  test "real_defenses_skip_status_returns_but_keep_equipment_returns" do
    char = character() |> Character.changeset(%{class: 8}) |> Repo.update!()

    {:ok, _hat} =
      Persistence.insert_item(char.id, %{nameid: 5_133, amount: 1, identify: 1, equip: 256})

    target = start_player_session(character: char)
    on_exit(fn -> end_player_session(target) end)
    source = start_mob_session(position: {149, 150}, max_hp: 100_000, level: 99)

    stub(DamageCalculator, :calculate_damage, fn _, _, _ ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)
    stub(Resistance, :roll_rate, fn _ -> true end)

    for status <- [:sc_parrying, :sc_energycoat, :sc_reflectshield] do
      assert :ok = PlayerSession.apply_status(target.pid, status, val1: 10, duration: 60_000)
    end

    before = get_player_state(target.pid)
    assert before.stats.modifiers.equipment.short_weapon_damage_return == 5
    source_hp = get_mob_state(source.pid).hp
    state = %{get_mob_state(source.pid) | target_ref: {:player, char.id}}
    row = %{skill_id: 485, skill: :ws_carttermination, level: 10, target: :target}
    assert :ok = Executor.execute(state, row)

    assert eventually(fn ->
             get_player_state(target.pid).stats.current_state.hp ==
               before.stats.current_state.hp - 40
           end)

    assert get_player_state(target.pid).stats.current_state.sp == before.stats.current_state.sp
    assert eventually(fn -> get_mob_state(source.pid).hp == source_hp - 2 end)
    assert StatusStorage.has_status?(:player, char.id, :sc_stun)
    Interpreter.remove_status(:player, char.id, :sc_stun)
    assert :ok = PlayerSession.apply_status(target.pid, :sc_autoguard, val1: 10, duration: 60_000)
    :rand.seed(:exsss, {1, 2, 3})
    assert :ok = Executor.execute(state, row)

    assert StatusStorage.has_status?(:player, char.id, :sc_stun) ==
             (GameMode.mode() == :pre_renewal)
  end

  defp cast(session, target),
    do:
      simulate_incoming_message(session.pid, %SkillCast{
        skill_id: 485,
        level: 10,
        target_id: target
      })

  defp character do
    id = System.unique_integer([:positive])

    account =
      Repo.insert!(%Account{userid: "ct#{id}", user_pass: "unused", email: "ct@test.local"})

    Repo.insert!(%Character{
      account_id: account.id,
      char_num: 0,
      name: "CartSmith#{id}",
      class: 4011,
      base_level: 99,
      job_level: 70,
      hp: 5_000,
      max_hp: 5_000,
      sp: 500,
      max_sp: 500,
      zeny: 100_000,
      learned_skills: %{"485" => 10, "1012" => 1},
      last_map: "prontera",
      last_x: 150,
      last_y: 150
    })
  end
end

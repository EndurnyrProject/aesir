defmodule Aesir.ZoneServer.Integration.WinkCharmIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession

  @map "wink_charm_live"
  @dancer_class 20
  @wink_charm 1011

  setup do
    Mimic.copy(Resistance)
    stub(Resistance, :roll_success, fn _effective_rate -> true end)

    map_cache = EtsTable.table_for(:map_cache)
    :ets.insert(map_cache, {@map, MapData.new(@map, 200, 200)})

    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "a live mob drops the charmer, then acquires and attacks another player" do
    dancer = start_dancer("Protected", {150, 150})
    other = start_player("Other", {152, 150})
    mob = start_charmable_mob(awake: false)

    MobSession.set_target(mob.pid, dancer.character.id)
    assert eventually(fn -> mob_target(mob) == {:player, dancer.character.id} end)

    # Charm has a ~1s cast that damage interrupts (health_handler cancels casts).
    # An awake mob attacking the adjacent dancer would race and cancel the cast,
    # so the status intermittently never landed. Cast while the mob is dormant,
    # then wake it to exercise the real autonomous drop-and-reacquire behaviour.
    charm(dancer, mob)
    MobSession.wake(mob.pid)
    force_ticks(mob, 3)

    # The charmer must be released. Asserting the transient `target_ref == nil`
    # state is a race: an aggressive mob re-acquires the other nearby player in
    # the same or next tick, so the null moment can be skipped entirely. The
    # stable, meaningful outcome is that the mob no longer targets the charmer.
    assert eventually(fn -> mob_target(mob) != {:player, dancer.character.id} end)

    flush_packets()
    force_ticks(mob, 3)

    assert eventually(fn -> mob_target(mob) == {:player, other.character.id} end)

    assert_receive {:packet_sent, %DamageDealt{src_id: source_id, target_id: target_id}, _},
                   2_000

    assert source_id == mob.unit_id
    assert target_id == other.character.id
  end

  test "non-zero damage from another source breaks charm and restores Dancer targeting" do
    dancer = start_dancer("DamageCharm", {150, 150})
    source = start_player("DamageSource", {152, 150})
    mob = start_charmable_mob()

    charm(dancer, mob)
    assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_winkcharm)

    DamageApplication.apply_unit_damage(
      :mob,
      mob.pid,
      mob.unit_id,
      1,
      %{damage: 1, dmg_type: :physical, is_short: true, from_caster?: false},
      source.character.id
    )

    assert eventually(fn -> not StatusStorage.has_status?(:mob, mob.unit_id, :sc_winkcharm) end)

    end_player_session(source)
    assert eventually(fn -> not Process.alive?(source.pid) end)

    MobSession.set_target(mob.pid, nil)
    assert eventually(fn -> mob_target(mob) == nil end)
    force_ticks(mob, 2)

    assert eventually(fn -> mob_target(mob) == {:player, dancer.character.id} end)
  end

  test "expiry releases a held target without an explicit removal call" do
    dancer = start_dancer("ExpiryCharm", {150, 150})
    mob = start_charmable_mob()

    # The window must comfortably outlast full-suite scheduler jitter: the mob is
    # awake and can be starved for a while before it processes the forced tick
    # that sheds the charmed target. A 500ms charm could lapse before that tick
    # ran, so the target was never observably released. Pump several ticks and
    # give the charm a wide window so the release is deterministic.
    assert :ok =
             StatusInterpreter.apply_status(:mob, mob.unit_id, :sc_winkcharm,
               duration: 2_000,
               caster_id: dancer.character.id,
               resistance_roll: fn _ -> true end
             )

    MobSession.set_target(mob.pid, dancer.character.id)
    force_ticks(mob, 3)
    assert eventually(fn -> mob_target(mob) == nil end)

    assert eventually(
             fn -> not StatusStorage.has_status?(:mob, mob.unit_id, :sc_winkcharm) end,
             4_000
           )

    force_ticks(mob, 2)
    assert eventually(fn -> mob_target(mob) == {:player, dancer.character.id} end)
  end

  test "a second Dancer replaces the first charmer and makes the first targetable" do
    first = start_dancer("FirstCharm", {150, 150})
    second = start_dancer("SecondCharm", {152, 150})
    mob = start_charmable_mob()

    charm(first, mob)
    assert %{source_id: first_id} = StatusStorage.get_status(:mob, mob.unit_id, :sc_winkcharm)
    assert first_id == first.character.id

    charm(second, mob)
    assert %{source_id: second_id} = StatusStorage.get_status(:mob, mob.unit_id, :sc_winkcharm)
    assert second_id == second.character.id

    MobSession.set_target(mob.pid, first.character.id)
    force_tick(mob)

    assert eventually(fn ->
             state = get_mob_state(mob.pid)
             state.target_ref == {:player, first.character.id} and state.ai_state == :combat
           end)
  end

  test "a Demihuman boss is rejected before the otherwise valid race gate" do
    dancer = start_dancer("BossGate", {150, 150})
    boss = start_charmable_mob(modes: [:aggressive, :boss])
    initial_sp = player_sp(dancer.pid)

    cast(dancer, boss.unit_id)

    assert_receive {:packet_sent,
                    %SkillCastFailed{
                      skill_id: @wink_charm,
                      reason: :SKILL_CAST_FAILURE_REASON_UNSPECIFIED
                    }, _},
                   1_000

    refute StatusStorage.has_status?(:mob, boss.unit_id, :sc_winkcharm)
    assert player_sp(dancer.pid) == initial_sp
  end

  defp charm(dancer, mob) do
    cast(dancer, mob.unit_id)

    # The cast threads through the full player-session pipeline; under full-suite
    # load a 2s budget was occasionally too tight. Use the generous default.
    assert eventually(fn ->
             case StatusStorage.get_status(:mob, mob.unit_id, :sc_winkcharm) do
               %{source_id: source_id} -> source_id == dancer.character.id
               nil -> false
             end
           end)
  end

  defp cast(session, target_id) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: @wink_charm,
      level: 1,
      target_id: target_id
    })
  end

  defp start_charmable_mob(opts \\ []) do
    mob =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: @map,
        position: {151, 150},
        level: 1,
        hp: 50_000,
        max_hp: 50_000,
        race: :demi_human,
        modes: Keyword.get(opts, :modes, [:aggressive]),
        awake: Keyword.get(opts, :awake, true)
      )

    on_exit(fn ->
      StatusStorage.clear_unit_statuses(:mob, mob.unit_id)
      end_mob_session(mob)
    end)

    mob
  end

  defp start_dancer(name, position) do
    start_player(name, position, class: @dancer_class, learned_skills: %{"1011" => 1})
  end

  defp start_player(name, {x, y}, opts \\ []) do
    unique = System.unique_integer([:positive])
    userid = "winkcharm#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "F",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: Keyword.get(opts, :class, 0),
        base_level: 99,
        job_level: 50,
        str: 20,
        agi: 20,
        vit: 20,
        int: 20,
        dex: 99,
        luk: 20,
        hp: 5_000,
        max_hp: 5_000,
        sp: 500,
        max_sp: 500,
        learned_skills: Keyword.get(opts, :learned_skills, %{}),
        last_map: @map,
        last_x: x,
        last_y: y,
        save_map: @map,
        save_x: x,
        save_y: y
      }
      |> Character.new()
      |> Repo.insert()

    session = start_player_session(character: character, map_name: @map, position: {x, y})
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp force_tick(mob) do
    send(mob.pid, {:ai, :tick})
    Process.sleep(30)
  end

  defp force_ticks(mob, count), do: Enum.each(1..count, fn _ -> force_tick(mob) end)
  defp mob_target(mob), do: get_mob_state(mob.pid).target_ref
  defp player_sp(pid), do: get_player_state(pid).stats.current_state.sp
end

defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfSpiderwebTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skills.Professor.PfSpiderweb
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(Manager)
    Mimic.copy(SplashTargets)
    :ok
  end

  @victim {:mob, 9_701}
  @other {:mob, 9_702}

  defp group(gid, map \\ "prontera") do
    %Group{
      group_id: gid,
      skill_id: 405,
      skill_name: :pf_spiderweb,
      level: 1,
      caster_id: 9_601,
      caster_type: :player,
      map_name: map,
      center: {105, 100},
      cells: [{105, 100}],
      next_tick_at: nil,
      expires_at: 0,
      interval: 1_000,
      state: %{}
    }
  end

  defp versus(map?), do: stub(MapFlags, :get, fn _map, flag -> map? and flag == :pvp end)

  defp now, do: System.monotonic_time(:millisecond)

  # Applications land in storage as given, without the holder's live session.
  defp store_applications do
    stub(StatusInterpreter, :apply_status, fn type, id, status, params ->
      StatusStorage.apply_status(type, id, status, params)
    end)
  end

  # Runs `fun` and asserts `ref`'s hold now ends `hold_ms` after some instant
  # of the call, whatever the call took.
  defp assert_hold_from_call(ref \\ @victim, hold_ms, fun) do
    {type, id} = ref
    before = now()
    result = fun.()
    expires_at = StatusStorage.get_status(type, id, :sc_spiderweb).expires_at
    assert expires_at in (before + hold_ms)..(now() + hold_ms)
    result
  end

  defp seed_held(ref \\ @victim, slots, duration) do
    {type, id} = ref
    caught = Enum.count(slots, & &1)

    :ok =
      StatusStorage.apply_status(type, id, :sc_spiderweb,
        val1: caught,
        duration: duration,
        state: %{slots: slots}
      )
  end

  defp held(ref) do
    {type, id} = ref
    StatusStorage.get_status(type, id, :sc_spiderweb)
  end

  defp on_cell(refs) do
    stub(SpatialIndex, :units_in_cell, fn "prontera", 105, 100 -> refs end)
    stub(SplashTargets, :eligible, fn refs, _caster -> refs end)
    stub(Targeting, :placement_reaches?, fn 405, _ref -> true end)
  end

  test "casting webs the target's cell, holds what stands there and keeps the web on it" do
    caster =
      PlayerState.new(%Character{
        id: 9_601,
        account_id: 9_601,
        name: "Professor",
        class: 4017,
        sex: "M",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 99,
        hp: 100,
        sp: 100
      })

    versus(false)
    on_cell([@victim])

    stub(Combat, :resolve_combatant, fn 9_701 ->
      {:ok, %{position: {105, 100}, unit_type: :mob}}
    end)

    expect(Unit, :place, fn ^caster, :pf_spiderweb, 1, {105, 100} -> {:ok, group(51)} end)
    stub(SplashTargets, :eligible, fn refs, %{unit_type: :player, unit_id: 9_601} -> refs end)

    expect(StatusInterpreter, :apply_status, fn :mob, 9_701, :sc_spiderweb, params ->
      assert params[:duration] == 8_000
      assert params[:val1] == 1
      assert params[:state] == %{slots: [51, nil, nil]}
      :ok
    end)

    expect(Knockback, :pull_to, fn :mob, 9_701, 105, 100 -> :ok end)
    expect(Unit, :update_state, fn 51, %{victim: @victim} -> :ok end)
    before = now()

    expect(Manager, :set_expires_at, fn 51, expires_at ->
      assert (expires_at - before) in 8_000..9_000
      :ok
    end)

    assert {:ok, ^caster} = PfSpiderweb.cast(caster, {:unit, 9_701}, 1, PfSpiderweb.definition())
  end

  test "every enemy standing on the cell gets its own hold, and the web keeps the last one" do
    versus(false)
    store_applications()
    stub(Knockback, :pull_to, fn _type, _id, _x, _y -> :ok end)
    seed_held(@other, [52, nil, nil], 1_000)
    ally = {:player, 9_602}
    hidden = {:mob, 9_703}

    stub(SpatialIndex, :units_in_cell, fn "prontera", 105, 100 ->
      [ally, @victim, hidden, @other]
    end)

    stub(SplashTargets, :eligible, fn refs, %{unit_id: 9_601} -> refs -- [ally] end)
    stub(Targeting, :placement_reaches?, fn 405, ref -> ref != hidden end)
    at = now()

    assert {@other, expires_at} = PfSpiderweb.catch_standing(group(51), %{unit_id: 9_601}, at)
    assert expires_at == at + 16_000

    assert %{val1: 1, state: %{slots: [51, nil, nil]}} = held(@victim)
    assert %{val1: 2, state: %{slots: [52, 51, nil]}} = held(@other)
    refute held(ally)
    refute held(hidden)
  end

  test "a unit in three web slots expires the web at once, after an earlier catch" do
    versus(false)
    store_applications()
    stub(Knockback, :pull_to, fn _type, _id, _x, _y -> :ok end)
    seed_held(@other, [52, 53, 54], 9_000)
    on_cell([@victim, @other])
    at = now()

    assert PfSpiderweb.catch_standing(group(51), %{unit_id: 9_601}, at) == {@victim, at}
    assert %{state: %{slots: [52, 53, 54]}} = held(@other)
  end

  test "a web landing on nobody it reaches leaves its lifetime and tracking alone" do
    on_cell([])
    assert PfSpiderweb.catch_standing(group(51), %{unit_id: 9_601}, now()) == {nil, nil}
  end

  test "a failed first hold still makes the web live 3 s, with no pull" do
    versus(false)
    expect(StatusInterpreter, :apply_status, fn :mob, 9_701, :sc_spiderweb, _ -> {:error, :x} end)
    reject(&Knockback.pull_to/4)

    assert PfSpiderweb.capture(group(51), @victim, now()) == {:caught, 3_000}
  end

  test "a versus map halves the first hold" do
    versus(true)
    stub(Knockback, :pull_to, fn _type, _id, _x, _y -> :ok end)

    expect(StatusInterpreter, :apply_status, fn :mob, 9_701, :sc_spiderweb, params ->
      assert params[:duration] == 4_000
      :ok
    end)

    PfSpiderweb.capture(group(51), @victim, now())
  end

  test "a second web takes a slot and extends the hold to 16 s" do
    versus(false)
    store_applications()
    seed_held([51, nil, nil], 1_000)
    reject(&Knockback.pull_to/4)

    assert {:caught, 16_000} =
             assert_hold_from_call(16_000, fn ->
               PfSpiderweb.capture(group(52), @victim, now())
             end)

    assert %{val1: 2, state: %{slots: [51, 52, nil]}} = held(@victim)
  end

  test "a third web on a versus map extends the hold to 12 s; a fourth is refused" do
    versus(true)
    store_applications()
    seed_held([51, 52, nil], 1_000)

    assert {:caught, 12_000} =
             assert_hold_from_call(12_000, fn ->
               PfSpiderweb.capture(group(53, "pvp"), @victim, now())
             end)

    assert PfSpiderweb.capture(group(54, "pvp"), @victim, now()) == :immune
    assert %{state: %{slots: [51, 52, 53]}} = held(@victim)
  end

  test "a third web in normal play extends the hold by 8 s only" do
    versus(false)
    store_applications()
    seed_held([51, 52, nil], 1_000)

    assert {:caught, 8_000} =
             assert_hold_from_call(8_000, fn -> PfSpiderweb.capture(group(53), @victim, now()) end)
  end

  test "the catch count, not the webs left, sets the web time, and a freed slot is taken first" do
    versus(false)
    store_applications()

    :ok =
      StatusStorage.apply_status(:mob, 9_701, :sc_spiderweb,
        val1: 2,
        duration: 1_000,
        state: %{slots: [nil, 52, nil]}
      )

    assert {:caught, 8_000} = PfSpiderweb.capture(group(53), @victim, now())
    assert %{val1: 3, state: %{slots: [53, 52, nil]}} = held(@victim)
  end

  test "a restart never shortens the hold" do
    versus(false)
    store_applications()
    seed_held([51, nil, nil], 30_000)

    assert {:caught, 16_000} =
             assert_hold_from_call(30_000, fn ->
               PfSpiderweb.capture(group(52), @victim, now())
             end)
  end

  test "a web's end frees its slot on the unit it kept, and the last slot ends the hold" do
    seed_held([51, 52, nil], 10_000)
    seed_held(@other, [51, nil, nil], 10_000)

    PfSpiderweb.on_expire(%{group(51) | state: %{victim: @victim}})

    assert %{state: %{slots: [nil, 52, nil]}} = held(@victim)
    assert %{state: %{slots: [51, nil, nil]}} = held(@other)

    expect(StatusInterpreter, :remove_status_if_current, fn :mob, 9_701, :sc_spiderweb, entry ->
      assert entry.state.slots == [nil, 52, nil]
      true
    end)

    PfSpiderweb.on_expire(%{group(52) | state: %{victim: @victim}})
  end

  test "a catch whose hold ended meanwhile starts a fresh hold" do
    versus(false)
    store_applications()
    stub(Knockback, :pull_to, fn _type, _id, _x, _y -> :ok end)
    seed_held([51, nil, nil], 1_000)

    expect(StatusInterpreter, :restart_status_if_current, fn :mob, 9_701, :sc_spiderweb, _, _ ->
      StatusStorage.remove_status(:mob, 9_701, :sc_spiderweb)
      false
    end)

    assert {:caught, _held_ms} = PfSpiderweb.capture(group(52), @victim, now())
    assert %{val1: 1, state: %{slots: [52, nil, nil]}} = held(@victim)
  end

  test "a first hold beaten by another web's catch takes a slot in that hold" do
    versus(false)
    reject(&Knockback.pull_to/4)

    expect(StatusInterpreter, :apply_status, fn :mob, 9_701, :sc_spiderweb, _params ->
      seed_held([52, nil, nil], 1_000)
      :ok
    end)

    assert {:caught, 16_000} = PfSpiderweb.capture(group(51), @victim, now())
    assert %{val1: 2, state: %{slots: [52, 51, nil]}} = held(@victim)
  end

  test "a first hold another web restarted at once stays this web's single slot" do
    versus(false)
    expect(Knockback, :pull_to, fn :mob, 9_701, 105, 100 -> :ok end)

    expect(StatusInterpreter, :apply_status, fn :mob, 9_701, :sc_spiderweb, _params ->
      :ok =
        StatusStorage.apply_status(:mob, 9_701, :sc_spiderweb,
          val1: 2,
          duration: 16_000,
          state: %{slots: [51, 52, nil]}
        )
    end)

    assert PfSpiderweb.capture(group(51), @victim, now()) == {:caught, 8_000}
    assert %{val1: 2, state: %{slots: [51, 52, nil]}} = held(@victim)
  end

  test "a web's end that loses a race to another catch frees its slot on the new hold" do
    seed_held([51, nil, nil], 10_000)

    expect(StatusStorage, :remove_status_if_current, fn :mob, 9_701, :sc_spiderweb, _read ->
      seed_held([51, 52, nil], 10_000)
      false
    end)

    PfSpiderweb.on_expire(%{group(51) | state: %{victim: @victim}})

    assert %{state: %{slots: [nil, 52, nil]}} = held(@victim)
  end

  test "a web whose kept unit no longer holds it in a slot leaves the unit alone" do
    seed_held([52, nil, nil], 10_000)
    reject(&StatusInterpreter.remove_status/3)

    PfSpiderweb.on_expire(%{group(51) | state: %{victim: @victim}})

    assert %{state: %{slots: [52, nil, nil]}} = held(@victim)
  end
end

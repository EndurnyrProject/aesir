defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfSpiderwebTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Professor.PfSpiderweb
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private
  setup :setup_ets_tables

  @caster %PlayerState{character_id: 9_601, map_name: "prontera", x: 100, y: 100}
  @victim {:mob, 9_701}

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

  defp remaining_ms do
    entry = StatusStorage.get_status(:mob, 9_701, :sc_spiderweb)
    entry.expires_at - System.monotonic_time(:millisecond)
  end

  defp seed_held(groups, duration) do
    :ok =
      StatusStorage.apply_status(:mob, 9_701, :sc_spiderweb,
        duration: duration,
        state: %{groups: groups}
      )
  end

  test "casting webs the target's cell and holds it for 8 s with one pull" do
    versus(false)

    stub(Combat, :resolve_combatant, fn 9_701 ->
      {:ok, %{position: {105, 100}, unit_type: :mob}}
    end)

    expect(Unit, :place, fn @caster, :pf_spiderweb, 1, {105, 100}, opts ->
      assert opts[:state] == %{victim: @victim}
      {:ok, group(51)}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, 9_701, :sc_spiderweb, params ->
      assert params[:duration] == 8_000
      assert params[:state] == %{groups: [51]}
      :ok
    end)

    expect(Knockback, :pull_to, fn :mob, 9_701, 105, 100 -> :ok end)

    assert {:ok, @caster} = PfSpiderweb.cast(@caster, {:unit, 9_701}, 1, PfSpiderweb.definition())
  end

  test "a versus map halves the first hold" do
    versus(true)
    stub(Knockback, :pull_to, fn _type, _id, _x, _y -> :ok end)

    expect(StatusInterpreter, :apply_status, fn :mob, 9_701, :sc_spiderweb, params ->
      assert params[:duration] == 4_000
      :ok
    end)

    PfSpiderweb.capture(group(51), @victim)
  end

  test "a second web appends its group and extends the hold to 16 s" do
    versus(false)
    seed_held([51], 1_000)
    reject(&Knockback.pull_to/4)

    PfSpiderweb.capture(group(52), @victim)

    assert StatusStorage.get_status(:mob, 9_701, :sc_spiderweb).state.groups == [51, 52]
    assert_in_delta remaining_ms(), 16_000, 100
  end

  test "a third web on a versus map extends the hold to 12 s; a fourth does nothing" do
    versus(true)
    seed_held([51, 52], 1_000)

    PfSpiderweb.capture(group(53, "pvp"), @victim)
    assert_in_delta remaining_ms(), 12_000, 100

    PfSpiderweb.capture(group(54, "pvp"), @victim)
    assert StatusStorage.get_status(:mob, 9_701, :sc_spiderweb).state.groups == [51, 52, 53]
  end

  test "re-entering the same web neither stacks nor extends the hold" do
    versus(false)
    seed_held([51], 8_000)

    PfSpiderweb.capture(group(51), @victim)

    assert StatusStorage.get_status(:mob, 9_701, :sc_spiderweb).state.groups == [51]
    assert remaining_ms() <= 8_000
  end

  test "a web's end releases its group, and the last web ends the hold" do
    seed_held([51, 52], 10_000)

    PfSpiderweb.on_expire(%{
      group(51)
      | target_type: :mob,
        target_id: 9_701,
        state: %{victim: @victim}
    })

    assert StatusStorage.get_status(:mob, 9_701, :sc_spiderweb).state.groups == [52]

    expect(StatusInterpreter, :remove_status, fn :mob, 9_701, :sc_spiderweb -> :ok end)
    PfSpiderweb.on_expire(%{group(52) | state: %{victim: @victim}})
  end
end

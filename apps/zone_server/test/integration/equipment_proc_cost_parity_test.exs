defmodule Aesir.ZoneServer.Integration.EquipmentProcCostParityTest do
  @moduledoc """
  An equipment proc consumes the skill's requirement the way an ordinary cast
  does, minus the SP its autocast flag waives, before the effect runs: the
  wearer's session commits what was spent even when the effect fails.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.StatusStorage

  @map "prontera"
  @heal 28
  @increase_agi 29
  @holy_light 156

  defp start_caster(opts) do
    session =
      start_player_session(
        Keyword.merge([map_name: @map, position: {150, 150}, dex: 99, int: 99], opts)
      )

    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp start_target do
    mob =
      start_mob_session(
        map_name: @map,
        position: {151, 150},
        hp: 100_000,
        max_hp: 100_000,
        agi: 0,
        luk: 0
      )

    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end

  defp vitals(pid) do
    %{hp: hp, sp: sp} = get_player_state(pid).stats.current_state
    {hp, sp}
  end

  test "a proc waives the skill's SP and runs with less SP than the skill costs" do
    caster = start_caster(hp: 10, sp: 5)
    {10, 5} = vitals(caster.pid)

    GenServer.cast(caster.pid, {:skill, {:proc_cast, @heal, 1, :self}})

    assert eventually(fn ->
             {hp, sp} = vitals(caster.pid)
             hp > 10 and sp == 5
           end)
  end

  test "Holy Light keeps its explicit SP requirement, spent up to the SP held" do
    caster = start_caster(sp: 9)
    {hp, 9} = vitals(caster.pid)
    mob = start_target()
    mob_hp = get_mob_state(mob.pid).hp

    GenServer.cast(caster.pid, {:skill, {:proc_cast, @holy_light, 1, {:unit, mob.unit_id}}})

    assert eventually(fn ->
             get_mob_state(mob.pid).hp < mob_hp and vitals(caster.pid) == {hp, 0}
           end)
  end

  test "a requirement spent before a failing effect stays spent" do
    caster = start_caster(sp: 40)
    {hp, 40} = vitals(caster.pid)

    GenServer.cast(caster.pid, {:skill, {:proc_cast, @holy_light, 1, {:unit, 999_999_999}}})

    assert eventually(fn -> vitals(caster.pid) == {hp, 25} end)
  end

  test "the HP a proc owes is spent before the effect, up to the HP held" do
    caster = start_caster(hp: 10, sp: 40)
    {10, 40} = vitals(caster.pid)

    GenServer.cast(caster.pid, {:skill, {:proc_cast, @increase_agi, 1, :self}})

    assert eventually(fn -> get_player_state(caster.pid).action_state == :dead end)
    assert vitals(caster.pid) == {0, 40}
    refute StatusStorage.has_status?(:player, caster.character.id, :sc_increaseagi)
  end
end

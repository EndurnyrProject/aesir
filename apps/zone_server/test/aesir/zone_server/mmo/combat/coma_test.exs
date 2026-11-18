defmodule Aesir.ZoneServer.Mmo.Combat.ComaTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup
  import Mimic
  import Aesir.ZoneServer.Factory

  alias Aesir.TestMob
  alias Aesir.ZoneServer.Mmo.Combat.Coma
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  test "bullseye_coma_test: roll 10 applies a sourceless coma, 11 does not" do
    UnitRegistry.register_player(player(18), self())

    expect(PlayerSession, :apply_coma, fn pid, nil, %{passive?: true} when pid == self() ->
      :ok
    end)

    assert :applied = Coma.attempt(:player, 18, rate: 10, sampler: fn 10_000 -> 10 end)
    assert :resisted = Coma.attempt(:player, 18, rate: 10, sampler: fn 10_000 -> 11 end)
  end

  test "status-immune and MVP monsters resist before the roll, a normal mob does not" do
    for {id, extra} <- [{42, [:status_immune]}, {43, [:mvp]}] do
      :ok = UnitRegistry.register_unit(:mob, id, MobState, mob(id, extra), self())
      assert :resisted = Coma.attempt(:mob, id, rate: 10, sampler: fn _ -> flunk("rolled") end)
    end

    :ok = UnitRegistry.register_unit(:mob, 44, MobState, mob(44, []), self())
    expect(MobSession, :apply_coma, fn _pid, nil, %{passive?: true} -> :ok end)
    assert :applied = Coma.attempt(:mob, 44, rate: 10_000)
  end

  test "a dead or Gravity Control target resists before the roll" do
    alive = player(18)
    dead = put_in(alive.stats.current_state.hp, 0)
    UnitRegistry.register_player(dead, self())
    UnitRegistry.register_player(player(19), self())
    :ok = StatusStorage.apply_status(:player, 19, :sc_gravitycontrol)
    reject(&PlayerSession.apply_coma/3)

    for id <- [18, 19, 99],
        do: assert(:resisted = Coma.attempt(:player, id, rate: 10, sampler: fn _ -> 1 end))
  end

  defp player(id) do
    PlayerState.new(
      Aesir.Factory.build(:character,
        id: id,
        account_id: id,
        name: "Coma #{id}",
        class: 0,
        base_level: 50,
        job_level: 1,
        sex: "M",
        last_map: "prontera",
        last_x: 10,
        last_y: 10,
        hp: 2000,
        sp: 100,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 0
      )
    )
  end

  defp mob(id, extra_modes) do
    {:ok, definition} = Mobs.by_id(1002)

    state = build(:mob_state, instance_id: id, mob_data: definition, x: 10, y: 10)

    modes = Enum.uniq(extra_modes ++ (state.mob_data.modes || []))
    TestMob.publish(%{state | mob_data: %{state.mob_data | modes: modes}})
  end
end

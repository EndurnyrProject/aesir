defmodule Aesir.ZoneServer.Unit.Player.StatusSyncTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.Stats, as: UnitStats

  defp stats(overrides \\ %{}) do
    base = %Stats{
      base_stats: %UnitStats.BaseStats{
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        pow: 10,
        sta: 20,
        wis: 30,
        spl: 40,
        con: 50,
        crt: 60
      },
      derived_stats: %UnitStats.DerivedStats{
        max_hp: 100,
        max_sp: 50,
        aspd: 150,
        max_ap: 70
      },
      combat_stats: %UnitStats.CombatStats{
        atk: 1,
        matk: 1,
        matk_min: 1,
        matk_max: 1,
        heal_matk_min: 1,
        heal_matk_max: 1,
        def: 1,
        mdef: 1,
        soft_mdef: 1,
        hit: 1,
        flee: 1,
        critical: 1,
        perfect_dodge: 1,
        passive_atk: 1,
        patk: 11,
        smatk: 22,
        res: 33,
        mres: 44,
        hplus: 55,
        crate: 66
      },
      current_state: %UnitStats.CurrentState{hp: 1, sp: 1, ap: 25},
      progression: %Stats.PlayerProgression{
        base_level: 200,
        job_level: 70,
        base_exp: 0,
        job_exp: 0,
        job_id: 4252,
        skill_point: 0,
        status_point: 0,
        trait_point: 12
      },
      equipment: %Stats.Equipment{},
      modifiers: %Stats.Modifiers{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
    }

    struct(base, overrides)
  end

  defp collect_params do
    receive do
      {:send, :gameplay, {:param_change, %Aesir.Net.ParamChange{var_id: id, value: value}}} ->
        Map.put(collect_params(), id, value)
    after
      0 -> %{}
    end
  end

  test "emits trait, derived combat, trait_point, and AP params with correct values" do
    StatusSync.send_stat_updates(self(), stats())

    params = collect_params()

    assert params[StatusParams.pow()] == 10
    assert params[StatusParams.sta()] == 20
    assert params[StatusParams.wis()] == 30
    assert params[StatusParams.spl()] == 40
    assert params[StatusParams.con()] == 50
    assert params[StatusParams.crt()] == 60

    assert params[StatusParams.patk()] == 11
    assert params[StatusParams.smatk()] == 22
    assert params[StatusParams.res()] == 33
    assert params[StatusParams.mres()] == 44
    assert params[StatusParams.hplus()] == 55
    assert params[StatusParams.crate()] == 66

    assert params[StatusParams.trait_point()] == 12
    assert params[StatusParams.ap()] == 25
    assert params[StatusParams.max_ap()] == 70
  end

  test "pushes derived combat stats for a non-trait job (SP-A gap closed)" do
    non_trait_stats =
      stats(%{
        base_stats: %UnitStats.BaseStats{
          str: 1,
          agi: 1,
          vit: 1,
          int: 1,
          dex: 1,
          luk: 1,
          pow: 0,
          sta: 0,
          wis: 0,
          spl: 0,
          con: 0,
          crt: 0
        },
        progression: %Stats.PlayerProgression{
          base_level: 99,
          job_level: 50,
          base_exp: 0,
          job_exp: 0,
          job_id: 1,
          skill_point: 0,
          status_point: 0,
          trait_point: 0
        }
      })

    StatusSync.send_stat_updates(self(), non_trait_stats)

    params = collect_params()

    assert params[StatusParams.patk()] == 11
    assert params[StatusParams.smatk()] == 22
    assert params[StatusParams.res()] == 33
    assert params[StatusParams.mres()] == 44
    assert params[StatusParams.hplus()] == 55
    assert params[StatusParams.crate()] == 66
  end

  test "existing base/derived/combat/progression params are unchanged" do
    StatusSync.send_stat_updates(self(), stats())

    params = collect_params()

    assert params[StatusParams.str()] == 1
    assert params[StatusParams.agi()] == 1
    assert params[StatusParams.vit()] == 1
    assert params[StatusParams.int()] == 1
    assert params[StatusParams.dex()] == 1
    assert params[StatusParams.luk()] == 1

    assert params[StatusParams.max_hp()] == 100
    assert params[StatusParams.max_sp()] == 50
    assert params[StatusParams.hp()] == 1
    assert params[StatusParams.sp()] == 1
    assert params[StatusParams.aspd()] == 150

    assert params[StatusParams.hit()] == 1
    assert params[StatusParams.flee1()] == 1
    assert params[StatusParams.critical()] == 1
    assert params[StatusParams.atk1()] == 1
    assert params[StatusParams.def1()] == 1

    assert params[StatusParams.base_level()] == 200
    assert params[StatusParams.job_level()] == 70
    assert params[StatusParams.base_exp()] == 0
    assert params[StatusParams.job_exp()] == 0
  end
end

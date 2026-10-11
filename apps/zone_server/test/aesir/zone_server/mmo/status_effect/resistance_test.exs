defmodule Aesir.ZoneServer.Mmo.StatusEffect.ResistanceTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance

  defp view(overrides \\ []) do
    Map.merge(
      %{player?: true, level: 50, str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0, mdef: 0},
      Map.new(overrides)
    )
  end

  # The roll reports the final rate and lands.
  defp input(status, overrides) do
    test_pid = self()

    Map.merge(
      %{
        status: status,
        rate: 10_000,
        tick: 10_000,
        target: view(),
        source: view(),
        scresist: nil,
        siegfried: nil,
        res_eff: 0,
        roll: fn rate ->
          send(test_pid, {:rate, rate})
          true
        end
      },
      Map.new(overrides)
    )
  end

  defp defend(status, mode, overrides \\ []),
    do: Resistance.defend(input(status, overrides), mode)

  defp rolled_rate do
    assert_received {:rate, rate}
    rate
  end

  describe "renewal recipes" do
    test "Stun: VIT share of the rate and duration, then 0.5 s longer" do
      assert {:ok, 3500} = defend(:sc_stun, :renewal, target: view(vit: 40), tick: 5000)
      assert rolled_rate() == 6000
    end

    test "the source's level lead lowers sc_def by lead squared / 5 * 100" do
      source = view(level: 60)
      assert {:ok, _} = defend(:sc_silence, :renewal, target: view(int: 50), source: source)
      assert rolled_rate() == 7000
    end

    test "the level advantage wraps at 16 bits" do
      target = view(level: 1, vit: 100)

      assert {:ok, _} = defend(:sc_stun, :renewal, target: target, source: view(level: 99))
      refute_received {:rate, _}

      assert {:ok, _} = defend(:sc_stun, :renewal, target: target, source: view(level: 59))
      assert rolled_rate() == 1670
    end

    test "a negative sc_def is clamped to 0" do
      assert {:ok, 12_000} =
               defend(:sc_poison, :renewal, target: view(level: 1), source: view(level: 20))

      refute_received {:rate, _}
    end

    test "Petrifying and Freeze use MDEF and add 3 s" do
      assert {:ok, 8000} = defend(:sc_stonewait, :renewal, target: view(mdef: 50))
      assert rolled_rate() == 5000

      assert {:ok, 8000} = defend(:sc_freeze, :renewal, target: view(mdef: 50))
    end

    test "Bleeding, Sleep, Blind, Curse and Confusion read their own stat" do
      assert {:ok, 21_000} = defend(:sc_bleeding, :renewal, target: view(agi: 10))
      assert {:ok, 11_000} = defend(:sc_sleep, :renewal, target: view(agi: 10))
      assert {:ok, 11_000} = defend(:sc_blind, :renewal, target: view(int: 10))
      assert {:ok, 11_000} = defend(:sc_curse, :renewal, target: view(luk: 10))
      assert {:ok, 11_000} = defend(:sc_confusion, :renewal, target: view(luk: 10))
    end
  end

  describe "pre-renewal recipes" do
    test "Stun: VIT share, then LUK and the level difference as flat defense" do
      target = view(vit: 30, luk: 20, level: 60)

      assert {:ok, 6800} = defend(:sc_stun, :pre_renewal, target: target, tick: 10_000)
      assert rolled_rate() == 6700
    end

    test "a level lead turns sc_def2 negative and raises the rate" do
      target = view(level: 1)

      assert {:ok, 10_000} =
               defend(:sc_stun, :pre_renewal, rate: 5000, target: target, source: view(level: 99))

      assert rolled_rate() == 5980
    end

    test "player Poison: its own VIT and LUK duration defense" do
      target = view(vit: 30, luk: 20)

      assert {:ok, 44_500} = defend(:sc_poison, :pre_renewal, target: target, tick: 60_000)
      assert rolled_rate() == 6800
    end

    test "monster Poison: half the duration, two thirds of a VIT share" do
      target = view(player?: false, vit: 30)

      assert {:ok, 24_000} = defend(:sc_poison, :pre_renewal, target: target, tick: 60_000)
    end

    test "Petrifying is not shortened" do
      assert {:ok, 20_000} =
               defend(:sc_stonewait, :pre_renewal, target: view(mdef: 40), tick: 20_000)

      assert rolled_rate() == 6000
    end

    test "Freeze: the source's LUK lengthens it" do
      assert {:ok, 7500} =
               defend(:sc_freeze, :pre_renewal, target: view(mdef: 30), source: view(luk: 50))
    end

    test "Curse defends duration with VIT and has only a source level penalty" do
      target = view(luk: 20, vit: 10, level: 99)

      assert {:ok, 8800} = defend(:sc_curse, :pre_renewal, target: target)
      assert rolled_rate() == 8300
    end

    test "Confusion reverses its flat defense" do
      target = view(str: 20, int: 20, level: 40)

      assert {:ok, _} = defend(:sc_confusion, :pre_renewal, target: target)
      assert rolled_rate() == 7900
    end
  end

  describe "mode-independent recipes" do
    test "Decrease AGI: MDEF as flat defense and half duration on players" do
      assert {:ok, 5000} = defend(:sc_decreaseagi, :renewal, target: view(mdef: 10))
      assert rolled_rate() == 9000

      assert {:ok, 10_000} =
               defend(:sc_decreaseagi, :pre_renewal, target: view(player?: false, mdef: 10))
    end

    test "Joint Beat and No Recover shorten by a flat LUK term" do
      target = view(luk: 40, agi: 25)

      assert {:ok, 98_000} = defend(:sc_jointbeat, :renewal, target: target, tick: 110_000)
      assert {:ok, 6000} = defend(:sc_norecover_state, :pre_renewal, target: target)
    end

    test "Curse never lands on a target without LUK" do
      assert :resisted = defend(:sc_curse, :renewal)
      refute_received {:rate, _}
    end

    test "a status without a recipe only rolls its rate and keeps its duration" do
      assert {:ok, 10_000} = defend(:sc_provoke, :renewal, rate: 7000, target: view(vit: 99))
      assert rolled_rate() == 7000
    end
  end

  describe "caps, resistance statuses and equipment" do
    test "sc_def is capped at 100%" do
      assert :resisted = defend(:sc_stun, :pre_renewal, target: view(vit: 150, luk: 0))
    end

    test "Status Resistance adds after the cap and ahead of Siegfried" do
      assert {:ok, _} = defend(:sc_stun, :renewal, target: view(vit: 20), scresist: 50)
      assert rolled_rate() == 3000

      assert {:ok, _} =
               defend(:sc_stun, :renewal, target: view(vit: 20), scresist: 50, siegfried: 99)

      assert rolled_rate() == 3000
    end

    test "Siegfried resists only its seven statuses in renewal and all in pre-renewal" do
      assert {:ok, _} = defend(:sc_stun, :renewal, siegfried: 25)
      assert rolled_rate() == 7500

      assert {:ok, _} = defend(:sc_poison, :renewal, siegfried: 25)
      refute_received {:rate, _}

      assert {:ok, _} = defend(:sc_poison, :pre_renewal, siegfried: 25)
      assert rolled_rate() == 7500
    end

    test "equipment resistance is a share of the rate, and of the renewal duration" do
      assert {:ok, 10_500} = defend(:sc_stun, :renewal, res_eff: 5000, tick: 20_000)
      assert rolled_rate() == 5000

      assert {:ok, 10_000} = defend(:sc_stun, :pre_renewal, res_eff: 5000)
      assert rolled_rate() == 5000
    end

    test "the rate is rounded up to a multiple of 10" do
      assert {:ok, _} = defend(:sc_stun, :renewal, rate: 5001)
      assert rolled_rate() == 5010
    end

    test "a full rate lands without rolling; a non-positive one never lands" do
      assert {:ok, _} = defend(:sc_stun, :renewal)
      refute_received {:rate, _}

      assert :resisted = defend(:sc_stun, :renewal, rate: 0)
      refute_received {:rate, _}
    end
  end

  describe "start flags and durations" do
    test "no_rate_def rolls the given rate; no_tick_def keeps the duration" do
      target = view(vit: 50)

      assert {:ok, _} = defend(:sc_stun, :renewal, target: target, rate: 5001, no_rate_def: true)
      assert rolled_rate() == 5001

      assert {:ok, 10_000} = defend(:sc_stun, :renewal, target: target, no_tick_def: true)
      assert rolled_rate() == 5000
    end

    test "a reduced duration never drops below 1 ms" do
      assert {:ok, 1} = defend(:sc_stun, :pre_renewal, target: view(vit: 50, luk: 99), tick: 100)
    end

    test "a field-held duration of 0 is never reduced" do
      assert {:ok, 0} = defend(:sc_stun, :renewal, target: view(vit: 50), tick: 0)
    end
  end

  describe "rolls" do
    test "roll_rate/1 always lands from 10000 and never at 0 or below" do
      assert Resistance.roll_rate(10_000)
      assert Resistance.roll_rate(12_000)
      refute Resistance.roll_rate(0)
      refute Resistance.roll_rate(-5)
    end

    test "roll_success/2 samples a fractional percent at 10,000-scale precision" do
      assert Resistance.roll_success(30.4, fn 10_000 -> 3040 end)
      refute Resistance.roll_success(30.4, fn 10_000 -> 3041 end)
    end

    test "roll_success/2 rounds fractional rates up to the next Aegis tenth-percent" do
      assert Resistance.roll_success(30.31, fn 10_000 -> 3040 end)
      refute Resistance.roll_success(30.31, fn 10_000 -> 3041 end)
    end

    test "roll_success/1 bounds" do
      assert Resistance.roll_success(100)
      refute Resistance.roll_success(0)
    end
  end
end

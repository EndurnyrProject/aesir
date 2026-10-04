defmodule Aesir.ZoneServer.Mmo.Skills.Shared.BoltEchoTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Skills.Shared.BoltEcho
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(MagicAttack)
    :ok
  end

  @id 7_101
  @target {:mob, 3001}

  defp caster(epoch \\ 2),
    do: %PlayerState{
      character_id: @id,
      deferred_epoch: epoch,
      stats: %{derived_stats: %{aspd: 150}}
    }

  defp hold_double_cast,
    do: :ok = StatusStorage.apply_status(:player, @id, :sc_doublecast, state: %{chance: 80})

  test "a passing roll schedules one echo of the same bolt after the attack motion" do
    hold_double_cast()

    assert :ok = BoltEcho.maybe_schedule(caster(), @target, 19, 7, fn 100 -> 80 end)

    assert_receive {:skill,
                    {:deferred, BoltEcho, %{target: @target, bolt_id: 19, level: 7, epoch: 2}}},
                   1_000
  end

  test "a failed roll or a caster without the status schedules nothing" do
    assert :ok = BoltEcho.maybe_schedule(caster(), @target, 19, 7, fn 100 -> 1 end)

    hold_double_cast()
    assert :ok = BoltEcho.maybe_schedule(caster(), @target, 19, 7, fn 100 -> 81 end)

    refute_receive {:skill, {:deferred, BoltEcho, _payload}}, 600
  end

  test "the echo fires the bolt once for the current epoch and never for a stale one" do
    payload = %{target: @target, bolt_id: 14, level: 3, epoch: 2}
    caster = caster()

    expect(MagicAttack, :execute_bolt, fn ^caster, @target, 14, 3, [] -> {:ok, @target} end)
    assert :ok = BoltEcho.deferred(payload, caster)

    reject(&MagicAttack.execute_bolt/5)
    assert {:error, :stale} = BoltEcho.deferred(payload, caster(3))
  end
end

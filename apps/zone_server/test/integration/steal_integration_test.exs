defmodule Aesir.ZoneServer.Integration.StealIntegrationTest do
  @moduledoc """
  Integration tests for TF_STEAL driving the real `MobSession.attempt_steal/3`.

  The rate roll (`:rand.uniform(100)`) and each per-drop roll
  (`:rand.uniform(10_000)`) are made deterministic without seeding `:rand` by
  pushing the computed rate to its guaranteed extremes: a `rate <= 0` can never
  beat the minimum roll of 1 (guaranteed miss), a `rate >= 100` can never lose
  to the maximum roll of 100 (guaranteed hit); the same trick applies to a
  drop's own `rate` against the 1..10_000 roll range.
  """

  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Unit.Mob.MobSession

  # Jellopy, Empty Bottle, Apple - real ids from priv/db/items.
  @jellopy_id 909
  @apple_id 512

  defp guaranteed_drops do
    [
      %MobDrop{item: "Jellopy", rate: 10_000, steal_protected: true},
      %MobDrop{item: "Empty_Bottle", rate: 0, steal_protected: false},
      %MobDrop{item: "Apple", rate: 10_000, steal_protected: false}
    ]
  end

  test "guaranteed rate and drop roll steals the first eligible, non-protected drop" do
    mob = start_mob_session(dex: 10, drops: guaranteed_drops())

    # dex diff 0, skill_lv 20 -> rate = 0 + 120 + 4 = 124, always beats the roll.
    assert {:ok, @apple_id} = MobSession.attempt_steal(mob.pid, 10, 20)

    state = get_mob_state(mob.pid)
    assert state.stolen_from
  end

  test "guaranteed miss when the rate rolls to zero or below" do
    mob = start_mob_session(dex: 100, drops: guaranteed_drops())

    # dex diff -100, skill_lv 1 -> rate = -50 + 6 + 4 = -40, never beats the roll.
    assert {:error, :miss} = MobSession.attempt_steal(mob.pid, 0, 1)

    refute get_mob_state(mob.pid).stolen_from
  end

  test "an unresolvable item name is skipped, falling through to the next drop" do
    drops = [
      %MobDrop{item: "NotARealItem_XYZ", rate: 10_000, steal_protected: false},
      %MobDrop{item: "Apple", rate: 10_000, steal_protected: false}
    ]

    mob = start_mob_session(dex: 10, drops: drops)

    assert {:ok, @apple_id} = MobSession.attempt_steal(mob.pid, 10, 20)
  end

  test "no eligible drop leaves stolen_from untouched and is retryable" do
    mob =
      start_mob_session(
        dex: 10,
        drops: [%MobDrop{item: "Apple", rate: 0, steal_protected: false}]
      )

    assert {:error, :no_drop} = MobSession.attempt_steal(mob.pid, 10, 20)
    refute get_mob_state(mob.pid).stolen_from

    assert {:error, :no_drop} = MobSession.attempt_steal(mob.pid, 10, 20)
    refute get_mob_state(mob.pid).stolen_from
  end

  test "boss mobs reject steals outright without consuming a roll" do
    mob = start_mob_session(dex: 10, modes: [:boss], drops: guaranteed_drops())

    assert {:error, :boss} = MobSession.attempt_steal(mob.pid, 10, 20)
    refute get_mob_state(mob.pid).stolen_from
  end

  test "a mob can only be stolen from once; the second attempt fails" do
    mob = start_mob_session(dex: 10, drops: guaranteed_drops())

    assert {:ok, @apple_id} = MobSession.attempt_steal(mob.pid, 10, 20)
    assert get_mob_state(mob.pid).stolen_from

    assert {:error, :already_stolen} = MobSession.attempt_steal(mob.pid, 10, 20)
  end

  test "steal_protected drops are never eligible even alone" do
    mob =
      start_mob_session(
        dex: 10,
        drops: [%MobDrop{item: "Jellopy", rate: 10_000, steal_protected: true}]
      )

    assert {:error, :no_drop} = MobSession.attempt_steal(mob.pid, 10, 20)
    refute get_mob_state(mob.pid).stolen_from
  end

  test "resolves the winning drop's aegis name to its real item id" do
    mob =
      start_mob_session(
        dex: 10,
        drops: [%MobDrop{item: "Jellopy", rate: 10_000, steal_protected: false}]
      )

    assert {:ok, @jellopy_id} = MobSession.attempt_steal(mob.pid, 10, 20)
  end
end

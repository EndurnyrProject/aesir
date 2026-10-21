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

  alias Aesir.Net.ItemAddFailed
  alias Aesir.Net.SkillCastFailed
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.TestSupport.ClownSessions
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Mob.MobSession

  # Jellopy, Empty Bottle, Apple - real ids from priv/db/re/items.
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

  test "status-immune mobs reject and terminally lock stealing without a roll" do
    mob =
      start_mob_session(
        dex: 10,
        modes: [:detector, :status_immune, :knockback_immune],
        drops: guaranteed_drops()
      )

    assert {:error, :immune} = MobSession.attempt_steal(mob.pid, 10, 20)
    assert get_mob_state(mob.pid).stolen_from
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

  describe "a player's failed Steal through the real sessions" do
    @rogue 17
    @emotion 197

    setup do
      ClownSessions.blank_map("prontera")
      :ok
    end

    defp reacts_to_steal do
      %{
        skill: "NPC_EMOTION",
        skill_id: @emotion,
        state: :any,
        level: 1,
        target: :self,
        delay: 5_000,
        cancelable: true,
        cast_time: 0,
        rate: 10_000,
        emotion: nil,
        condition: %{type: :skillused, value: 50, val1: 15}
      }
    end

    test "spends its SP, reports the failure and lets the monster react to the use" do
      mob = start_mob_session(dex: 255, drops: guaranteed_drops(), position: {151, 150})
      stub(MobSkillDb, :rows_for, fn _mob_id -> [reacts_to_steal()] end)
      Mimic.allow(MobSkillDb, self(), mob.pid)

      session =
        :novice
        |> ClownSessions.character("prontera", {150, 150}, %{50 => 1}, %{class: @rogue, dex: 1})
        |> ClownSessions.start_session()

      ClownSessions.cast(session, 50, 1, mob.unit_id)

      assert_packet_sent(SkillCastFailed)
      assert_eventually(fn -> get_player_state(session.pid).stats.current_state.sp == 990 end)
      assert_eventually(fn -> get_mob_state(mob.pid).last_skill_id == @emotion end)
      refute get_mob_state(mob.pid).stolen_from
    end

    test "a stolen item the caster cannot carry reports the reason" do
      mob =
        start_mob_session(
          dex: 1,
          drops: [%MobDrop{item: "Barrier_Builder", rate: 10_000, steal_protected: false}],
          position: {151, 150}
        )

      character =
        ClownSessions.character(
          :novice,
          "prontera",
          {150, 150},
          %{50 => 10},
          %{class: @rogue, dex: 100}
        )

      {:ok, _heavy} =
        InventoryPersistence.insert_item(character.id, %{nameid: 2806, amount: 3})

      session = ClownSessions.start_session(character)

      ClownSessions.cast(session, 50, 10, mob.unit_id)

      assert_packet_sent_with(ItemAddFailed, fn packet ->
        assert packet.result == :ITEM_ADD_RESULT_OVERWEIGHT
      end)

      assert_packet_sent(SkillCastFailed)

      assert [{0, %{nameid: 2806, amount: 3}}] =
               Enum.to_list(get_player_state(session.pid).inventory)
    end
  end
end

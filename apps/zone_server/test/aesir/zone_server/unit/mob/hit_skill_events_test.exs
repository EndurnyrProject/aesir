defmodule Aesir.ZoneServer.Unit.Mob.HitSkillEventsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Mob.HitSkillEvents
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :verify_on_exit!

  @mob_id 7001
  @attacker {:player, 1000}

  defp mob do
    struct!(MobState,
      instance_id: @mob_id,
      mob_id: 1002,
      mob_data: Aesir.TestMob.definition(),
      spawn_ref: "",
      x: 10,
      y: 10,
      map_name: "prontera",
      hp: 100,
      sp: 10,
      spawned_at: 0
    )
  end

  # Records every event the reaction boundary receives, in order.
  defp record_events do
    test_pid = self()

    stub(AiHandler, :handle_skill_event, fn state, source_ref, event, tick ->
      send(test_pid, {:event, source_ref, event, tick})
      {:noreply, state}
    end)
  end

  defp physical(overrides), do: Map.merge(%{dmg_type: :physical, is_short: true}, overrides)

  describe "run/5" do
    test "a short physical hit fires the close-attack event then the skill-used event" do
      record_events()

      assert HitSkillEvents.run(mob(), 500, @attacker, physical(%{skill_id: 5}), 1234) == mob()

      assert_received {:event, @attacker, {:attacked, :closed, 500}, 1234}
      assert_received {:event, @attacker, {:skillused, 5, 500}, 1234}
    end

    test "a long physical hit fires the long-range event, a long magic hit the any-damage one" do
      record_events()

      HitSkillEvents.run(mob(), 500, @attacker, physical(%{is_short: false}), 1234)
      assert_received {:event, @attacker, {:attacked, :long, 500}, 1234}

      HitSkillEvents.run(mob(), 500, @attacker, %{dmg_type: :magic, is_short: false}, 1234)
      assert_received {:event, @attacker, {:attacked, :other, 500}, 1234}
    end

    test "a misc hit without a range flag is the any-damage event" do
      record_events()

      HitSkillEvents.run(mob(), 500, @attacker, %{dmg_type: :misc, connected?: true}, 1234)

      assert_received {:event, @attacker, {:attacked, :other, 500}, 1234}
    end

    test "a hit that took no HP fires only the skill-used event, carrying no damage" do
      record_events()

      HitSkillEvents.run(mob(), 0, @attacker, physical(%{skill_id: 5, connected?: true}), 1234)

      refute_received {:event, @attacker, {:attacked, _kind, _damage}, _tick}
      assert_received {:event, @attacker, {:skillused, 5, 0}, 1234}
    end

    test "a hit from no skill fires only the attack event" do
      record_events()

      HitSkillEvents.run(mob(), 500, @attacker, physical(%{}), 1234)

      assert_received {:event, @attacker, {:attacked, :closed, 500}, 1234}
      refute_received {:event, @attacker, {:skillused, _skill_id, _damage}, _tick}
    end

    test "a passive or status-tick notification is not a battle hit" do
      reject(&AiHandler.handle_skill_event/4)

      assert HitSkillEvents.run(mob(), 500, @attacker, physical(%{passive?: true}), 1234) == mob()

      assert HitSkillEvents.run(mob(), 500, @attacker, physical(%{status_tick?: true}), 1234) ==
               mob()
    end

    test "a missed or blocked hit fires nothing" do
      reject(&AiHandler.handle_skill_event/4)

      assert HitSkillEvents.run(mob(), 0, @attacker, physical(%{magic_rod_miss?: true}), 1234) ==
               mob()

      assert HitSkillEvents.run(mob(), 500, @attacker, physical(%{blocked?: true}), 1234) == mob()
    end

    test "a monster's own hit on itself fires nothing" do
      reject(&AiHandler.handle_skill_event/4)

      assert HitSkillEvents.run(mob(), 500, {:mob, @mob_id}, physical(%{skill_id: 5}), 1234) ==
               mob()
    end
  end
end

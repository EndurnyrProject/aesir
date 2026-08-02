defmodule Aesir.ZoneServer.Mmo.MobSkill.SelectorTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist
  alias Aesir.ZoneServer.Mmo.MobSkill.Selector
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :verify_on_exit!

  # Forces every rate roll to succeed (1 <= rate for any rate >= 1).
  defp hit, do: fn _ -> 1 end
  # Forces every rate roll to fail against any rate < 10_000.
  defp miss, do: fn _ -> 10_000 end

  defp mob(overrides \\ %{}) do
    base = %{
      ai_state: :combat,
      initiated_by_self?: false,
      hp: 100,
      max_hp: 100,
      target_id: 1,
      rude_attacked?: false,
      skill_cooldowns: %{}
    }

    struct(MobState, Map.merge(base, Map.new(overrides)))
  end

  # MG_FIREBOLT: a real player skill (id 19), resolvable in Skill.Catalog with
  # an active module, so it clears the castable gate by default.
  defp row(overrides \\ %{}) do
    base = %{
      skill: "MG_FIREBOLT",
      skill_id: 19,
      state: :attack,
      rate: 10_000,
      condition: %{type: :always}
    }

    Map.merge(base, Map.new(overrides))
  end

  defp opts(extra \\ []), do: Keyword.merge([now: 0, rng: hit()], extra)

  describe "state filter" do
    test "an :attack-state row fires in :combat when not self-initiated" do
      mob = mob(%{ai_state: :combat, initiated_by_self?: false})

      assert Selector.select(mob, [row(%{state: :attack})], opts()) ==
               {:cast, row(%{state: :attack})}
    end

    test "an :attack-state row does NOT fire in :combat when self-initiated (wants :angry)" do
      mob = mob(%{ai_state: :combat, initiated_by_self?: true})

      assert Selector.select(mob, [row(%{state: :attack})], opts()) == nil
    end

    test "an :angry-state row fires in :combat when self-initiated" do
      mob = mob(%{ai_state: :combat, initiated_by_self?: true})

      assert Selector.select(mob, [row(%{state: :angry})], opts()) ==
               {:cast, row(%{state: :angry})}
    end

    test "an :idle-state row fires in both :idle and :alert" do
      idle_row = row(%{state: :idle})

      assert Selector.select(mob(%{ai_state: :idle}), [idle_row], opts()) == {:cast, idle_row}
      assert Selector.select(mob(%{ai_state: :alert}), [idle_row], opts()) == {:cast, idle_row}
    end

    test "an :any-state row fires regardless of AI state" do
      any_row = row(%{state: :any})

      for ai_state <- [:idle, :alert, :combat, :chase, :return] do
        assert Selector.select(mob(%{ai_state: ai_state}), [any_row], opts()) ==
                 {:cast, any_row}
      end
    end

    test "a :chase-state row fires in :chase" do
      chase_row = row(%{state: :chase})

      assert Selector.select(mob(%{ai_state: :chase}), [chase_row], opts()) ==
               {:cast, chase_row}
    end
  end

  describe "castable filter" do
    test "a row whose skill_id has no catalog entry is skipped" do
      unresolvable = row(%{skill_id: 999_999})

      assert Selector.select(mob(), [unresolvable], opts()) == nil
    end

    test "a row whose skill_id is denylisted is skipped" do
      stub(Denylist, :denied?, fn 19 -> true end)

      assert Selector.select(mob(), [row()], opts()) == nil
    end

    test "a row whose skill_id resolves and is not denylisted fires" do
      stub(Denylist, :denied?, fn 19 -> false end)

      assert Selector.select(mob(), [row()], opts()) == {:cast, row()}
    end
  end

  describe "condition filter" do
    test "always fires" do
      r = row(%{condition: %{type: :always}})

      assert Selector.select(mob(), [r], opts()) == {:cast, r}
    end

    test "myhpltmaxrate fires only when HP% is at or below the threshold" do
      r = row(%{condition: %{type: :myhpltmaxrate, value: 50}})

      assert Selector.select(mob(%{hp: 100, max_hp: 100}), [r], opts()) == nil
      assert Selector.select(mob(%{hp: 50, max_hp: 100}), [r], opts()) == {:cast, r}
      assert Selector.select(mob(%{hp: 30, max_hp: 100}), [r], opts()) == {:cast, r}
    end

    test "alchemist fires only for damaged player-owned mobs" do
      r = row(%{condition: %{type: :alchemist}})

      assert Selector.select(mob(%{owner_player_id: 42, hp: 99}), [r], opts()) == {:cast, r}
      assert Selector.select(mob(%{owner_player_id: 42, hp: 100}), [r], opts()) == nil
      assert Selector.select(mob(%{owner_player_id: nil, hp: 99}), [r], opts()) == nil
    end

    test "idle rows stay eligible in combat for player-owned mobs" do
      r = row(%{state: :idle})

      assert Selector.select(mob(%{ai_state: :combat, owner_player_id: 42}), [r], opts()) ==
               {:cast, r}

      assert Selector.select(mob(%{ai_state: :combat, owner_player_id: nil}), [r], opts()) == nil
    end

    test "rudeattacked reads the transient flag" do
      r = row(%{condition: %{type: :rudeattacked}})

      assert Selector.select(mob(%{rude_attacked?: true}), [r], opts()) == {:cast, r}
      assert Selector.select(mob(%{rude_attacked?: false}), [r], opts()) == nil
    end

    test "onspawn fires only on the spawn event" do
      r = row(%{condition: %{type: :onspawn}})

      assert Selector.select(mob(), [r], opts(event: :spawn)) == {:cast, r}
      assert Selector.select(mob(), [r], opts(event: :tick)) == nil
      assert Selector.select(mob(), [r], opts()) == nil
    end

    test "casttargeted fires only when a target exists" do
      r = row(%{condition: %{type: :casttargeted}})

      assert Selector.select(mob(%{target_id: 42}), [r], opts()) == {:cast, r}
      assert Selector.select(mob(%{target_id: nil}), [r], opts()) == nil
    end

    test "slavele fires when the master's living-slave count is at or below the value" do
      r = row(%{condition: %{type: :slavele, value: 3}})
      mob = mob(%{instance_id: 9001})

      counts = fn count -> opts(count_living_slaves: fn 9001 -> count end) end

      assert Selector.select(mob, [r], counts.(3)) == {:cast, r}
      assert Selector.select(mob, [r], counts.(0)) == {:cast, r}
      assert Selector.select(mob, [r], counts.(4)) == nil
    end

    test "an unsupported condition type never fires" do
      r = row(%{condition: %{type: :skillused, value: 100}})

      assert Selector.select(mob(), [r], opts()) == nil
    end
  end

  describe "delay gate" do
    test "a row still on cooldown is excluded" do
      mob = mob(%{skill_cooldowns: %{19 => 5000}})

      assert Selector.select(mob, [row()], now: 1000, rng: hit()) == nil
    end

    test "a row whose cooldown has elapsed is eligible" do
      mob = mob(%{skill_cooldowns: %{19 => 5000}})

      assert Selector.select(mob, [row()], now: 5000, rng: hit()) == {:cast, row()}
    end
  end

  describe "rate roll" do
    test "a roll above the row rate does not select it" do
      r = row(%{rate: 5000})

      assert Selector.select(mob(), [r], opts(rng: fn _ -> 5001 end)) == nil
    end

    test "a roll at or below the row rate selects it" do
      r = row(%{rate: 5000})

      assert Selector.select(mob(), [r], opts(rng: fn _ -> 5000 end)) == {:cast, r}
    end

    test "first eligible row that passes its roll wins" do
      first = row(%{skill: "NPC_FIREATTACK", rate: 10_000})
      second = row(%{skill: "NPC_WATERATTACK", rate: 10_000})

      assert Selector.select(mob(), [first, second], opts()) == {:cast, first}
    end

    test "a failing earlier row lets a later row win" do
      first = row(%{skill: "NPC_FIREATTACK", rate: 0})
      second = row(%{skill: "NPC_WATERATTACK", rate: 10_000})

      assert Selector.select(mob(), [first, second], opts(rng: fn n -> n end)) ==
               {:cast, second}
    end

    test "no surviving row returns nil" do
      assert Selector.select(mob(), [], opts()) == nil
      assert Selector.select(mob(), [row(%{rate: 0})], opts(rng: miss())) == nil
    end
  end
end

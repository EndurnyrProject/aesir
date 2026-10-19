defmodule Aesir.ZoneServer.Mmo.MobSkill.SelectorTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.MobSkill.Selector
  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :verify_on_exit!

  # Forces every rate roll to succeed (1 <= rate for any rate >= 1).
  defp hit, do: fn _ -> 1 end
  # Forces every rate roll to fail against any rate < 10_000.
  defp miss, do: fn _ -> 10_000 end

  defp mob(overrides \\ %{}) do
    base = %{
      skill_state: :berserk,
      hp: 100,
      max_hp: 100,
      target_ref: {:player, 1},
      attacked_count: 0,
      skill_cooldowns: %{},
      mob_data: Aesir.TestMob.definition()
    }

    {max_hp, fields} = base |> Map.merge(Map.new(overrides)) |> Map.pop!(:max_hp)
    MobState |> struct(fields) |> Aesir.TestMob.publish(max_hp: max_hp)
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
    test "an :attack-state row fires in the berserk state only" do
      assert Selector.select(mob(%{skill_state: :berserk}), [row(%{state: :attack})], opts()) ==
               {:cast, row(%{state: :attack})}

      assert Selector.select(mob(%{skill_state: :angry}), [row(%{state: :attack})], opts()) == nil
    end

    test "an :angry-state row fires in the angry state only" do
      assert Selector.select(mob(%{skill_state: :angry}), [row(%{state: :angry})], opts()) ==
               {:cast, row(%{state: :angry})}

      assert Selector.select(mob(%{skill_state: :berserk}), [row(%{state: :angry})], opts()) ==
               nil
    end

    test "chase, follow, idle, walk, loot and dead rows fire in their own state" do
      for {row_state, skill_state} <- [
            chase: :rush,
            follow: :follow,
            idle: :idle,
            walk: :walk,
            loot: :loot,
            dead: :dead
          ] do
        r = row(%{state: row_state})
        assert Selector.select(mob(%{skill_state: skill_state}), [r], opts()) == {:cast, r}
      end

      assert Selector.select(mob(%{skill_state: :follow}), [row(%{state: :chase})], opts()) ==
               nil
    end

    test "an :any-state row fires in every state but dead" do
      any_row = row(%{state: :any})

      for skill_state <- [:idle, :walk, :loot, :berserk, :angry, :rush, :follow] do
        assert Selector.select(mob(%{skill_state: skill_state}), [any_row], opts()) ==
                 {:cast, any_row}
      end

      assert Selector.select(mob(%{skill_state: :dead}), [any_row], opts()) == nil
    end

    test "an :anytarget row fires with a target in every state but dead and loot" do
      r = row(%{state: :anytarget})

      for skill_state <- [:idle, :walk, :berserk, :angry, :rush, :follow] do
        assert Selector.select(mob(%{skill_state: skill_state}), [r], opts()) == {:cast, r}
      end

      assert Selector.select(mob(%{skill_state: :loot}), [r], opts()) == nil
      assert Selector.select(mob(%{skill_state: :dead}), [r], opts()) == nil
      assert Selector.select(mob(%{skill_state: :berserk, target_ref: nil}), [r], opts()) == nil
    end
  end

  describe "castable filter" do
    test "a row whose skill_id has no catalog entry is skipped" do
      unresolvable = row(%{skill_id: 999_999})

      assert Selector.select(mob(), [unresolvable], opts()) == nil
    end

    test "a row whose skill is uncastable for a mob is skipped" do
      stub(Castability, :check, fn _definition, :mob ->
        {:error, {:missing, [:player_state]}}
      end)

      assert Selector.select(mob(), [row()], opts()) == nil
    end

    test "a row whose skill resolves and is castable for a mob fires" do
      stub(Castability, :check, fn _definition, :mob -> :ok end)

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

    test "HP rates are rounded down before the comparison" do
      r = row(%{condition: %{type: :myhpltmaxrate, value: 33}})

      assert Selector.select(mob(%{hp: 1, max_hp: 3}), [r], opts()) == {:cast, r}
    end

    test "myhpinrate fires when the HP rate lies in the band" do
      r = row(%{condition: %{type: :myhpinrate, value: 20, val1: 40}})

      assert Selector.select(mob(%{hp: 20, max_hp: 100}), [r], opts()) == {:cast, r}
      assert Selector.select(mob(%{hp: 40, max_hp: 100}), [r], opts()) == {:cast, r}
      assert Selector.select(mob(%{hp: 19, max_hp: 100}), [r], opts()) == nil
      assert Selector.select(mob(%{hp: 41, max_hp: 100}), [r], opts()) == nil
    end

    test "mystatuson/off read the mob's statuses; a mob with none is never off" do
      on = row(%{condition: %{type: :mystatuson, value: :hiding}})
      off = row(%{condition: %{type: :mystatusoff, value: :hiding}})
      anybad_on = row(%{condition: %{type: :mystatuson, value: :anybad}})
      anybad_off = row(%{condition: %{type: :mystatusoff, value: :anybad}})
      stone = row(%{condition: %{type: :mystatuson, value: 0}})
      with_statuses = fn statuses -> opts(mob_statuses: fn %MobState{} -> statuses end) end

      assert Selector.select(mob(), [on], with_statuses.([:sc_hiding])) == {:cast, on}
      assert Selector.select(mob(), [on], with_statuses.([:sc_blind])) == nil
      assert Selector.select(mob(), [off], with_statuses.([:sc_blind])) == {:cast, off}
      assert Selector.select(mob(), [off], with_statuses.([])) == nil

      assert Selector.select(mob(), [anybad_on], with_statuses.([:sc_blind])) ==
               {:cast, anybad_on}

      assert Selector.select(mob(), [anybad_on], with_statuses.([:sc_hiding])) == nil

      assert Selector.select(mob(), [anybad_off], with_statuses.([:sc_hiding])) ==
               {:cast, anybad_off}

      assert Selector.select(mob(), [stone], with_statuses.([:sc_stone])) == {:cast, stone}
    end

    test "friendstatuson/off fire when a friend with/without the status is found" do
      on = row(%{condition: %{type: :friendstatuson, value: :anybad}})
      off = row(%{condition: %{type: :friendstatusoff, value: :hiding}})
      mob = mob(%{instance_id: 9001})

      found = fn expected ->
        opts(
          status_friend: fn %MobState{instance_id: 9001}, on?, status ->
            if {on?, status} == expected, do: {:mob, 9002}
          end
        )
      end

      assert Selector.select(mob, [on], found.({true, :anybad})) == {:cast, on}
      assert Selector.select(mob, [off], found.({false, :hiding})) == {:cast, off}
      assert Selector.select(mob, [on], found.(:none)) == nil
    end

    test "slavelt fires when the living-slave count is below the value" do
      r = row(%{condition: %{type: :slavelt, value: 3}})
      mob = mob(%{instance_id: 9001})

      counts = fn count -> opts(count_living_slaves: fn 9001 -> count end) end

      assert Selector.select(mob, [r], counts.(2)) == {:cast, r}
      assert Selector.select(mob, [r], counts.(3)) == nil
    end

    test "attackpcgt/ge count the units attacking the mob" do
      gt = row(%{condition: %{type: :attackpcgt, value: 2}})
      ge = row(%{condition: %{type: :attackpcge, value: 2}})
      mob = mob(%{instance_id: 9001})

      attacked_by = fn count -> opts(targeted_count: fn {:mob, 9001} -> count end) end

      assert Selector.select(mob, [gt], attacked_by.(3)) == {:cast, gt}
      assert Selector.select(mob, [gt], attacked_by.(2)) == nil
      assert Selector.select(mob, [ge], attacked_by.(2)) == {:cast, ge}
      assert Selector.select(mob, [ge], attacked_by.(1)) == nil
    end

    test "masterattacked fires when someone attacks a living master, never without a master" do
      r = row(%{condition: %{type: :masterattacked}})

      attacked_by = fn count ->
        opts(
          targeted_count: fn {:mob, 7} -> count end,
          living_unit: fn {:mob, 7} -> true end
        )
      end

      assert Selector.select(mob(%{master_id: 7}), [r], attacked_by.(1)) == {:cast, r}
      assert Selector.select(mob(%{master_id: 7}), [r], attacked_by.(0)) == nil
      assert Selector.select(mob(%{master_id: nil}), [r], attacked_by.(1)) == nil

      gone = opts(targeted_count: fn _ -> 1 end, living_unit: fn {:mob, 7} -> false end)
      assert Selector.select(mob(%{master_id: 7}), [r], gone) == nil
    end

    test "mobnearbygt counts the monsters within the visual area, the mob included" do
      r = row(%{condition: %{type: :mobnearbygt, value: 2}})
      nearby = fn count -> opts(nearby_mobs: fn %MobState{} -> count end) end

      assert Selector.select(mob(), [r], nearby.(3)) == {:cast, r}
      assert Selector.select(mob(), [r], nearby.(2)) == nil
    end

    test "afterskill fires when the mob's last skill use is the given skill" do
      r = row(%{condition: %{type: :afterskill, value: 19}})

      assert Selector.select(mob(%{last_skill_id: 19}), [r], opts()) == {:cast, r}
      assert Selector.select(mob(%{last_skill_id: 20}), [r], opts()) == nil
      assert Selector.select(mob(%{last_skill_id: nil}), [r], opts()) == nil
    end

    test "alchemist fires only for damaged player-owned mobs" do
      r = row(%{condition: %{type: :alchemist}})

      assert Selector.select(mob(%{owner_player_id: 42, hp: 99}), [r], opts()) == {:cast, r}
      assert Selector.select(mob(%{owner_player_id: 42, hp: 100}), [r], opts()) == nil
      assert Selector.select(mob(%{owner_player_id: nil, hp: 99}), [r], opts()) == nil

      assert Selector.select(mob(%{owner_player_id: 42, hp: 99, trickcasting: 1}), [r], opts()) ==
               nil
    end

    test "trickcasting fires while a trick cast is kept" do
      r = row(%{condition: %{type: :trickcasting}})

      assert Selector.select(mob(%{trickcasting: 1}), [r], opts()) == {:cast, r}
      assert Selector.select(mob(%{trickcasting: nil}), [r], opts()) == nil
    end

    test "idle rows stay eligible in combat for player-owned mobs" do
      r = row(%{state: :idle})

      assert Selector.select(mob(%{skill_state: :berserk, owner_player_id: 42}), [r], opts()) ==
               {:cast, r}

      assert Selector.select(mob(%{skill_state: :berserk, owner_player_id: nil}), [r], opts()) ==
               nil
    end

    test "a periodic rudeattacked row needs at least one counted rude attack" do
      r = row(%{condition: %{type: :rudeattacked}})

      assert Selector.select(mob(%{attacked_count: 1}), [r], opts()) == {:cast, r}
      assert Selector.select(mob(%{attacked_count: 0}), [r], opts()) == nil
    end

    test "the rude-attacked event fires only rudeattacked rows, whatever the count" do
      rude = row(%{condition: %{type: :rudeattacked}})
      always = row(%{condition: %{type: :always}})
      event = Keyword.put(opts(), :event, :rudeattacked)

      assert Selector.select(mob(%{attacked_count: 0}), [always, rude], event) == {:cast, rude}
      assert Selector.select(mob(%{attacked_count: 0}), [always], event) == nil
    end

    test "onspawn fires only on the spawn event" do
      r = row(%{condition: %{type: :onspawn}})

      assert Selector.select(mob(), [r], opts(event: :spawn)) == {:cast, r}
      assert Selector.select(mob(), [r], opts(event: :tick)) == nil
      assert Selector.select(mob(), [r], opts()) == nil
    end

    test "the spawn event fires only onspawn rows" do
      assert Selector.select(mob(), [row()], opts(event: :spawn)) == nil
    end

    test "event conditions never fire on a periodic check" do
      for type <- [
            :casttargeted,
            :skillused,
            :closedattacked,
            :longrangeattacked,
            :groundattacked,
            :damagedgt
          ] do
        r = row(%{condition: %{type: type, value: 100}})
        assert Selector.select(mob(%{target_ref: {:player, 42}}), [r], opts()) == nil
      end
    end

    test "slavele fires when the master's living-slave count is at or below the value" do
      r = row(%{condition: %{type: :slavele, value: 3}})
      mob = mob(%{instance_id: 9001})

      counts = fn count -> opts(count_living_slaves: fn 9001 -> count end) end

      assert Selector.select(mob, [r], counts.(3)) == {:cast, r}
      assert Selector.select(mob, [r], counts.(0)) == {:cast, r}
      assert Selector.select(mob, [r], counts.(4)) == nil
    end

    test "friendhpltmaxrate and friendhpinrate fire when a friend in the HP band is found" do
      lt = row(%{condition: %{type: :friendhpltmaxrate, value: 60}})
      band = row(%{condition: %{type: :friendhpinrate, value: 20, val1: 40}})
      mob = mob(%{instance_id: 9001})

      found = fn expected ->
        opts(
          hp_rate_friend: fn %MobState{instance_id: 9001}, low, high ->
            if {low, high} == expected, do: {:mob, 9002}
          end
        )
      end

      assert Selector.select(mob, [lt], found.({0, 60})) == {:cast, lt}
      assert Selector.select(mob, [band], found.({20, 40})) == {:cast, band}
      assert Selector.select(mob, [lt], found.(:none)) == nil
    end

    test "an unknown condition type never fires" do
      r = row(%{condition: %{type: :no_such_condition, value: 100}})

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

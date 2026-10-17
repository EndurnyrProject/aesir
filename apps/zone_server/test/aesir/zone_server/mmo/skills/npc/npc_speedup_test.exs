defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSpeedupTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcSpeedup
  alias Aesir.ZoneServer.Unit.Mob.MobState

  test "speeds the trick-casting mob up while more than 700 ms are left" do
    now = System.system_time(:millisecond)
    mob = mob(trickcasting: now + 3_000, last_skillcheck: now)

    assert {:ok, faster} = NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})

    assert faster.walk_speed == 550
    assert faster.trickcasting == mob.trickcasting
    assert faster.last_skillcheck == now
    assert faster.can_escape
  end

  test "the last interval delays the next skill check by 100 ms" do
    now = System.system_time(:millisecond)
    mob = mob(trickcasting: now + 1_200, last_skillcheck: now)

    assert {:ok, faster} = NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})

    assert faster.walk_speed == 550
    assert faster.last_skillcheck in (now + 100)..(System.system_time(:millisecond) + 100)
  end

  test "never drops below the minimum walk speed" do
    now = System.system_time(:millisecond)
    mob = mob(trickcasting: now + 3_000, walk_speed: 100)

    assert {:ok, %MobState{walk_speed: 20}} =
             NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})
  end

  test "under 700 ms left it ends the trick cast and the escape" do
    now = System.system_time(:millisecond)
    mob = mob(trickcasting: now + 500, last_skillcheck: now)

    assert {:ok, stopped} = NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})

    assert stopped.walk_speed == 800
    assert stopped.trickcasting == nil
    assert stopped.last_skillcheck == now + 500
    refute stopped.can_escape
  end

  test "without a trick cast it only resets the escape" do
    mob = mob(trickcasting: nil, last_skillcheck: 123)

    assert {:ok, stopped} = NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})

    assert stopped.walk_speed == 800
    assert stopped.last_skillcheck == 0
    refute stopped.can_escape
  end

  test "only a monster casts it" do
    assert {:error, :mob_only} = NpcSpeedup.cast(mob([]), {:unit, 7}, 1, definition())
  end

  defp definition, do: NpcSpeedup.definition()

  defp mob(fields) do
    struct(
      MobState,
      Keyword.merge([instance_id: 7, mob_id: 1142, walk_speed: 800, can_escape: true], fields)
    )
  end
end

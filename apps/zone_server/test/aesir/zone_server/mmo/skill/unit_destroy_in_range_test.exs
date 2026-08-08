defmodule Aesir.ZoneServer.Mmo.Skill.UnitDestroyInRangeTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Unit.Broadcast

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    Mimic.copy(Broadcast)
    allow(Broadcast, self(), manager)
    stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)
    :ok
  end

  test "destroys only named groups whose footprints are in range" do
    matching_in_range = group(1, :matching_skill, {10, 10})
    other_in_range = group(2, :other_skill, {10, 11})
    matching_out_of_range = group(3, :matching_skill, {20, 20})

    assert :ok = Manager.register(matching_in_range)
    assert :ok = Manager.register(other_in_range)
    assert :ok = Manager.register(matching_out_of_range)

    assert :ok = Unit.destroy_in_range("prontera", {10, 10}, 2, [:matching_skill])

    assert :error = Unit.fetch(matching_in_range.group_id)
    assert {:ok, ^other_in_range} = Unit.fetch(other_in_range.group_id)
    assert {:ok, ^matching_out_of_range} = Unit.fetch(matching_out_of_range.group_id)
  end

  defp group(group_id, skill_name, {x, y}) do
    %Group{
      group_id: group_id,
      skill_id: group_id,
      skill_name: skill_name,
      level: 1,
      caster_id: group_id,
      caster_type: :player,
      map_name: "prontera",
      center: {x, y},
      cells: [{x, y}],
      next_tick_at: 10_000,
      expires_at: 20_000,
      interval: 450
    }
  end
end

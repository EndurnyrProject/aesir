defmodule Aesir.ZoneServer.Mmo.SkillUnit.TickManagerTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.SkillUnit.Behaviors
  alias Aesir.ZoneServer.Mmo.SkillUnit.Group
  alias Aesir.ZoneServer.Mmo.SkillUnit.Storage
  alias Aesir.ZoneServer.Mmo.SkillUnit.TickManager

  setup :setup_ets_tables
  setup :verify_on_exit!
  setup :set_mimic_global

  defmodule FakeUnit do
    use Aesir.ZoneServer.Mmo.SkillUnit.Behaviour

    @impl true
    def skill_name, do: :fake_unit

    @impl true
    def on_place(%Group{center: center}) do
      {:ok, %{cells: [center], state: %{}, interval: 450, duration: 5_000}}
    end

    @impl true
    def on_interval(%Group{state: state} = group, _now) do
      if Map.get(state, :expire_now) do
        {:expire, group}
      else
        {:ok, %{group | state: Map.update(state, :ticks, 1, &(&1 + 1))}}
      end
    end

    @impl true
    def on_expire(%Group{group_id: group_id}) do
      send(self(), {:expired, group_id})
      :ok
    end
  end

  setup do
    Mimic.copy(Behaviors)
    stub(Behaviors, :module_for, fn :fake_unit -> {:ok, FakeUnit} end)
    :ok
  end

  defp group(group_id, attrs) do
    base = %Group{
      group_id: group_id,
      skill_id: 0,
      skill_name: :fake_unit,
      level: 1,
      caster_id: 1,
      caster_type: :player,
      map_name: "prontera",
      center: {100, 100},
      cells: [{100, 100}],
      next_tick_at: 0,
      expires_at: 1_000_000,
      interval: 450,
      state: %{}
    }

    struct(base, attrs)
  end

  describe "process_tick/1" do
    test "runs on_interval only for due groups and re-arms next_tick_at" do
      now = 10_000
      :ok = Storage.insert(group(1, next_tick_at: now - 10, interval: 450))
      :ok = Storage.insert(group(2, next_tick_at: now + 500))

      TickManager.process_tick(now)

      updated = Storage.get(1)
      assert updated.next_tick_at == now + 450
      assert updated.state[:ticks] == 1

      untouched = Storage.get(2)
      assert untouched.next_tick_at == now + 500
      assert untouched.state == %{}
    end

    test "on_interval returning {:expire, _} deletes the group" do
      now = 10_000

      :ok =
        Storage.insert(group(1, next_tick_at: now - 10, state: %{expire_now: true}))

      TickManager.process_tick(now)

      assert_received {:expired, 1}
      assert nil == Storage.get(1)
    end

    test "runs on_expire and deletes groups past expires_at" do
      now = 10_000
      :ok = Storage.insert(group(1, next_tick_at: now + 5_000, expires_at: now - 10))

      TickManager.process_tick(now)

      assert_received {:expired, 1}
      assert nil == Storage.get(1)
    end

    test "runs on_expire at most once for a group both due and expired in the same tick" do
      now = 10_000

      :ok =
        Storage.insert(
          group(1,
            next_tick_at: now - 10,
            expires_at: now - 10,
            state: %{expire_now: true}
          )
        )

      TickManager.process_tick(now)

      assert_received {:expired, 1}
      refute_received {:expired, 1}
      assert nil == Storage.get(1)
    end
  end
end

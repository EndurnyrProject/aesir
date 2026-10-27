defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StoneTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Stone
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEntry

  setup :set_mimic_private

  describe "steps/1 and lifetime/1" do
    test "drain every 5 seconds while time remains; the last step ends it" do
      assert Stone.steps(12_000) == [{5_000, true}, {10_000, true}, {12_000, false}]
      assert Stone.lifetime(12_000) == 12_000
    end

    test "a step landing exactly on the end still drains" do
      assert Stone.steps(15_000) == [{5_000, true}, {10_000, true}, {15_000, true}]
    end

    test "lasts at least one step and drops a final remainder under 100 ms" do
      assert Stone.lifetime(1) == 5_000
      assert Stone.steps(10_050) == [{5_000, true}, {10_000, true}]
      assert Stone.lifetime(10_050) == 10_000
    end
  end

  test "drains 1% of Max HP, at least 1" do
    assert Stone.drain(1_000) == 10
    assert Stone.drain(50) == 1
    assert Stone.drain(250_000) == 2_500
  end

  describe "drain timing" do
    defp step(petrify_ms, step_ms) do
      now = System.monotonic_time(:millisecond)

      %StatusEntry{
        type: :sc_stone,
        val3: petrify_ms,
        tick: 5_000,
        state: %{},
        started_at: now - step_ms,
        next_tick_at: now,
        expires_at: now - step_ms + Stone.lifetime(petrify_ms)
      }
    end

    @healthy %{target: %{hp: 1_000, max_hp: 1_000}}

    test "runs every 5 seconds" do
      assert Stone.metadata().tick_interval == 5_000
    end

    test "a step while time remains drains" do
      expect(Helpers, :apply_passive_hp_loss, fn {:mob, 1}, 10 -> :ok end)

      assert {:ok, _} = Stone.on_tick({:mob, 1}, step(12_000, 5_000), @healthy)
    end

    test "a step landing exactly on the end still drains" do
      expect(Helpers, :apply_passive_hp_loss, fn {:mob, 1}, 10 -> :ok end)

      assert {:ok, _} = Stone.on_tick({:mob, 1}, step(15_000, 15_000), @healthy)
    end

    test "the step after a short petrification ran out does not drain" do
      reject(&Helpers.apply_passive_hp_loss/2)

      assert {:ok, _} = Stone.on_tick({:mob, 1}, step(3_000, 5_000), @healthy)
    end

    test "a restored petrification counts its steps from the original start" do
      reject(&Helpers.apply_passive_hp_loss/2)
      restored = %{step(3_000, 5_000) | started_at: System.monotonic_time(:millisecond) - 2_000}

      assert {:ok, _} = Stone.on_tick({:mob, 1}, restored, @healthy)
    end

    test "no drain at a quarter of Max HP or below" do
      reject(&Helpers.apply_passive_hp_loss/2)

      assert {:ok, _} =
               Stone.on_tick({:mob, 1}, step(12_000, 5_000), %{
                 target: %{hp: 250, max_hp: 1_000}
               })
    end
  end

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_stone, state: %{}}, overrides)

  describe "speed handling (rAthena: SC_STONE is absent from status_calc_speed)" do
    test "does not declare a :speed calc flag" do
      refute :speed in Stone.metadata().calc_flags
    end

    test "wait phase carries no :movement_speed modifier" do
      refute Map.has_key?(Stone.modifiers(entry(phase: :wait), %{}), :movement_speed)
    end

    test "stone phase carries no :movement_speed modifier" do
      refute Map.has_key?(Stone.modifiers(entry(phase: :stone), %{}), :movement_speed)
    end
  end
end

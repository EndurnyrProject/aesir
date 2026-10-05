defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StoneWaitTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.StoneWait
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(state), do: %StatusEntry{type: :sc_stonewait, state: state}

  describe "resolve_duration/2" do
    test "waits the given delay and keeps the rest of the duration for the petrification" do
      assert {5_000, %StatusEntry{val3: 12_000}} =
               StoneWait.resolve_duration(entry(%{delay: 5_000}), 17_000)
    end

    test "waits 100 ms unless a delay is given" do
      assert {100, %StatusEntry{val3: 19_900}} = StoneWait.resolve_duration(entry(%{}), 20_000)
    end

    test "keeps at least 1 ms for the petrification" do
      assert {5_000, %StatusEntry{val3: 1}} =
               StoneWait.resolve_duration(entry(%{delay: 5_000}), 4_000)
    end
  end

  test "running out starts an unavoidable petrification lasting the kept duration" do
    instance = %{entry(%{}) | val1: 4, val2: 7, val3: 12_000, source_id: 7, source_type: :player}

    assert [{:sc_stone, params}] = StoneWait.on_timeout({:mob, 1}, instance, %{})
    assert params[:duration] == 12_000
    assert params[:no_avoid] == true
    assert params[:val1] == 4
    assert params[:caster_id] == 7
  end
end

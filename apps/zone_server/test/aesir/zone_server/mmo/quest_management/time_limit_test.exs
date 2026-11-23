defmodule Aesir.ZoneServer.Mmo.QuestManagement.TimeLimitTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.QuestManagement.TimeLimit

  describe "parse/1" do
    test "reads a missing limit as none" do
      assert {:ok, :none} = TimeLimit.parse(nil)
      assert {:ok, :none} = TimeLimit.parse("")
    end

    test "reads a time of day with an optional weekday and day offset" do
      assert {:ok, {:at, 14_400, -1}} = TimeLimit.parse("4h")
      assert {:ok, {:at, 16_200, -1}} = TimeLimit.parse("4h 30mn")
      assert {:ok, {:at, 619_200, -1}} = TimeLimit.parse("7d 4h")
      assert {:ok, {:at, 14_400, 1}} = TimeLimit.parse("Monday 4h")
      assert {:ok, {:at, 14_400, 0}} = TimeLimit.parse("SUNDAY 4h")
    end

    test "drops the day offset after a weekday, except Sunday, like rAthena" do
      assert {:ok, {:at, 14_400, 1}} = TimeLimit.parse("Monday 2d 4h")
      assert {:ok, {:at, 187_200, 0}} = TimeLimit.parse("SUNDAY 2d 4h")
    end

    test "reads a relative limit as seconds" do
      assert {:ok, {:relative, 10_800}} = TimeLimit.parse("+3h")
      assert {:ok, {:relative, 600}} = TimeLimit.parse("+10mn")
      assert {:ok, {:relative, 86_400}} = TimeLimit.parse("+1d")
      assert {:ok, {:relative, 30}} = TimeLimit.parse("+30s")
      assert {:ok, {:relative, 5_400}} = TimeLimit.parse("+1h30mn")
      assert {:ok, {:relative, 129_600}} = TimeLimit.parse("+1d12h")
    end

    test "rejects out of range or unknown absolute times" do
      for input <- ["24h", "4h 60mn", "4x"] do
        assert {:error, reason} = TimeLimit.parse(input)
        assert reason =~ input
      end
    end

    test "rejects a relative limit that is not in the future" do
      for input <- ["+0s", "+"] do
        assert {:error, reason} = TimeLimit.parse(input)
        assert reason =~ input
      end
    end

    test "rejects relative months and years, which need a calendar" do
      assert {:error, _} = TimeLimit.parse("+1m")
      assert {:error, _} = TimeLimit.parse("+1y")
    end
  end

  describe "parse!/1" do
    test "returns the parsed limit" do
      assert :none = TimeLimit.parse!(nil)
      assert {:at, 14_400, -1} = TimeLimit.parse!("4h")
    end

    test "raises naming the string" do
      assert_raise ArgumentError, ~r/24h/, fn -> TimeLimit.parse!("24h") end
    end
  end

  describe "deadline/3" do
    test "none is zero" do
      assert 0 = TimeLimit.deadline(:none, unix(~N[2026-11-21 03:00:00]), ~N[2026-11-21 03:00:00])
    end

    test "relative adds the seconds to now" do
      now = unix(~N[2026-11-21 03:00:00])
      assert now + 14_400 == TimeLimit.deadline({:relative, 14_400}, now, ~N[2026-11-21 03:00:00])
    end

    test "a time of day is today before it and tomorrow from it on" do
      limit = {:at, 14_400, -1}

      assert unix(~N[2026-11-21 04:00:00]) == deadline(limit, ~N[2026-11-21 03:00:00])
      assert unix(~N[2026-11-22 04:00:00]) == deadline(limit, ~N[2026-11-21 05:00:00])
      assert unix(~N[2026-11-22 04:00:00]) == deadline(limit, ~N[2026-11-21 04:00:00])
    end

    test "a day offset is added after the next time of day" do
      assert unix(~N[2026-11-25 04:00:00]) ==
               deadline({:at, 3 * 86_400 + 14_400, -1}, ~N[2026-11-21 05:00:00])
    end

    test "a weekday is the next such day, a week on once its time has passed" do
      limit = {:at, 14_400, 1}

      assert unix(~N[2026-11-23 04:00:00]) == deadline(limit, ~N[2026-11-21 03:00:00])
      assert unix(~N[2026-11-23 04:00:00]) == deadline(limit, ~N[2026-11-23 03:00:00])
      assert unix(~N[2026-11-30 04:00:00]) == deadline(limit, ~N[2026-11-23 05:00:00])
    end

    test "Sunday is week 0" do
      assert unix(~N[2026-11-22 04:00:00]) == deadline({:at, 14_400, 0}, ~N[2026-11-21 05:00:00])
    end
  end

  defp deadline(limit, local_now), do: TimeLimit.deadline(limit, unix(local_now), local_now)

  defp unix(naive), do: naive |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
end

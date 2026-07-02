defmodule Aesir.ZoneServer.Party.StateTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State

  defp member(char_id, base_level, online, opts \\ []) do
    Member.new(
      char_id,
      Keyword.get(opts, :name, "member-#{char_id}"),
      base_level,
      online,
      Keyword.get(opts, :map_name, "prontera")
    )
  end

  defp state(members) do
    %State{
      party_id: 1,
      name: "Test Party",
      leader_char_id: 1,
      exp_share: false,
      members: Map.new(members, &{&1.char_id, &1})
    }
  end

  describe "level_spread/1" do
    test "returns 0 when no members are online" do
      party = state([member(1, 50, false)])

      assert State.level_spread(party) == 0
    end

    test "returns 0 when only one member is online" do
      party = state([member(1, 50, true), member(2, 80, false)])

      assert State.level_spread(party) == 0
    end

    test "returns the max minus min base level over online members" do
      party = state([member(1, 50, true), member(2, 80, true), member(3, 30, false)])

      assert State.level_spread(party) == 30
    end
  end

  describe "full?/1" do
    test "is full at exactly max_party members" do
      members = for id <- 1..Config.max_party(), do: member(id, 50, true)

      assert State.full?(state(members))
    end

    test "is not full at max_party - 1 members" do
      members = for id <- 1..(Config.max_party() - 1), do: member(id, 50, true)

      refute State.full?(state(members))
    end
  end

  describe "member_count/1" do
    test "counts online and offline members" do
      party = state([member(1, 50, true), member(2, 60, false)])

      assert State.member_count(party) == 2
    end
  end

  describe "same_account?/2" do
    test "is true when the account already owns a member" do
      member_account_ids = %{1 => 100, 2 => 200}

      assert State.same_account?(member_account_ids, 200)
    end

    test "is false when no member shares the account" do
      member_account_ids = %{1 => 100, 2 => 200}

      refute State.same_account?(member_account_ids, 300)
    end
  end
end

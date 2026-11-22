defmodule Aesir.ZoneServer.Party.StateTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Party.State

  describe "level_spread/1" do
    test "returns 0 when no members are online" do
      party = build(:party_state, members: [build(:party_member, base_level: 50, online: false)])

      assert State.level_spread(party) == 0
    end

    test "returns 0 when only one member is online" do
      members = [
        build(:party_member, base_level: 50),
        build(:party_member, base_level: 80, online: false)
      ]

      assert State.level_spread(build(:party_state, members: members)) == 0
    end

    test "returns the max minus min base level over online members" do
      members = [
        build(:party_member, base_level: 50),
        build(:party_member, base_level: 80),
        build(:party_member, base_level: 30, online: false)
      ]

      assert State.level_spread(build(:party_state, members: members)) == 30
    end
  end

  describe "full?/1" do
    test "is full at exactly max_party members, including an offline member" do
      members = [
        build(:party_member, online: false) | build_list(Config.max_party() - 1, :party_member)
      ]

      assert State.full?(build(:party_state, members: members))
    end

    test "is not full at max_party - 1 members" do
      members = build_list(Config.max_party() - 1, :party_member)

      refute State.full?(build(:party_state, members: members))
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

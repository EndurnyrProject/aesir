defmodule Aesir.ZoneServer.Guild.PermissionsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Permissions
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.State

  @actions [:invite, :expel, :emblem, :notice, :positions, :assign]

  defp member(char_id, position_index) do
    Member.new(char_id, "member-#{char_id}", 50, true, position_index, "prontera")
  end

  defp state(members, positions) do
    %State{
      guild_id: 1,
      name: "Test Guild",
      master_char_id: 1,
      positions: positions,
      members: Map.new(members, &{&1.char_id, &1})
    }
  end

  describe "master" do
    test "is allowed every action" do
      guild = state([member(1, 0)], Map.new(Position.defaults(), &{&1.index, &1}))

      for action <- @actions do
        assert Permissions.can?(guild, 1, action), "master denied #{action}"
      end
    end
  end

  describe "non-member" do
    test "is denied every action" do
      guild = state([member(1, 0)], %{})

      for action <- @actions do
        refute Permissions.can?(guild, 999, action)
      end
    end
  end

  describe "invite" do
    test "denied when the member's position lacks can_invite" do
      positions = %{5 => %Position{index: 5, can_invite: false}}
      guild = state([member(1, 0), member(2, 5)], positions)

      refute Permissions.can?(guild, 2, :invite)
    end

    test "allowed when the member's position grants can_invite" do
      positions = %{5 => %Position{index: 5, can_invite: true}}
      guild = state([member(1, 0), member(2, 5)], positions)

      assert Permissions.can?(guild, 2, :invite)
    end
  end

  describe "expel" do
    test "allowed when the member's position grants can_expel" do
      positions = %{5 => %Position{index: 5, can_expel: true}}
      guild = state([member(1, 0), member(2, 5)], positions)

      assert Permissions.can?(guild, 2, :expel)
    end

    test "denied when the member's position lacks can_expel" do
      positions = %{5 => %Position{index: 5, can_expel: false}}
      guild = state([member(1, 0), member(2, 5)], positions)

      refute Permissions.can?(guild, 2, :expel)
    end
  end

  describe "master-only actions" do
    test "emblem, positions, assign and notice are denied for any non-master" do
      positions = %{5 => %Position{index: 5, can_invite: true, can_expel: true}}
      guild = state([member(1, 0), member(2, 5)], positions)

      for action <- [:emblem, :positions, :assign, :notice] do
        refute Permissions.can?(guild, 2, action), "non-master allowed #{action}"
      end
    end
  end
end

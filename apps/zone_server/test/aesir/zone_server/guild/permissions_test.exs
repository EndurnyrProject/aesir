defmodule Aesir.ZoneServer.Guild.PermissionsTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Guild.Permissions
  alias Aesir.ZoneServer.Guild.Position

  @actions [:invite, :expel, :storage, :emblem, :notice, :relations, :positions, :assign]

  describe "master" do
    test "is allowed every action" do
      master = build(:guild_member, position_index: 0)
      guild = build(:guild_state, master_char_id: master.char_id, members: [master])

      for action <- @actions do
        assert Permissions.can?(guild, master.char_id, action), "master denied #{action}"
      end
    end
  end

  describe "non-member" do
    test "is denied every action" do
      guild = build(:guild_state, positions: Map.new(Position.defaults(), &{&1.index, &1}))

      for action <- @actions do
        refute Permissions.can?(guild, 999, action)
      end
    end
  end

  describe "position-gated actions" do
    for {action, flag} <- [
          invite: :can_invite,
          expel: :can_expel,
          storage: :can_storage,
          notice: :can_notice,
          relations: :can_relations
        ] do
      @action action
      @flag flag

      test "#{action} follows the member's position #{flag}" do
        granted = build(:guild_member, position_index: 5)
        denied = build(:guild_member, position_index: 6)

        guild =
          build(:guild_state,
            members: [granted, denied],
            positions: %{
              5 => struct!(Position, [{:index, 5}, {@flag, true}]),
              6 => %Position{index: 6}
            }
          )

        assert Permissions.can?(guild, granted.char_id, @action)
        refute Permissions.can?(guild, denied.char_id, @action)
      end
    end
  end

  describe "master-only actions" do
    test "emblem, positions and assign are denied for a non-master holding every flag" do
      officer = build(:guild_member, position_index: 5)

      position = %Position{
        index: 5,
        can_invite: true,
        can_expel: true,
        can_storage: true,
        can_notice: true,
        can_relations: true
      }

      guild = build(:guild_state, members: [officer], positions: %{5 => position})

      for action <- [:emblem, :positions, :assign] do
        refute Permissions.can?(guild, officer.char_id, action), "non-master allowed #{action}"
      end
    end
  end
end

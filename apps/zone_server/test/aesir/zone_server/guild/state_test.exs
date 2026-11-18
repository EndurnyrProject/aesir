defmodule Aesir.ZoneServer.Guild.StateTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.Relation
  alias Aesir.ZoneServer.Guild.State

  @max_members 16
  @gd_extension 10_004

  describe "member_count/1" do
    test "counts offline members toward the cap" do
      members = [
        build(:guild_member, online: false) | build_list(@max_members - 1, :guild_member)
      ]

      guild = build(:guild_state, members: members)

      assert State.member_count(guild) == @max_members
      assert State.full?(guild)
    end
  end

  describe "full?/1" do
    test "is full at exactly 16 members" do
      guild = build(:guild_state, members: build_list(@max_members, :guild_member))

      assert State.full?(guild)
    end
  end

  describe "max_members/1" do
    test "is 16 without extension and 76 at extension 10" do
      assert State.max_members(build(:guild_state)) == 16

      assert State.max_members(build(:guild_state, learned_skills: %{@gd_extension => 10})) ==
               76
    end
  end

  describe "skill_level/2" do
    test "reads learned levels, defaulting to 0" do
      guild = build(:guild_state, learned_skills: %{@gd_extension => 3})

      assert State.skill_level(guild, @gd_extension) == 3
      assert State.skill_level(guild, 10_000) == 0
    end
  end

  describe "position_of/2" do
    test "resolves a member's held position" do
      member = build(:guild_member, position_index: 0)

      guild =
        build(:guild_state,
          members: [member],
          positions: %{0 => %Position{index: 0, name: "GuildMaster"}}
        )

      assert %Position{index: 0, name: "GuildMaster"} = State.position_of(guild, member.char_id)
    end

    test "is nil for a non-member" do
      member = build(:guild_member)
      guild = build(:guild_state, members: [member])

      assert State.position_of(guild, member.char_id + 1) == nil
    end
  end

  describe "ally?/2" do
    test "is false for nil, 0, and an antagonist id" do
      antagonist = %Relation{guild_id: 3, name: "Muspelheim", kind: :antagonist}
      guild = build(:guild_state, relations: %{3 => antagonist})

      refute State.ally?(guild, nil)
      refute State.ally?(guild, 0)
      refute State.ally?(guild, 3)
    end

    test "is true for an ally id" do
      ally = %Relation{guild_id: 2, name: "Asgard", kind: :ally}
      guild = build(:guild_state, relations: %{2 => ally})

      assert State.ally?(guild, 2)
    end
  end
end

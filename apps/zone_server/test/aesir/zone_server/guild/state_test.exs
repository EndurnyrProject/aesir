defmodule Aesir.ZoneServer.Guild.StateTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.State

  @max_members 16

  defp member(char_id, position_index) do
    Member.new(char_id, "member-#{char_id}", 50, true, position_index, "prontera")
  end

  defp state(members, opts \\ []) do
    %State{
      guild_id: 1,
      name: "Test Guild",
      master_char_id: Keyword.get(opts, :master_char_id, 1),
      positions: Keyword.get(opts, :positions, %{}),
      members: Map.new(members, &{&1.char_id, &1}),
      learned_skills: Keyword.get(opts, :learned_skills, %{})
    }
  end

  describe "member_count/1" do
    test "counts online and offline members" do
      assert State.member_count(state([member(1, 0), member(2, 19)])) == 2
    end
  end

  describe "full?/1" do
    test "is full at exactly 16 members" do
      members = for id <- 1..@max_members, do: member(id, 19)

      assert State.full?(state(members))
    end

    test "is not full at 15 members" do
      members = for id <- 1..(@max_members - 1), do: member(id, 19)

      refute State.full?(state(members))
    end

    test "extension raises the cap by 6 per level" do
      members = for id <- 1..@max_members, do: member(id, 19)

      refute State.full?(state(members, learned_skills: %{10_004 => 1}))

      members_22 = for id <- 1..(@max_members + 6), do: member(id, 19)
      assert State.full?(state(members_22, learned_skills: %{10_004 => 1}))
    end
  end

  describe "max_members/1" do
    test "is 16 without extension and 76 at extension 10" do
      assert State.max_members(state([])) == 16
      assert State.max_members(state([], learned_skills: %{10_004 => 10})) == 76
    end
  end

  describe "skill_level/2" do
    test "reads learned levels, defaulting to 0" do
      s = state([], learned_skills: %{10_004 => 3})

      assert State.skill_level(s, 10_004) == 3
      assert State.skill_level(s, 10_000) == 0
    end
  end

  describe "position_of/2" do
    test "resolves a member's held position" do
      positions = %{0 => %Position{index: 0, name: "GuildMaster"}}
      guild = state([member(1, 0)], positions: positions)

      assert %Position{index: 0, name: "GuildMaster"} = State.position_of(guild, 1)
    end

    test "is nil for a non-member" do
      assert State.position_of(state([member(1, 0)]), 999) == nil
    end
  end
end

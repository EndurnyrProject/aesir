defmodule Aesir.ZoneServer.Guild.MemberTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Guild.Member

  describe "new/6" do
    test "builds a member carrying its position index and presence" do
      member = Member.new(7, "Hero", 55, true, 3, "prontera")

      assert member.char_id == 7
      assert member.name == "Hero"
      assert member.base_level == 55
      assert member.position_index == 3
      assert member.online
      assert member.map_name == "prontera"
    end
  end

  describe "from_character/3" do
    test "projects persisted character state at a position" do
      character = %Character{
        id: 12,
        name: "Mage",
        class: 9,
        base_level: 40,
        hp: 100,
        max_hp: 120,
        sp: 30,
        max_sp: 40,
        ap: 5,
        max_ap: 10,
        last_map: "geffen"
      }

      member = Member.from_character(character, true, 19)

      assert member.char_id == 12
      assert member.name == "Mage"
      assert member.job_id == 9
      assert member.base_level == 40
      assert member.position_index == 19
      assert member.hp == 100
      assert member.max_hp == 120
      assert member.online
      assert member.map_name == "geffen"
    end

    test "falls back to safe defaults for nil character fields" do
      character = %Character{id: 1, name: "Novice", class: nil, base_level: nil}

      member = Member.from_character(character, false, 0)

      assert member.job_id == 0
      assert member.base_level == 1
      assert member.position_index == 0
      refute member.online
    end

    test "carries the guild contribution and the last login as unix seconds, 0 when never logged in" do
      seen = %Character{
        id: 1,
        name: "Veteran",
        guild_exp: 4_200,
        last_login: ~N[2026-11-11 20:58:00]
      }

      assert %Member{exp: 4_200, last_seen: 1_794_430_680} =
               Member.from_character(seen, false, 3)

      never = %Character{id: 2, name: "Newcomer"}

      assert %Member{exp: 0, last_seen: 0} = Member.from_character(never, false, 19)
    end
  end
end

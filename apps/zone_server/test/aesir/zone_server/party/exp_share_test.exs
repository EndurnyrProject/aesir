defmodule Aesir.ZoneServer.Party.ExpShareTest do
  @moduledoc """
  Exercises the party even-share EXP formula (design "EXP share"): pool ÷
  eligible count, × bonus ÷ 100, × per-member `LevelPenalty.exp/2` rate ÷ 100,
  each step truncating, floored at 1 when the pre-penalty (post-bonus) slice
  was positive. Also covers `eligible_members/2`'s online/map/alive filter.
  """

  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Party.ExpShare
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    :persistent_term.put({LevelPenalty, :exp}, %{-20 => 90, -40 => 50})

    on_exit(fn -> :persistent_term.erase({LevelPenalty, :exp}) end)

    :ok
  end

  defp member(char_id, base_level, opts \\ []) do
    Member.new(
      char_id,
      Keyword.get(opts, :name, "member-#{char_id}"),
      base_level,
      Keyword.get(opts, :online, true),
      Keyword.get(opts, :map_name, "prontera")
    )
  end

  describe "split/5" do
    test "matches the design's worked formula for a representative 3-member case" do
      members = [member(1, 50), member(2, 70), member(3, 90)]

      shares = ExpShare.split(100, 60, members, 10, 50)

      assert shares == %{
               1 => {39, 24},
               2 => {35, 21},
               3 => {19, 12}
             }
    end

    test "floors a positive pooled slice at 1 instead of rounding to 0 after the penalty" do
      shares = ExpShare.split(10, 1, [member(1, 90)], 0, 50)

      assert shares == %{1 => {5, 1}}
    end

    test "returns an empty map when there are no eligible members" do
      assert ExpShare.split(100, 50, [], 0, 50) == %{}
    end

    test "applies no bonus scaling at even_share_bonus 0" do
      members = [member(1, 50), member(2, 50)]

      shares = ExpShare.split(100, 40, members, 0, 50)

      assert shares == %{1 => {50, 20}, 2 => {50, 20}}
    end
  end

  describe "eligible_members/2" do
    defp register_player(char_id, map_name, hp) do
      UnitRegistry.register_unit(
        :player,
        char_id,
        Aesir.ZoneServer.Unit.Player.PlayerState,
        %{map_name: map_name, stats: %{current_state: %{hp: hp}}},
        self()
      )
    end

    test "excludes an offline member without a registry lookup" do
      register_player(1, "prontera", 100)

      party_state = %State{
        party_id: 1,
        name: "Party",
        leader_char_id: 1,
        exp_share: true,
        members: %{
          1 => member(1, 50, online: true, map_name: "prontera"),
          2 => member(2, 50, online: false, map_name: "prontera")
        }
      }

      assert [%Member{char_id: 1}] = ExpShare.eligible_members(party_state, "prontera")
    end

    test "excludes a member on a different map" do
      register_player(1, "prontera", 100)
      register_player(2, "geffen", 100)

      party_state = %State{
        party_id: 1,
        name: "Party",
        leader_char_id: 1,
        exp_share: true,
        members: %{
          1 => member(1, 50, online: true, map_name: "prontera"),
          2 => member(2, 50, online: true, map_name: "geffen")
        }
      }

      assert [%Member{char_id: 1}] = ExpShare.eligible_members(party_state, "prontera")
    end

    test "excludes a dead member" do
      register_player(1, "prontera", 100)
      register_player(2, "prontera", 0)

      party_state = %State{
        party_id: 1,
        name: "Party",
        leader_char_id: 1,
        exp_share: true,
        members: %{
          1 => member(1, 50, online: true, map_name: "prontera"),
          2 => member(2, 50, online: true, map_name: "prontera")
        }
      }

      assert [%Member{char_id: 1}] = ExpShare.eligible_members(party_state, "prontera")
    end

    test "skips a member whose registry lookup 404s" do
      register_player(1, "prontera", 100)

      party_state = %State{
        party_id: 1,
        name: "Party",
        leader_char_id: 1,
        exp_share: true,
        members: %{
          1 => member(1, 50, online: true, map_name: "prontera"),
          2 => member(2, 50, online: true, map_name: "prontera")
        }
      }

      assert [%Member{char_id: 1}] = ExpShare.eligible_members(party_state, "prontera")
    end
  end
end

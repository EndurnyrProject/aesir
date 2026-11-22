defmodule Aesir.ZoneServer.Party.ExpShareTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Party.ExpShare
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context

  describe "split/5" do
    test "truncates the split before applying the party bonus and each member's penalty" do
      stub(LevelPenalty, :exp, fn
        50, 50 -> 100
        50, 70 -> 90
        50, 90 -> 50
      end)

      members = [
        build(:party_member, char_id: 1, base_level: 50),
        build(:party_member, char_id: 2, base_level: 70),
        build(:party_member, char_id: 3, base_level: 90)
      ]

      assert ExpShare.split(100, 60, members, 10, 50) == %{
               1 => {39, 24},
               2 => {35, 21},
               3 => {19, 12}
             }
    end

    test "floors a positive pooled slice at 1 instead of rounding to 0 after the penalty" do
      stub(LevelPenalty, :exp, fn 50, 90 -> 50 end)
      member = build(:party_member, char_id: 1, base_level: 90)

      assert ExpShare.split(10, 1, [member], 0, 50) == %{1 => {5, 1}}
    end

    test "returns an empty map when there are no eligible members" do
      assert ExpShare.split(100, 50, [], 0, 50) == %{}
    end

    test "applies no bonus scaling at even_share_bonus 0" do
      stub(LevelPenalty, :exp, fn 50, 50 -> 100 end)

      members = [
        build(:party_member, char_id: 1, base_level: 50),
        build(:party_member, char_id: 2, base_level: 50)
      ]

      assert ExpShare.split(100, 40, members, 0, 50) == %{1 => {50, 20}, 2 => {50, 20}}
    end
  end

  describe "eligible_members/2" do
    setup do
      seed = :crypto.strong_rand_bytes(5) |> Base.url_encode64(padding: false)
      start_supervised!({EtsTable, seed: seed})
      Process.put({EtsTable, :seed}, seed)
      :ok
    end

    test "requires online presence, a live local player, and a matching map" do
      eligible = build(:party_member, map_name: "geffen")
      offline = build(:party_member, online: false)
      remote = build(:party_member, map_name: "prontera")
      dead = build(:party_member)
      missing = build(:party_member)

      register_player(eligible, "prontera", 100)
      register_player(offline, "prontera", 100)
      register_player(remote, "geffen", 100)
      register_player(dead, "prontera", 0)

      party =
        build(:party_state, exp_share: true, members: [eligible, offline, remote, dead, missing])

      assert ExpShare.eligible_members(party, "prontera") == [eligible]
    end
  end

  defp register_player(member, map_name, hp) do
    player =
      build(:player_state,
        character_id: member.char_id,
        map_name: map_name,
        stats: %{current_state: %{hp: hp}}
      )

    :ok = UnitRegistry.register_unit(:player, member.char_id, PlayerState, player, self())
  end
end

defmodule Aesir.ZoneServer.Unit.Mob.KillExpTest do
  @moduledoc """
  Exercises damage-based EXP distribution for a mob kill (design
  "Damage-based EXP share"): `split/6`'s pure damage-proportional formula
  plus the multi-attacker bonus, `eligible_damage/2`'s online/map/alive
  filter, and `distribute/5`'s end-to-end grouping -- solo damage-based
  grants scaled by the renewal level-gap penalty, and party-pooled grants
  split evenly across every eligible member of an `exp_share` party
  regardless of who actually attacked.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  describe "split/6" do
    test "splits proportional to damage dealt" do
      shares = KillExp.split(100, 60, %{1 => 75, 2 => 25}, 100, 0, 12)

      assert shares == %{1 => {75, 45}, 2 => {25, 15}}
    end

    test "dilutes shares against total_damage contributed by now-ineligible attackers" do
      shares = KillExp.split(100, 0, %{1 => 50}, 100, 0, 12)

      assert shares == %{1 => {50, 0}}
    end

    test "applies the multi-attacker bonus at count > 1" do
      shares = KillExp.split(100, 0, %{1 => 50, 2 => 50}, 100, 25, 12)

      assert shares == %{1 => {62, 0}, 2 => {62, 0}}
    end

    test "caps the multi-attacker bonus's attacker count at max_attackers" do
      damage = Map.new(1..20, &{&1, 5})

      shares = KillExp.split(1000, 0, damage, 100, 25, 12)

      assert {187, 0} = shares[1]
    end

    test "floors a positive share at 1 instead of rounding down to 0" do
      shares = KillExp.split(1, 1, %{1 => 1}, 1_000_000, 0, 12)

      assert shares == %{1 => {1, 1}}
    end

    test "returns an empty map for no eligible attackers" do
      assert KillExp.split(100, 50, %{}, 100, 0, 12) == %{}
    end
  end

  describe "eligible_damage/2" do
    defp register_player(char_id, map_name, hp) do
      UnitRegistry.register_unit(
        :player,
        char_id,
        PlayerState,
        %{map_name: map_name, stats: %{current_state: %{hp: hp}}},
        self()
      )
    end

    test "excludes an attacker whose registry lookup 404s" do
      register_player(1, "prontera", 100)

      assert KillExp.eligible_damage(%{1 => 50, 2 => 50}, "prontera") == %{1 => 50}
    end

    test "excludes an attacker on a different map" do
      register_player(1, "prontera", 100)
      register_player(2, "geffen", 100)

      assert KillExp.eligible_damage(%{1 => 50, 2 => 50}, "prontera") == %{1 => 50}
    end

    test "excludes a dead attacker" do
      register_player(1, "prontera", 100)
      register_player(2, "prontera", 0)

      assert KillExp.eligible_damage(%{1 => 50, 2 => 50}, "prontera") == %{1 => 50}
    end
  end

  describe "distribute/5" do
    setup do
      Application.put_env(:zone_server, :exp_bonus_attacker, 0)
      Application.put_env(:zone_server, :party_even_share_bonus, 0)

      on_exit(fn ->
        Application.delete_env(:zone_server, :exp_bonus_attacker)
        Application.delete_env(:zone_server, :party_even_share_bonus)
      end)

      :ok
    end

    defp register_member(char_id, opts) do
      state = %{
        character_id: char_id,
        map_name: Keyword.get(opts, :map, "prontera"),
        party_id: Keyword.get(opts, :party_id, 0),
        stats: %{
          current_state: %{hp: Keyword.get(opts, :hp, 100)},
          progression: %{base_level: Keyword.get(opts, :base_level, 100)}
        }
      }

      UnitRegistry.register_unit(:player, char_id, PlayerState, state, self())
    end

    defp party_member(char_id, map_name),
      do: Member.new(char_id, "Char#{char_id}", 100, true, map_name)

    test "grants a lone solo attacker its full damage-based share, level-penalized" do
      register_member(1, base_level: 100)
      expect(LevelPenalty, :exp, fn 100, 100 -> 100 end)

      PubSub.subscribe(Aesir.PubSub, "player:1")

      KillExp.distribute(%{1 => 100}, 100, 50, 100, "prontera", :brute)

      assert_receive {:progression, {:mob_kill_exp, 100, 50, :brute}}
    end

    test "splits two non-party attackers proportional to damage, each with its own level penalty" do
      register_member(1, base_level: 100)
      register_member(2, base_level: 80)
      expect(LevelPenalty, :exp, fn 100, 100 -> 100 end)
      expect(LevelPenalty, :exp, fn 100, 80 -> 50 end)

      PubSub.subscribe(Aesir.PubSub, "player:1")
      PubSub.subscribe(Aesir.PubSub, "player:2")

      KillExp.distribute(%{1 => 75, 2 => 25}, 100, 0, 100, "prontera", :brute)

      assert_receive {:progression, {:mob_kill_exp, 75, 0, :brute}}
      assert_receive {:progression, {:mob_kill_exp, 12, 0, :brute}}
    end

    test "an ineligible attacker's damage dilutes the pool but it receives nothing" do
      register_member(1, base_level: 100)
      expect(LevelPenalty, :exp, fn 100, 100 -> 100 end)

      PubSub.subscribe(Aesir.PubSub, "player:1")
      PubSub.subscribe(Aesir.PubSub, "player:2")

      KillExp.distribute(%{1 => 50, 2 => 50}, 100, 0, 100, "prontera", :brute)

      assert_receive {:progression, {:mob_kill_exp, 50, 0, :brute}}
      refute_receive {:progression, {:mob_kill_exp, _base, _job, _race}}, 50
    end

    test "pools contributing party members' shares and splits evenly across every eligible member" do
      register_member(1, base_level: 100, party_id: 10)
      register_member(2, base_level: 100, party_id: 10)
      register_member(3, base_level: 100, party_id: 10)

      party_state = %PartyState{
        party_id: 10,
        name: "Party",
        leader_char_id: 1,
        exp_share: true,
        members: %{
          1 => party_member(1, "prontera"),
          2 => party_member(2, "prontera"),
          3 => party_member(3, "prontera")
        }
      }

      stub(PartyManager, :get, fn 10 -> {:ok, party_state} end)
      stub(LevelPenalty, :exp, fn 100, 100 -> 100 end)

      PubSub.subscribe(Aesir.PubSub, "player:1")
      PubSub.subscribe(Aesir.PubSub, "player:2")
      PubSub.subscribe(Aesir.PubSub, "player:3")

      # Only 1 and 2 attacked; 3 never dealt damage.
      KillExp.distribute(%{1 => 60, 2 => 40}, 100, 50, 100, "prontera", :brute)

      assert_receive {:progression, {:mob_kill_exp, 33, 16, :brute}}
      assert_receive {:progression, {:mob_kill_exp, 33, 16, :brute}}
      assert_receive {:progression, {:mob_kill_exp, 33, 16, :brute}}
    end

    test "a party member with exp_share off falls through to a damage-based solo grant" do
      register_member(1, base_level: 100, party_id: 10)

      party_state = %PartyState{
        party_id: 10,
        name: "Party",
        leader_char_id: 1,
        exp_share: false,
        members: %{1 => party_member(1, "prontera")}
      }

      expect(PartyManager, :get, fn 10 -> {:ok, party_state} end)
      expect(LevelPenalty, :exp, fn 100, 100 -> 100 end)

      PubSub.subscribe(Aesir.PubSub, "player:1")

      KillExp.distribute(%{1 => 100}, 100, 50, 100, "prontera", :brute)

      assert_receive {:progression, {:mob_kill_exp, 100, 50, :brute}}
    end

    test "a party that disbands between grouping and pooling falls back to solo grants" do
      register_member(1, base_level: 100, party_id: 10)

      party_state = %PartyState{
        party_id: 10,
        name: "Party",
        leader_char_id: 1,
        exp_share: true,
        members: %{1 => party_member(1, "prontera")}
      }

      expect(PartyManager, :get, fn 10 -> {:ok, party_state} end)
      expect(PartyManager, :get, fn 10 -> {:error, :not_found} end)
      expect(LevelPenalty, :exp, fn 100, 100 -> 100 end)

      PubSub.subscribe(Aesir.PubSub, "player:1")

      KillExp.distribute(%{1 => 100}, 100, 50, 100, "prontera", :brute)

      assert_receive {:progression, {:mob_kill_exp, 100, 50, :brute}}
    end
  end
end

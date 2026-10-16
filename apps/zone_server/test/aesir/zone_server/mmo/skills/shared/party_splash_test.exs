defmodule Aesir.ZoneServer.Mmo.Skills.Shared.PartySplashTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skills.Shared.PartySplash
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  test "returns living same-map members in range, excluding the caster" do
    caster = player(1, "prontera", 100, 100)

    for {id, map, x, y} <- [
          {2, "prontera", 114, 114},
          {3, "prontera", 115, 100},
          {4, "geffen", 100, 100}
        ] do
      state = player(id, map, x, y)
      :ok = UnitRegistry.register_unit(:player, id, PlayerState, state, self())
    end

    dead = player(5, "prontera", 100, 100)
    dead = put_in(dead.stats.current_state.hp, 0)
    :ok = UnitRegistry.register_unit(:player, 5, PlayerState, dead, self())

    party = %PartyState{
      party_id: 10,
      name: "Splash",
      leader_char_id: 1,
      exp_share: false,
      item_pickup_share: false,
      members: Map.new(1..5, &{&1, Member.new(&1, "Char#{&1}", 50, true, "prontera")})
    }

    stub(PartyManager, :get, fn 10 -> {:ok, party} end)

    assert PartySplash.nearby_member_ids(caster, 14) == [2]
    assert PartySplash.nearby_member_ids(%{caster | party_id: 0}, 14) == []
  end

  test "leaves out an invincible member" do
    caster = player(1, "prontera", 100, 100)
    :ok = UnitRegistry.register_unit(:player, 2, PlayerState, player(2, "prontera", 101, 100))

    invincible = %{player(3, "prontera", 101, 100) | invincible_timer: make_ref()}
    :ok = UnitRegistry.register_unit(:player, 3, PlayerState, invincible, self())

    party = %PartyState{
      party_id: 10,
      name: "Splash",
      leader_char_id: 1,
      exp_share: false,
      item_pickup_share: false,
      members: Map.new(1..3, &{&1, Member.new(&1, "Char#{&1}", 50, true, "prontera")})
    }

    stub(PartyManager, :get, fn 10 -> {:ok, party} end)

    assert PartySplash.nearby_member_ids(caster, 14) == [2]
  end

  defp player(id, map, x, y) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Char#{id}",
      last_map: map,
      last_x: x,
      last_y: y,
      hp: 100,
      sp: 100,
      class: 0,
      sex: "M",
      party_id: 10
    })
  end
end

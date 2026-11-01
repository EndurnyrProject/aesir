defmodule Aesir.ZoneServer.Mmo.Skill.CashPartyBuffTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  alias Phoenix.PubSub

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    stub(Resistance, :roll_success, fn _ -> true end)
    :ok
  end

  test "cash party fanout filters caster and does not fall back for a missing party" do
    caster = player(1)
    stub(PartyManager, :get, fn 10 -> {:error, :not_found} end)
    assert [] = PartyBuff.apply_cash(caster, :sc_blessing, params(), 14)
    refute StatusStorage.has_status?(:player, 1, :sc_blessing)

    stub(PartyManager, :get, fn 10 -> {:ok, party([member(1)])} end)

    for filtered <- [
          %{caster | invincible_timer: make_ref()},
          %{caster | option: Option.id(:invisible)}
        ] do
      :ok = UnitRegistry.update_unit_state(:player, 1, filtered)
      assert [] = PartyBuff.apply_cash(filtered, :sc_blessing, params(), 14)
      refute StatusStorage.has_status?(:player, 1, :sc_blessing)
    end

    :ok = UnitRegistry.update_unit_state(:player, 1, caster)
    assert [{:sc_blessing, :apply}] = PartyBuff.apply_cash(caster, :sc_blessing, params(), 14)
    assert StatusStorage.has_status?(:player, 1, :sc_blessing)
  end

  test "cash party relationship honors no-party flags, teams and siren before self exemption" do
    caster = player(1)
    target = player(2, %{guild_id: 55})
    caster = %{caster | guild_id: 55}
    assert Targeting.cash_party_recipient?(caster, target)

    for {versus, no_party} <- [
          {:pvp, :pvp_noparty},
          {:gvg, :gvg_noparty},
          {:gvg_te, :gvg_noparty}
        ] do
      :ok = MapFlags.set_runtime("prontera", versus, true)
      :ok = MapFlags.set_runtime("prontera", no_party, true)
      refute Targeting.cash_party_recipient?(caster, target)
      assert Targeting.cash_party_recipient?(caster, caster)
      :ok = MapFlags.set_runtime("prontera", no_party, false)
      assert Targeting.cash_party_recipient?(caster, target)
      :ok = MapFlags.set_runtime("prontera", versus, false)
    end

    :ok = MapFlags.set_runtime("prontera", :battleground, true)
    assert Targeting.cash_party_recipient?(caster, target)
    caster = %{caster | battleground_team_id: 8}
    target = %{target | battleground_team_id: 9}
    refute Targeting.cash_party_recipient?(caster, target)
    assert Targeting.cash_party_recipient?(caster, %{target | battleground_team_id: 8})
    assert Targeting.cash_party_recipient?(caster, caster)

    :ok = StatusStorage.apply_status(:player, 1, :sc_voiceofsiren, val2: 2)
    refute Targeting.cash_party_recipient?(caster, %{target | battleground_team_id: 8})
    :ok = StatusStorage.apply_status(:player, 1, :sc_voiceofsiren, val2: 1)
    refute Targeting.cash_party_recipient?(caster, caster)
  end

  test "cash fanout uses inclusive square range and skips unavailable or refused members independently" do
    caster = player(1)
    player(2, %{x: 114, y: 86})
    player(3, %{x: 115})
    player(4, %{map_name: "geffen"})
    player(5)
    player(7, %{pending_map_load: :login})
    player(8, %{action_state: :dead})
    player(9)
    player(10)
    :ok = StatusStorage.apply_status(:player, 9, :sc_quagmire)
    :ok = StatusStorage.apply_status(:player, 10, :sc_hiding)
    members = Enum.map(1..10, &member(&1, &1 != 5))
    stub(PartyManager, :get, fn 10 -> {:ok, party(members)} end)

    assert [{:sc_increaseagi, :apply}] =
             PartyBuff.apply_cash(caster, :sc_increaseagi, params(), 14)

    for id <- [1, 2, 10] do
      assert %{source_id: 1, source_type: :player} =
               StatusStorage.get_status(:player, id, :sc_increaseagi)
    end

    for id <- 3..9 do
      refute StatusStorage.has_status?(:player, id, :sc_increaseagi)
    end
  end

  test "cash fanout returns caster cure events and notifies only other owners" do
    caster = player(1)
    player(2)
    :ok = PubSub.subscribe(Aesir.PubSub, "player:1")
    :ok = PubSub.subscribe(Aesir.PubSub, "player:2")
    :ok = StatusStorage.apply_status(:player, 1, :sc_curse)
    stub(PartyManager, :get, fn 10 -> {:ok, party([member(1), member(2)])} end)

    assert [{:sc_curse, :removed}] = PartyBuff.apply_cash(caster, :sc_blessing, params(), 14)
    refute StatusStorage.has_status?(:player, 1, :sc_blessing)
    refute StatusStorage.has_status?(:player, 1, :sc_curse)
    assert StatusStorage.has_status?(:player, 2, :sc_blessing)
    assert_receive {:stats, {:status_changed, :sc_blessing, :apply}}
    refute_receive {:stats, {:status_changed, :sc_curse, :removed}}, 0

    held = StatusStorage.get_status(:player, 2, :sc_blessing)
    :ok = StatusStorage.apply_status(:player, 1, :sc_blessing, val1: 10)
    assert [] = PartyBuff.apply_cash(caster, :sc_blessing, Keyword.put(params(), :val1, 1), 14)
    assert StatusStorage.get_status(:player, 2, :sc_blessing) == held
    refute_receive {:stats, {:status_changed, _, _}}, 0
  end

  test "fanout preserves a magic self invocation and its original source for immunity" do
    immune_stats = %{
      combat_stats: %CombatStats{},
      progression: %{base_level: 1, job_level: 1},
      modifiers: %{equipment: %{no_magic_damage: 100}}
    }

    caster = player(1, %{stats: immune_stats})
    player(2, %{stats: immune_stats})
    player(3)
    stub(PartyManager, :get, fn 10 -> {:ok, party(Enum.map(1..3, &member/1))} end)

    # An existing magic/self skill provides the invocation metadata before the
    # cash skill definitions are introduced in the next task.
    assert [{:sc_blessing, :apply}] =
             Origin.with_skill(:pr_magnificat, {:player, 1}, fn ->
               events = PartyBuff.apply_cash(caster, :sc_blessing, params(), 14)
               assert %{skill: :pr_magnificat, caster: {:player, 1}} = Origin.current()
               events
             end)

    assert %{source_id: 1} = StatusStorage.get_status(:player, 1, :sc_blessing)
    refute StatusStorage.has_status?(:player, 2, :sc_blessing)
    assert %{source_id: 1} = StatusStorage.get_status(:player, 3, :sc_blessing)
  end

  defp player(id, overrides \\ %{}) do
    state =
      PlayerStateFixture.build(
        Map.merge(
          %{
            character_id: id,
            account_id: id,
            party_id: 10,
            map_name: "prontera",
            x: 100,
            y: 100,
            pending_map_load: nil,
            stats: %{combat_stats: %CombatStats{}, progression: %{base_level: 1, job_level: 1}}
          },
          overrides
        )
      )

    :ok = UnitRegistry.register_player(state, self())
    state
  end

  defp params, do: [duration: 30_000, val1: 10, caster_id: 1, source_type: :player]

  defp member(id, online \\ true), do: Member.new(id, "Char#{id}", 1, online, "prontera")

  defp party(members) do
    %PartyState{
      party_id: 10,
      name: "Cash",
      leader_char_id: 1,
      exp_share: false,
      item_pickup_share: false,
      members: Map.new(members, &{&1.char_id, &1})
    }
  end
end

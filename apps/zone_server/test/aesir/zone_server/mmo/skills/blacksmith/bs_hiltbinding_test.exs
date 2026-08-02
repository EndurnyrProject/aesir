defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHiltbindingTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline2
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHiltbinding
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsOverthrust
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsWeaponperfect
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    :ok = Catalog.reload()
  end

  test "grants exactly one STR and four ATK without a HIT bonus" do
    player = player_state(1, %{105 => 1})

    assert {:ok, BsHiltbinding} = Catalog.passive_module_for(:bs_hiltbinding)
    assert Passives.str_bonus(player) == 1
    assert Passives.atk_bonus(player) == 4
    assert Passives.hit_bonus(player) == 0
  end

  test "extends only a Hilt Binding caster's duration and truncates fractional milliseconds" do
    assert PartyBuff.duration_for_caster(player_state(1, %{105 => 1}), 101) == 111
    assert PartyBuff.duration_for_caster(player_state(1, %{}), 101) == 101
  end

  test "a recipient's Hilt Binding does not extend a non-Hilt caster's buff" do
    assert_weaponperfect_durations(%{}, %{105 => 1}, 10_000)
  end

  test "caster and recipient Hilt Binding extend once, never compounding to 1.21x" do
    assert_weaponperfect_durations(%{105 => 1}, %{105 => 1}, 11_000)
  end

  test "a Hilt Binding caster extends all four buffs for self and party recipients" do
    caster = player_state(1, %{105 => 1})
    member = player_state(2, %{})
    UnitRegistry.register_unit(:player, 2, PlayerState, member, self())

    stub(PartyManager, :get, fn 10 -> {:ok, party_state()} end)
    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn :player, target_id, status, params ->
      send(test_pid, {:status, target_id, status, params[:duration]})
      :ok
    end)

    for {module, status, duration, applications} <- [
          {BsAdrenaline, :sc_adrenaline, 33_000, 2},
          {BsAdrenaline2, :sc_adrenaline2, 165_000, 2},
          {BsWeaponperfect, :sc_weaponperfection, 11_000, 2},
          {BsOverthrust, :sc_overthrust, 22_000, 3}
        ] do
      assert {:ok, ^caster} = module.cast(caster, :self, 1, module.definition())

      messages = for _index <- 1..applications, do: receive_status()

      assert {1, status, duration} in messages
      assert {2, status, duration} in messages
      refute_receive {:status, _, _, _}
    end
  end

  defp assert_weaponperfect_durations(caster_skills, member_skills, expected_duration) do
    caster = player_state(1, caster_skills)
    member = player_state(2, member_skills)
    UnitRegistry.register_unit(:player, 2, PlayerState, member, self())

    expect(PartyManager, :get, fn 10 -> {:ok, party_state()} end)

    expect(StatusInterpreter, :apply_status, 2, fn
      :player, target_id, :sc_weaponperfection, params when target_id in [1, 2] ->
        assert params[:duration] == expected_duration
        :ok
    end)

    assert {:ok, ^caster} =
             BsWeaponperfect.cast(caster, :self, 1, BsWeaponperfect.definition())
  end

  defp receive_status do
    receive do
      {:status, target_id, status, duration} -> {target_id, status, duration}
    after
      100 -> flunk("expected status application")
    end
  end

  defp player_state(char_id, learned_skills) do
    %Character{
      id: char_id,
      account_id: char_id,
      name: "Char#{char_id}",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 10,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: 10,
      learned_skills:
        Map.new(learned_skills, fn {id, level} -> {Integer.to_string(id), level} end)
    }
    |> PlayerState.new()
    |> equip_axe()
  end

  defp equip_axe(%PlayerState{stats: %Stats{} = stats} = player) do
    %{player | stats: %Stats{stats | equipment: %Equipment{right_hand: 1301}}}
  end

  defp party_state do
    %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      item_pickup_share: false,
      members: %{
        1 => Member.new(1, "Char1", 100, true, "prontera"),
        2 => Member.new(2, "Char2", 100, true, "prontera")
      }
    }
  end
end

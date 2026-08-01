defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsOverthrustTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsOverthrust
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    :ok = Catalog.reload()
  end

  test "exposes the Over Thrust definition as an active skill" do
    assert {:ok, definition} = Catalog.by_id(113)
    assert definition.name == :bs_overthrust
    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.status == :sc_overthrust
    assert definition.splash_radius == 14
    assert definition.duration == [20_000, 40_000, 60_000, 80_000, 100_000]
    assert definition.sp_cost == [18, 16, 14, 12, 10]
    assert {:ok, BsOverthrust} = Catalog.active_module_for(:bs_overthrust)
  end

  test "applies the larger caster rate and coarser party rate at every level" do
    caster = player_state(1)
    member = player_state(2)
    assert :ok = UnitRegistry.register_unit(:player, 2, PlayerState, member, self())

    stub(PartyManager, :get, fn 10 -> {:ok, party_state()} end)
    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn :player, target_id, :sc_overthrust, params ->
      send(test_pid, {:status, target_id, params[:val1], params[:duration]})
      :ok
    end)

    assert {:ok, definition} = Catalog.by_id(113)

    for {level, caster_rate, recipient_rate, duration} <- [
          {1, 5, 5, 20_000},
          {2, 10, 5, 40_000},
          {3, 15, 10, 60_000},
          {4, 20, 10, 80_000},
          {5, 25, 15, 100_000}
        ] do
      assert {:ok, ^caster} = BsOverthrust.cast(caster, :self, level, definition)
      assert_receive {:status, 1, ^recipient_rate, ^duration}
      assert_receive {:status, 2, ^recipient_rate, ^duration}
      assert_receive {:status, 1, ^caster_rate, ^duration}
      refute_receive {:status, _, _, _}
    end
  end

  defp player_state(char_id) do
    %Character{
      id: char_id,
      account_id: char_id,
      name: "Char#{char_id}",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 0,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: 10
    }
    |> PlayerState.new()
  end

  defp party_state do
    %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      members: %{
        1 => Member.new(1, "Char1", 100, true, "prontera"),
        2 => Member.new(2, "Char2", 100, true, "prontera")
      }
    }
  end
end

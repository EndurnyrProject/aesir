defmodule Aesir.ZoneServer.Mmo.Skills.AlAngelusTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AlAngelus
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  test "Catalog.by_id/1 resolves al_angelus" do
    assert {:ok, definition} = Catalog.by_id(33)
    assert definition.name == :al_angelus
  end

  test "Catalog.by_name/1 resolves al_angelus" do
    assert {:ok, definition} = Catalog.by_name(:al_angelus)
    assert definition.id == 33
  end

  test "definition cooldown is 30_000ms at every level" do
    assert {:ok, definition} = Catalog.by_id(33)
    assert Enum.all?(definition.cooldown, &(&1 == 30_000))
  end

  test "cast/4 applies SC_ANGELUS to the caster at level 1" do
    {:ok, definition} = Catalog.by_id(33)
    caster = %{character_id: 500}

    expect(StatusInterpreter, :apply_status, fn :player, 500, :sc_angelus, params ->
      assert params[:val1] == 1
      assert params[:val2] == 5
      assert params[:caster_id] == 500
      assert params[:duration] == 30_000
      :ok
    end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 1, definition)
  end

  test "cast/4 applies SC_ANGELUS to the caster at level 10" do
    {:ok, definition} = Catalog.by_id(33)
    caster = %{character_id: 500}

    expect(StatusInterpreter, :apply_status, fn :player, 500, :sc_angelus, params ->
      assert params[:val1] == 10
      assert params[:val2] == 50
      assert params[:caster_id] == 500
      assert params[:duration] == 300_000
      :ok
    end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 10, definition)
  end

  test "cast/4 propagates error from StatusInterpreter" do
    {:ok, definition} = Catalog.by_id(33)
    caster = %{character_id: 500}

    expect(StatusInterpreter, :apply_status, fn :player, 500, :sc_angelus, _params ->
      {:error, :prevented}
    end)

    assert {:error, :prevented} = AlAngelus.cast(caster, :self, 5, definition)
  end

  defp character(char_id, opts) do
    %Character{
      id: char_id,
      account_id: char_id,
      name: "Char#{char_id}",
      last_map: Keyword.get(opts, :map, "prontera"),
      last_x: Keyword.get(opts, :x, 150),
      last_y: Keyword.get(opts, :y, 150),
      class: 0,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 7,
      party_id: Keyword.get(opts, :party_id, 0)
    }
  end

  defp caster_state(char_id, opts) do
    PlayerState.new(character(char_id, opts))
  end

  defp register_member(char_id, opts) do
    state = PlayerState.new(character(char_id, opts))

    state =
      if Keyword.get(opts, :dead, false) do
        put_in(state.stats.current_state.hp, 0)
      else
        state
      end

    UnitRegistry.register_unit(:player, char_id, PlayerState, state, self())
  end

  defp party_member(char_id, map_name) do
    Member.new(char_id, "Char#{char_id}", 100, true, map_name)
  end

  test "cast/4 splashes SC_ANGELUS to an online same-map party member within range" do
    {:ok, definition} = Catalog.by_id(33)
    caster = caster_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    register_member(2, map: "prontera", x: 160, y: 150)

    party_state = %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      members: %{
        1 => party_member(1, "prontera"),
        2 => party_member(2, "prontera")
      }
    }

    expect(PartyManager, :get, fn 10 -> {:ok, party_state} end)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_angelus, params ->
      assert params[:caster_id] == 1
      :ok
    end)

    expect(StatusInterpreter, :apply_status, fn :player, 2, :sc_angelus, params ->
      assert params[:caster_id] == 1
      :ok
    end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 1, definition)
  end

  test "cast/4 does not splash a party member outside splash_radius" do
    {:ok, definition} = Catalog.by_id(33)
    caster = caster_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    register_member(2, map: "prontera", x: 200, y: 150)

    party_state = %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      members: %{
        1 => party_member(1, "prontera"),
        2 => party_member(2, "prontera")
      }
    }

    expect(PartyManager, :get, fn 10 -> {:ok, party_state} end)
    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_angelus, _params -> :ok end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 1, definition)
  end

  test "cast/4 does not splash a party member on a different map" do
    {:ok, definition} = Catalog.by_id(33)
    caster = caster_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    register_member(2, map: "geffen", x: 150, y: 150)

    party_state = %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      members: %{
        1 => party_member(1, "prontera"),
        2 => party_member(2, "geffen")
      }
    }

    expect(PartyManager, :get, fn 10 -> {:ok, party_state} end)
    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_angelus, _params -> :ok end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 1, definition)
  end

  test "cast/4 does not splash a dead party member" do
    {:ok, definition} = Catalog.by_id(33)
    caster = caster_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    register_member(2, map: "prontera", x: 155, y: 150, dead: true)

    party_state = %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      members: %{
        1 => party_member(1, "prontera"),
        2 => party_member(2, "prontera")
      }
    }

    expect(PartyManager, :get, fn 10 -> {:ok, party_state} end)
    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_angelus, _params -> :ok end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 1, definition)
  end

  test "cast/4 does not splash an inconsistent dead party snapshot" do
    {:ok, definition} = Catalog.by_id(33)
    caster = caster_state(1, party_id: 10, map: "prontera", x: 150, y: 150)

    dead_member =
      2
      |> caster_state(map: "prontera", x: 155, y: 150)
      |> Map.put(:action_state, :dead)

    UnitRegistry.register_unit(:player, 2, PlayerState, dead_member, self())

    party_state = %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      members: %{1 => party_member(1, "prontera"), 2 => party_member(2, "prontera")}
    }

    expect(PartyManager, :get, fn 10 -> {:ok, party_state} end)
    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn :player, target_id, :sc_angelus, _params ->
      send(test_pid, {:angelus, target_id})
      :ok
    end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 1, definition)
    assert_received {:angelus, 1}
    refute_received {:angelus, 2}
  end

  test "cast/4 does not consult Party.Manager when the caster has no party" do
    {:ok, definition} = Catalog.by_id(33)
    caster = caster_state(1, party_id: 0, map: "prontera", x: 150, y: 150)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_angelus, _params -> :ok end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 1, definition)
  end

  test "cast/4 splashes only the caster when the party entry has gone missing" do
    {:ok, definition} = Catalog.by_id(33)
    caster = caster_state(1, party_id: 10, map: "prontera", x: 150, y: 150)

    expect(PartyManager, :get, fn 10 -> {:error, :not_found} end)
    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_angelus, _params -> :ok end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 1, definition)
  end
end

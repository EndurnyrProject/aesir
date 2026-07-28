defmodule Aesir.ZoneServer.Mmo.Skills.Bard.SongTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skills.Bard.Song
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  test "an unpartied caster receives the finite song and remembers it" do
    caster = player(1, party_id: 0)
    assert Map.fetch!(caster, :last_song) == nil

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_whistle, params ->
      assert params[:val2] == 20
      assert params[:caster_id] == 1
      assert params[:duration] == 180_000
      assert params[:owner_refresh] == :notify
      :ok
    end)

    assert {:ok, result} = Song.snapshot(caster, 319, 1, :sc_whistle, val2: 20)
    assert result.last_song == %{skill_id: 319, level: 1}
  end

  test "selects only living online same-map party members inside Chebyshev radius 15" do
    caster = player(1, party_id: 10)
    register(player(2, x: 115, y: 115))
    register(player(3, x: 116, y: 100))
    register(player(4, map: "geffen"))
    register(dead_player(5, x: 105))
    register(player(6, x: 105))

    stub(PartyManager, :get, fn 10 ->
      {:ok,
       %PartyState{
         party_id: 10,
         name: "Party",
         leader_char_id: 1,
         exp_share: false,
         members: %{
           1 => member(1),
           2 => member(2),
           3 => member(3),
           4 => member(4),
           5 => member(5),
           6 => %{member(6) | online: false}
         }
       }}
    end)

    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn :player, target_id, :sc_whistle, _params ->
      send(test_pid, {:applied, target_id})
      :ok
    end)

    assert {:ok, _result} = Song.snapshot(caster, 319, 1, :sc_whistle, val2: 20)
    assert_received {:applied, 1}
    assert_received {:applied, 2}
    refute_received {:applied, 3}
    refute_received {:applied, 4}
    refute_received {:applied, 5}
    refute_received {:applied, 6}
  end

  test "applies eligibility per recipient and does not roll back independent failures" do
    caster = player(1, party_id: 10)
    register(player(2))
    register(player(3))

    stub(PartyManager, :get, fn 10 ->
      {:ok,
       %PartyState{
         party_id: 10,
         name: "Party",
         leader_char_id: 1,
         exp_share: false,
         members: %{1 => member(1), 2 => member(2), 3 => member(3)}
       }}
    end)

    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn :player, target_id, :sc_assncross, _params ->
      send(test_pid, {:attempted, target_id})
      if target_id == 1, do: {:error, :target_gone}, else: :ok
    end)

    assert {:ok, result} =
             Song.snapshot(caster, 320, 10, :sc_assncross, [val2: 20],
               eligible?: &(&1.character_id != 3)
             )

    assert_received {:attempted, 1}
    assert_received {:attempted, 2}
    refute_received {:attempted, 3}
    assert result.last_song == %{skill_id: 320, level: 10}
  end

  defp player(id, opts \\ []) do
    %Character{
      id: id,
      account_id: id,
      name: "Player#{id}",
      last_map: Keyword.get(opts, :map, "prontera"),
      last_x: Keyword.get(opts, :x, 100),
      last_y: Keyword.get(opts, :y, 100),
      class: 19,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: Keyword.get(opts, :party_id, 0)
    }
    |> PlayerState.new()
  end

  defp dead_player(id, opts) do
    state = player(id, opts)
    put_in(state.stats.current_state.hp, 0)
  end

  defp register(state) do
    UnitRegistry.register_unit(:player, state.character_id, PlayerState, state, self())
  end

  defp member(id), do: Member.new(id, "Player#{id}", 100, true, "prontera")
end

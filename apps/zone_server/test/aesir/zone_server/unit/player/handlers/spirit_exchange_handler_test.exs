defmodule Aesir.ZoneServer.Unit.Player.Handlers.SpiritExchangeHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SpiritExchangeHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :setup_ets_tables

  test "transfer sends one best-effort request to the current target session" do
    source = player_state(1, party_id: 10)
    target = player_state(2, party_id: 10)
    :ok = UnitRegistry.register_player(target, self())

    assert :ok = SpiritExchangeHandler.transfer(%{game_state: source}, 2)

    assert_receive {:"$gen_cast",
                    {:receive_spirit_sphere,
                     %{source_id: 1, source_pid: source_pid, target_id: 2}}}

    assert source_pid == self()
  end

  test "a valid receiver adds one sphere but a full receiver keeps its sphere" do
    Mimic.copy(Broadcast)
    expect(Broadcast, :to_visible_players, 5, fn _state, _update, exclude_id: 2 -> :ok end)

    source = player_state(1, party_id: 10)
    target = player_state(2, party_id: 10)
    :ok = UnitRegistry.register_player(source, self())

    request = %{source_id: 1, source_pid: self(), target_id: 2}
    state = %{connection_pid: self(), game_state: target}

    received =
      Enum.reduce(1..5, state, fn _, state ->
        assert {:noreply, state} = SpiritExchangeHandler.receive_sphere(state, request)
        state
      end)

    assert SpiritSpheres.count(received.game_state.spirit_spheres) == 5

    assert {:noreply, unchanged} = SpiritExchangeHandler.receive_sphere(received, request)
    assert unchanged == received

    Process.cancel_timer(received.game_state.spirit_sphere_timer)
  end

  test "a receiver rejects a stale source session and coin-user jobs" do
    source = player_state(1, party_id: 10)
    :ok = UnitRegistry.register_player(source, spawn(fn -> :ok end))
    request = %{source_id: 1, source_pid: self(), target_id: 2}

    for target <- [player_state(2, party_id: 10), player_state(2, party_id: 10, job_id: 24)] do
      state = %{connection_pid: self(), game_state: target}
      assert {:noreply, ^state} = SpiritExchangeHandler.receive_sphere(state, request)
    end
  end

  test "an accepted absorb request clears the target and replies once with the count" do
    Mimic.copy(Broadcast)
    Mimic.copy(Targeting)
    stub(Targeting, :validate_enemy, fn _source, _target -> :ok end)
    expect(Broadcast, :to_visible_players, fn _state, _update, exclude_id: 2 -> :ok end)

    source = player_state(1)
    target = player_state(2) |> with_spheres(2)
    :ok = UnitRegistry.register_player(source, self())
    token = make_ref()
    request = %{source_id: 1, source_pid: self(), target_id: 2, token: token}

    assert {:noreply, updated} =
             SpiritExchangeHandler.absorb_spheres(
               %{connection_pid: self(), game_state: target},
               request
             )

    assert SpiritSpheres.count(updated.game_state.spirit_spheres) == 0
    assert_receive {:"$gen_cast", {:spirit_absorb_result, ^token, 2, 2}}
  end

  test "player absorb is rejected when the current targeting policy disallows PvP" do
    source = player_state(1)
    target = player_state(2) |> with_spheres(1)
    :ok = UnitRegistry.register_player(source, self())
    token = make_ref()
    request = %{source_id: 1, source_pid: self(), target_id: 2, token: token}
    state = %{connection_pid: self(), game_state: target}

    assert {:noreply, ^state} = SpiritExchangeHandler.absorb_spheres(state, request)
    refute_receive {:"$gen_cast", {:spirit_absorb_result, ^token, 2, _count}}
  end

  defp player_state(id, opts \\ []) do
    character = %Character{
      id: id,
      account_id: id,
      name: "Player #{id}",
      last_map: Keyword.get(opts, :map_name, "prontera"),
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: Keyword.get(opts, :job_id, 15)
    }

    state = PlayerState.new(character)
    %{state | party_id: Keyword.get(opts, :party_id, 0)}
  end

  defp with_spheres(state, count) do
    spheres =
      Enum.reduce(1..count, state.spirit_spheres, fn _, spheres ->
        {spheres, _entry} = SpiritSpheres.summon(spheres, 60_000, 5)
        spheres
      end)

    %{state | spirit_spheres: spheres}
  end
end

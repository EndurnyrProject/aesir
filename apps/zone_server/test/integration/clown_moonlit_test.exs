defmodule Aesir.ZoneServer.Integration.ClownMoonlitTest do
  @moduledoc "Real-session Moonlit Water Mill in renewal and pre-renewal."
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.SkillCastFailed
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.TestSupport.ClownSessions

  @map "prontera"
  @moonlit 395
  @center {150, 150}

  setup do
    ClownSessions.blank_map(@map)
    :ok
  end

  describe "renewal" do
    @describetag game_mode: :renewal, integration_pre_re: false

    test "a cast without an adjacent partner is refused" do
      clown = start(:clown, @center, 5)
      sp = get_player_state(clown.pid).stats.current_state.sp
      flush_packets()

      ClownSessions.cast(clown, @moonlit, 5)

      assert_packet_sent(SkillCastFailed)
      assert groups(clown) == []
      assert get_player_state(clown.pid).stats.current_state.sp == sp
    end

    test "a paired cast pushes an entering mob, without fatigue" do
      %{clown: clown} = start_pair(1, 1)
      mob = start_mob_session(map_name: @map, position: {170, 150}, vit: 0, luk: 0)
      on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)

      ClownSessions.cast(clown, @moonlit, 1)

      assert_eventually(fn -> match?([_], groups(clown)) end)
      assert %{state: %{root: :always}} = dancing(clown)
      refute StatusInterpreter.can_move?(:player, clown.character.id)
      refute StatusStorage.has_status?(:player, clown.character.id, :sc_ensemblefatigue)

      {dx, dy} = Geometry.facing_delta(get_mob_state(mob.pid).dir)
      {cx, cy} = @center
      MobSession.warp(mob.pid, @map, cx + 4 * dx, cy + 4 * dy)

      assert_eventually(fn ->
        match?(
          {:ok, {x, y, _}} when {x, y} == {cx + 6 * dx, cy + 6 * dy},
          SpatialIndex.get_unit_position(:mob, mob.unit_id)
        )
      end)
    end

    test "a paired cast roots both performers at the caster's level" do
      %{clown: clown, gypsy: gypsy} = start_pair(5, 1)

      ClownSessions.cast(clown, @moonlit, 5)

      assert_eventually(fn -> match?([%{level: 5}], groups(clown)) end)

      for performer <- [clown, gypsy] do
        assert_eventually(fn ->
          match?(%{state: %{root: :always, upkeep_sp: 20}}, dancing(performer))
        end)

        refute StatusInterpreter.can_move?(:player, performer.character.id)
        refute StatusStorage.has_status?(:player, performer.character.id, :sc_ensemblefatigue)
      end
    end

    test "upkeep pays four SP per level every ten seconds" do
      %{clown: clown} = start_pair(1, 1)
      id = clown.character.id
      ClownSessions.cast(clown, @moonlit, 1)
      assert_eventually(fn -> match?(%{state: %{upkeep: 10}}, dancing(clown)) end)
      sp = get_player_state(clown.pid).stats.current_state.sp

      :ok =
        StatusStorage.update_status(:player, id, :sc_dancing, fn status ->
          %{
            status
            | next_tick_at: System.monotonic_time(:millisecond) - 1,
              state: %{status.state | ticks: 9}
          }
        end)

      StatusTickManager.force_tick()
      assert_eventually(fn -> get_player_state(clown.pid).stats.current_state.sp == sp - 4 end)
    end
  end

  describe "pre-renewal" do
    @describetag game_mode: :pre_renewal, integration_re: false

    test "a paired cast places the field and roots both performers" do
      %{clown: clown, gypsy: gypsy} = start_pair(5, 5)

      ClownSessions.cast(clown, @moonlit, 5)

      assert_eventually(fn -> match?([%{level: 5}], groups(clown)) end)

      for performer <- [clown, gypsy] do
        assert_eventually(fn -> match?(%{state: %{root: :always}}, dancing(performer)) end)
        refute StatusInterpreter.can_move?(:player, performer.character.id)
      end
    end

    test "a cast without an adjacent partner is refused" do
      clown = start(:clown, @center, 5)
      sp = get_player_state(clown.pid).stats.current_state.sp
      flush_packets()

      ClownSessions.cast(clown, @moonlit, 5)

      assert_packet_sent(SkillCastFailed)
      assert groups(clown) == []
      assert get_player_state(clown.pid).stats.current_state.sp == sp
    end
  end

  defp start_pair(clown_level, gypsy_level) do
    clown = ClownSessions.character(:clown, @map, @center, %{@moonlit => clown_level})
    gypsy = ClownSessions.character(:gypsy, @map, {151, 150}, %{@moonlit => gypsy_level})
    ClownSessions.party([clown, gypsy])
    %{clown: ClownSessions.start_session(clown), gypsy: ClownSessions.start_session(gypsy)}
  end

  defp start(job, position, level) do
    job
    |> ClownSessions.character(@map, position, %{@moonlit => level})
    |> ClownSessions.start_session()
  end

  defp groups(session), do: Storage.get_groups_by_caster(:player, session.character.id)

  defp dancing(session),
    do: StatusStorage.get_status(:player, session.character.id, :sc_dancing)
end

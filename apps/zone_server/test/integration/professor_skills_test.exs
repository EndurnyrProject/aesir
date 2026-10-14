defmodule Aesir.ZoneServer.Integration.ProfessorSkillsTest do
  @moduledoc """
  Real-session Professor coverage: Mind Breaker, Soul Exhale, Fiber Lock and
  Double Casting.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Aesir.ZoneServer.HwProfessorFixture

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.Skills.Professor.PfMindbreaker
  alias Aesir.ZoneServer.Mmo.Skills.Shared.BoltEcho
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @professor 4017
  @cold_bolt 14
  @fire_bolt 19
  @lightning_bolt 20
  @soul_change 374
  @mind_breaker 402
  @spiderweb 405
  @double_casting 482

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  describe "Mind Breaker" do
    setup do
      Mimic.copy(PfMindbreaker)

      stub(PfMindbreaker, :cast, fn caster, target, level, definition ->
        Mimic.call_original(PfMindbreaker, :cast, [
          caster,
          target,
          level,
          definition,
          [rng: fn 100 -> 1 end]
        ])
      end)

      :ok
    end

    test "breaks a casting player's spell on a versus map" do
      :ok = MapFlags.set_runtime(map(), :pvp, true)
      on_exit(fn -> MapFlags.clear_runtime(map(), :pvp) end)

      professor = start_caster(@professor, %{"#{@mind_breaker}" => 1})
      Mimic.allow(PfMindbreaker, self(), professor.pid)

      victim =
        start_caster(@professor, %{"#{@cold_bolt}" => 10}, [], %{last_x: 153, int: 1, dex: 1})

      mob = start_target({158, 150})

      cast(victim, @cold_bolt, 10, mob.unit_id)
      assert eventually(fn -> get_player_state(victim.pid).casting != nil end)

      cast(professor, @mind_breaker, 1, victim.character.id)

      assert eventually(fn ->
               StatusStorage.has_status?(:player, victim.character.id, :sc_mindbreaker)
             end)

      assert eventually(fn -> get_player_state(victim.pid).casting == nil end)
    end

    test "turns a monster on the Professor" do
      professor = start_caster(@professor, %{"#{@mind_breaker}" => 1})
      Mimic.allow(PfMindbreaker, self(), professor.pid)
      mob = start_target({153, 150})

      cast(professor, @mind_breaker, 1, mob.unit_id)

      assert eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_mindbreaker) end)

      assert eventually(fn ->
               get_mob_state(mob.pid).target_ref == {:player, professor.character.id}
             end)
    end
  end

  test "Soul Exhale exchanges SP with a party member" do
    caster_row = insert_character(@professor, %{"#{@soul_change}" => 1}, %{sp: 300})
    ally_row = insert_character(@professor, %{}, %{sp: 100, last_x: 152})
    assert {:ok, party} = PartyManager.create("Prof#{caster_row.id}", caster_row)
    assert {:ok, _party} = PartyManager.add_member(party.party_id, ally_row)

    professor = start_caster_from(caster_row)
    ally = start_caster_from(ally_row)

    cast(professor, @soul_change, 1, ally.character.id)

    {to_ally, to_professor} =
      case GameMode.mode() do
        :renewal -> {div(300 - 5, 2), div(100, 2)}
        :pre_renewal -> {300 - 5, 100}
      end

    assert eventually(fn -> sp(ally) == to_ally and sp(professor) == to_professor end, 8_000)
  end

  test "Fiber Lock roots a monster until a Fire Bolt burns the web" do
    professor =
      start_caster(@professor, %{"#{@spiderweb}" => 1, "#{@fire_bolt}" => 1}, [{1025, 1}])

    mob = start_target({153, 150})

    cast(professor, @spiderweb, 1, mob.unit_id)

    assert eventually(fn ->
             match?(
               %{state: %{slots: [_gid, nil, nil]}},
               StatusStorage.get_status(:mob, mob.unit_id, :sc_spiderweb)
             )
           end)

    assert [_web] = SkillUnitStorage.get_groups_by_caster(:player, professor.character.id)

    assert eventually(fn ->
             PlayerState.act_ready?(
               get_player_state(professor.pid),
               System.monotonic_time(:millisecond)
             )
           end)

    cast(professor, @fire_bolt, 1, mob.unit_id)

    assert eventually(
             fn ->
               not StatusStorage.has_status?(:mob, mob.unit_id, :sc_spiderweb) and
                 SkillUnitStorage.get_groups_by_caster(:player, professor.character.id) == []
             end,
             8_000
           )
  end

  test "Fiber Lock catches every monster on the web's cell and keeps the last one caught" do
    professor = start_caster(@professor, %{"#{@spiderweb}" => 1}, [{1025, 1}])
    first = start_target({153, 150})
    second = start_target({153, 150})

    cast(professor, @spiderweb, 1, first.unit_id)

    assert eventually(fn ->
             Enum.all?([first, second], fn mob ->
               StatusStorage.has_status?(:mob, mob.unit_id, :sc_spiderweb)
             end)
           end)

    # Monsters are caught most recent to enter the block first, so the first
    # spawned is caught last and kept.
    first_ref = {:mob, first.unit_id}

    assert eventually(fn ->
             match?(
               [%{state: %{victim: ^first_ref}}],
               SkillUnitStorage.get_groups_by_caster(:player, professor.character.id)
             )
           end)
  end

  test "Double Casting echoes a landed bolt once" do
    Mimic.copy(BoltEcho)

    stub(BoltEcho, :maybe_schedule, fn caster, target, bolt_id, level ->
      Mimic.call_original(BoltEcho, :maybe_schedule, [
        caster,
        target,
        bolt_id,
        level,
        fn 100 -> 1 end
      ])
    end)

    professor =
      start_caster(@professor, %{"#{@double_casting}" => 5, "#{@lightning_bolt}" => 1})

    Mimic.allow(BoltEcho, self(), professor.pid)
    mob = start_target({153, 150})
    target_id = mob.unit_id

    cast(professor, @double_casting, 5)

    assert eventually(
             fn -> StatusStorage.has_status?(:player, professor.character.id, :sc_doublecast) end,
             8_000
           )

    assert eventually(fn ->
             PlayerState.act_ready?(
               get_player_state(professor.pid),
               System.monotonic_time(:millisecond)
             )
           end)

    clear_packet_inbox()
    cast(professor, @lightning_bolt, 1, target_id)

    assert_receive {:packet_sent, %SkillDamage{skill_id: @lightning_bolt, target_id: ^target_id},
                    _channel},
                   8_000

    assert_receive {:packet_sent, %SkillDamage{skill_id: @lightning_bolt, target_id: ^target_id},
                    _channel},
                   4_000

    refute_receive {:packet_sent, %SkillDamage{skill_id: @lightning_bolt}, _channel}, 1_500
  end

  defp start_caster_from(character) do
    session =
      start_player_session(
        character: Repo.get!(Character, character.id),
        map_name: map(),
        position: {character.last_x, character.last_y}
      )

    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp sp(session), do: get_player_state(session.pid).stats.current_state.sp
end

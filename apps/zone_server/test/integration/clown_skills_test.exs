defmodule Aesir.ZoneServer.Integration.ClownSkillsTest do
  @moduledoc "Real-session Clown and Gypsy skill coverage in renewal and pre-renewal."
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Proximity
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.SessionHelpers
  alias Aesir.ZoneServer.TestSupport.ClownSessions
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @map "prontera"
  @arrow_vulcan 394
  @marionette 396
  @longing 487
  @hermode 488
  @drum 309
  @special_singer 5068

  setup do
    ClownSessions.blank_map(@map)
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    :ok
  end

  test "Arrow Vulcan strikes at range, shown as nine hits" do
    clown = start(:clown, {150, 150}, %{@arrow_vulcan => 1})
    Mimic.allow(HitCalculations, self(), clown.pid)
    mob = start_mob({157, 150})
    mob_id = mob.unit_id

    ClownSessions.cast(clown, @arrow_vulcan, 1, mob_id)

    assert_receive {:packet_sent,
                    %SkillDamage{skill_id: 394, target_id: ^mob_id, damage: damage, div: 9},
                    _channel},
                   4_000

    assert damage > 0
    assert eventually(fn -> get_mob_state(mob.pid).hp == 100_000 - damage end)
  end

  test "Marionette transfers half the master's stats and unlinks both beyond seven cells" do
    clown = ClownSessions.character(:clown, @map, {150, 150}, %{@marionette => 1}, %{str: 80})
    gypsy = ClownSessions.character(:gypsy, @map, {152, 150}, %{})
    ClownSessions.party([clown, gypsy])
    master = ClownSessions.start_session(clown)
    puppet = ClownSessions.start_session(gypsy)

    {master_str, puppet_str} = {effective_str(master), effective_str(puppet)}

    ClownSessions.cast(master, @marionette, 1, puppet.character.id)

    assert eventually(fn ->
             effective_str(master) == master_str - 40 and
               effective_str(puppet) == puppet_str + 40
           end)

    assert has_status?(master, :sc_marionette)
    assert has_status?(puppet, :sc_marionette2)

    simulate_incoming_message(puppet.pid, %MoveRequest{dest_x: 158, dest_y: 150})

    assert eventually(fn ->
             not has_status?(master, :sc_marionette) and
               not has_status?(puppet, :sc_marionette2)
           end)

    assert effective_str(master) == master_str
    assert effective_str(puppet) == puppet_str
  end

  @tag game_mode: :renewal, integration_pre_re: false
  test "renewal Hermode strips a party member's buffs, not the caster's, and voids magic" do
    clown = ClownSessions.character(:clown, @map, {150, 150}, %{@hermode => 1})
    novice = ClownSessions.character(:novice, @map, {152, 150}, %{})
    ClownSessions.party([clown, novice])
    caster = ClownSessions.start_session(clown)
    member = ClownSessions.start_session(novice)
    member_id = member.character.id

    for session <- [caster, member] do
      :ok = PlayerSession.apply_status(session.pid, :sc_blessing, val1: 10, duration: 60_000)
    end

    ClownSessions.cast(caster, @hermode, 1)

    assert eventually(fn -> has_status?(member, :sc_hermode) end)
    refute has_status?(member, :sc_blessing)
    assert eventually(fn -> has_status?(caster, :sc_hermode) end)
    assert has_status?(caster, :sc_blessing)

    mob = start_mob({158, 150})
    MobSession.set_target(mob.pid, {:player, member_id})
    assert eventually(fn -> get_mob_state(mob.pid).target_ref == {:player, member_id} end)
    hp = get_player_state(member.pid).stats.current_state.hp
    row = %{skill: "MG_COLDBOLT", skill_id: 14, level: 5, target: :target}

    assert :ok = Executor.execute(get_mob_state(mob.pid), row)

    assert_receive {:packet_sent, %SkillDamage{skill_id: 14, target_id: ^member_id}, _channel},
                   1_000

    assert get_player_state(member.pid).stats.current_state.hp == hp
  end

  describe "pre-renewal Hermode" do
    @describetag game_mode: :pre_renewal, integration_re: false

    test "is refused away from any NPC or warp" do
      position = {300, 50}
      {x, y} = position
      refute Proximity.touch_area_within?(@map, x, y, 1)
      clown = start(:clown, position, %{@hermode => 1})
      flush_packets()

      ClownSessions.cast(clown, @hermode, 1)

      assert_packet_sent(SkillCastFailed)
      refute has_status?(clown, :sc_dancing)
    end

    test "next to a warp places a rooted field that party members gain and lose" do
      :ok = Warps.reload()
      {:ok, [warp | _]} = Warps.for_map(@map)
      {x, y} = {warp.x + warp.xs + 1, warp.y}
      clown = ClownSessions.character(:clown, @map, {x, y}, %{@hermode => 1})
      novice = ClownSessions.character(:novice, @map, {x + 5, y}, %{})
      ClownSessions.party([clown, novice])
      caster = ClownSessions.start_session(clown)
      member = ClownSessions.start_session(novice)

      ClownSessions.cast(caster, @hermode, 1)

      assert eventually(fn ->
               match?(%{state: %{root: :always, upkeep: 5}}, dancing(caster))
             end)

      refute StatusInterpreter.can_move?(:player, caster.character.id)
      refute has_status?(member, :sc_hermode)

      simulate_incoming_message(member.pid, %MoveRequest{dest_x: x + 2, dest_y: y})
      assert eventually(fn -> has_status?(member, :sc_hermode) end)

      simulate_incoming_message(member.pid, %MoveRequest{dest_x: x + 5, dest_y: y})
      assert eventually(fn -> not has_status?(member, :sc_hermode) end)
    end
  end

  @tag game_mode: :renewal, integration_pre_re: false
  test "renewal Skilled Special Singer clears the caster's ensemble fatigue" do
    %{clown: clown, gypsy: gypsy} = start_pair(%{@special_singer => 1})

    ClownSessions.cast(clown, @drum, 5)

    assert eventually(fn ->
             has_status?(clown, :sc_ensemblefatigue) and has_status?(gypsy, :sc_ensemblefatigue)
           end)

    assert eventually(fn -> act_ready?(clown) end)
    ClownSessions.cast(clown, @special_singer, 1)

    assert eventually(fn -> not has_status?(clown, :sc_ensemblefatigue) end)
    assert has_status?(gypsy, :sc_ensemblefatigue)
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "pre-renewal Longing lets a performer walk and attack, and leaving the field ends it" do
    %{clown: clown, gypsy: gypsy} = start_pair(%{@longing => 5})
    Mimic.allow(HitCalculations, self(), clown.pid)

    ClownSessions.cast(clown, @drum, 5)

    assert eventually(fn ->
             has_status?(clown, :sc_dancing) and has_status?(gypsy, :sc_dancing)
           end)

    refute StatusInterpreter.can_move?(:player, clown.character.id)

    ClownSessions.cast(clown, @longing, 5)
    assert eventually(fn -> has_status?(clown, :sc_longing) end)
    assert get_player_state(clown.pid).walk_speed == 150

    simulate_incoming_message(clown.pid, %MoveRequest{dest_x: 150, dest_y: 151})
    assert eventually(fn -> position(clown) == {150, 151} end)

    mob = start_mob({150, 152})
    simulate_incoming_message(clown.pid, %ActionRequest{target_id: mob.unit_id, action: 0})
    assert eventually(fn -> get_mob_state(mob.pid).hp < 100_000 end)

    simulate_incoming_message(clown.pid, %MoveRequest{dest_x: 156, dest_y: 151})
    assert eventually(fn -> position(clown) == {156, 151} end)

    assert eventually(fn ->
             not has_status?(clown, :sc_dancing) and not has_status?(gypsy, :sc_dancing)
           end)
  end

  test "Marionette Control links the caster's own Homunculus and recasting ends both" do
    clown = ClownSessions.character(:clown, @map, {150, 150}, %{@marionette => 1}, %{str: 80})
    insert_homunculus(clown.id)
    character = Repo.preload(Repo.get!(Character, clown.id), :homunculus)

    caster =
      SessionHelpers.start_player_session(
        character: character,
        map_name: @map,
        position: {150, 150}
      )

    on_exit(fn ->
      if Process.alive?(caster.pid), do: SessionHelpers.end_player_session(caster)
    end)

    assert eventually(fn -> homunculus(caster) end)

    gid = homunculus(caster).world_gid
    master_str = effective_str(caster)

    ClownSessions.cast(caster, @marionette, 1, gid)

    assert eventually(fn ->
             StatusStorage.has_status?(:homunculus, gid, :sc_marionette2) and
               homunculus(caster).str == 99
           end)

    assert has_status?(caster, :sc_marionette)
    assert effective_str(caster) == master_str - 40

    ClownSessions.cast(caster, @marionette, 1, gid)

    assert eventually(fn ->
             not has_status?(caster, :sc_marionette) and
               not StatusStorage.has_status?(:homunculus, gid, :sc_marionette2)
           end)
  end

  defp insert_homunculus(character_id) do
    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character_id,
      class_id: 6001,
      name: "Lif",
      lifecycle: "active",
      hp: 1_000,
      max_hp: 1_000,
      sp: 40,
      max_sp: 40,
      str: 60,
      agi: 10,
      vit: 0,
      int: 10,
      dex: 10,
      luk: 0,
      active_remaining_ms: 1_800_000
    })
    |> Repo.insert!()
  end

  defp homunculus(session), do: PlayerSession.get_state(session.pid).homunculus

  defp start_pair(clown_skills) do
    clown =
      ClownSessions.character(:clown, @map, {150, 150}, Map.put(clown_skills, @drum, 5))

    gypsy = ClownSessions.character(:gypsy, @map, {151, 150}, %{@drum => 5})
    ClownSessions.party([clown, gypsy])
    %{clown: ClownSessions.start_session(clown), gypsy: ClownSessions.start_session(gypsy)}
  end

  defp start(job, position, skills) do
    job
    |> ClownSessions.character(@map, position, skills)
    |> ClownSessions.start_session()
  end

  defp start_mob(position) do
    mob =
      start_mob_session(
        map_name: @map,
        position: position,
        hp: 100_000,
        max_hp: 100_000,
        vit: 0,
        luk: 0
      )

    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end

  defp has_status?(session, status),
    do: StatusStorage.has_status?(:player, session.character.id, status)

  defp dancing(session), do: StatusStorage.get_status(:player, session.character.id, :sc_dancing)

  defp effective_str(session),
    do: Stats.get_effective_stat(get_player_state(session.pid).stats, :str)

  defp position(session) do
    state = get_player_state(session.pid)
    {state.x, state.y}
  end

  defp act_ready?(session),
    do: PlayerState.act_ready?(get_player_state(session.pid), System.monotonic_time(:millisecond))
end

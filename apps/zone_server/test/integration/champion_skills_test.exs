defmodule Aesir.ZoneServer.Integration.ChampionSkillsTest do
  @moduledoc """
  Live-session acceptance coverage for the Champion kit in renewal and
  pre-renewal: Zen, the extended combo chain into an instant Asura Strike, the
  pre-renewal Chain Crush to Glacier Fist loop, and Raging Palm Strike's delayed
  blow. Network transport alone is faked; skills, combat, combo windows,
  spheres and knockback use their real session routes.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCasting
  alias Aesir.Net.SpiritSphereUpdate
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @map "prontera"
  @champion_job 4016

  @asura 271
  @quadruple 272
  @thrust 273
  @palm_strike 370
  @glacier_fist 371
  @chain_crush 372
  @zen 401

  @skills %{
    "261" => 5,
    "263" => 10,
    "269" => 5,
    "270" => 5,
    "271" => 5,
    "272" => 5,
    "273" => 5,
    "370" => 5,
    "371" => 5,
    "372" => 10,
    "401" => 1
  }

  setup do
    Mimic.copy(Formulas)
    stub(Formulas, :trifecta_activation_rate, fn _level -> 100 end)
    :ok
  end

  describe "Zen" do
    test "fills the session to five broadcast spheres" do
      champion = start_champion(9_301)

      cast(champion, @zen, 1)

      assert eventually(fn -> sphere_count(champion) == 5 end)
      assert_packet_sent(SpiritSphereUpdate, 500)
    end
  end

  describe "combo chain" do
    @tag game_mode: :renewal, integration_pre_re: false
    test "Thrust, Glacier Fist and Chain Crush end in an instant Asura spending every sphere" do
      champion = start_champion(9_302)
      mob = spawn_target_mob(9_402)
      zen(champion)
      fury(champion)

      open_thrust_window(champion, mob)

      chain(champion, @thrust, 5, mob)
      assert eventually(fn -> sphere_count(champion) == 4 end)

      chain(champion, @glacier_fist, 5, mob)
      assert eventually(fn -> stage(champion) == :tiger_fist and sphere_count(champion) == 3 end)

      chain(champion, @chain_crush, 10, mob)
      assert eventually(fn -> stage(champion) == :chain_crush and sphere_count(champion) == 2 end)

      # Renewal Glacier Fist only follows Raging Thrust.
      # The state read queues behind the refused cast in the session mailbox.
      wait_act_ready(champion)
      cast(champion, @glacier_fist, 5, mob.unit_id)
      assert stage(champion) == :chain_crush
      assert sphere_count(champion) == 2

      hp_before = mob_hp(mob)
      flush_packets(SkillCasting)
      cast(champion, @asura, 5, mob.unit_id)

      # Instant: resolved well inside the 1 s + 1 s level-5 cast it would need.
      assert eventually(fn -> sphere_count(champion) == 0 end, 600)
      refute_received {:packet_sent, %SkillCasting{skill_id: @asura}, _channel}
      assert eventually(fn -> mob_hp(mob) < hp_before end)
      assert get_player_state(champion.pid).stats.current_state.sp == 0
    end

    @tag game_mode: :pre_renewal, integration_re: false
    test "pre-renewal Chain Crush loops back into Glacier Fist" do
      champion = start_champion(9_303)
      mob = spawn_target_mob(9_403)
      zen(champion)

      open_thrust_window(champion, mob)

      chain(champion, @thrust, 5, mob)
      assert eventually(fn -> stage(champion) == :extremity and sphere_count(champion) == 4 end)

      chain(champion, @chain_crush, 10, mob)
      assert eventually(fn -> stage(champion) == :chain_crush and sphere_count(champion) == 2 end)

      # Glacier Fist lands off Chain Crush; one sphere left is too few to reopen
      # toward Chain Crush, so the loop ends here.
      chain(champion, @glacier_fist, 5, mob)
      assert eventually(fn -> sphere_count(champion) == 1 and stage(champion) == :idle end)
    end
  end

  describe "Raging Palm Strike" do
    test "shows a zero-damage hit, then strikes and pushes the target three cells" do
      champion = start_champion(9_304)
      mob = spawn_target_mob(9_404)
      fury(champion)
      hp_before = mob_hp(mob)

      cast(champion, @palm_strike, 5, mob.unit_id)

      assert_receive {:packet_sent, %DamageDealt{damage: 0, target_id: 9_404}, _channel}, 500
      assert eventually(fn -> mob_hp(mob) < hp_before end)

      assert eventually(fn ->
               match?({:ok, {154, 150, @map}}, SpatialIndex.get_unit_position(:mob, 9_404))
             end)
    end
  end

  # Drives a real Trifecta swing, then Raging Quadruple Blow, so the session
  # holds the Raging Thrust window on `mob`.
  defp open_thrust_window(champion, mob) do
    Mimic.allow(Formulas, self(), champion.pid)
    simulate_incoming_message(champion.pid, %ActionRequest{target_id: mob.unit_id, action: 0})
    assert eventually(fn -> stage(champion) == :quadruple end)

    cast(champion, @quadruple, 5, mob.unit_id)
    assert eventually(fn -> stage(champion) == :thrust end)
  end

  # A follow-up is cast once the previous skill's after-cast delay has passed,
  # inside the window's grace.
  defp chain(champion, skill_id, level, mob) do
    wait_act_ready(champion)
    cast(champion, skill_id, level, mob.unit_id)
  end

  defp wait_act_ready(champion) do
    assert eventually(
             fn ->
               PlayerState.act_ready?(
                 get_player_state(champion.pid),
                 System.monotonic_time(:millisecond)
               )
             end,
             2_000,
             5
           )
  end

  defp zen(champion) do
    cast(champion, @zen, 1)
    assert eventually(fn -> sphere_count(champion) == 5 end)
  end

  defp fury(champion) do
    id = champion.character.id

    :ok =
      StatusStorage.apply_status(:player, id, :sc_explosionspirits,
        val1: 5,
        caster_id: id,
        duration: 180_000
      )
  end

  defp flush_packets(type) do
    receive do
      {:packet_sent, %{__struct__: ^type}, _channel} -> flush_packets(type)
    after
      0 -> :ok
    end
  end

  defp cast(champion, skill_id, level, target_id \\ nil) do
    simulate_incoming_message(champion.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id || champion.character.id
    })
  end

  defp stage(champion), do: get_player_state(champion.pid).combo.stage

  defp sphere_count(champion),
    do: SpiritSpheres.count(get_player_state(champion.pid).spirit_spheres)

  defp mob_hp(mob), do: get_mob_state(mob.pid).hp

  defp start_champion(id) do
    start_player_session(
      character: %Character{
        id: id,
        account_id: id,
        name: "Champ#{id}",
        char_num: 0,
        class: @champion_job,
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        zeny: 5_000,
        str: 60,
        agi: 40,
        vit: 40,
        int: 30,
        dex: 90,
        luk: 20,
        hp: 9_000,
        max_hp: 9_000,
        sp: 500,
        max_sp: 500,
        status_point: 0,
        skill_point: 0,
        learned_skills: @skills,
        party_id: 0,
        last_map: @map,
        last_x: 150,
        last_y: 150,
        save_map: @map,
        save_x: 150,
        save_y: 150,
        hair: 1,
        hair_color: 1,
        clothes_color: 0,
        online: true
      },
      map_name: @map,
      position: {150, 150}
    )
  end

  # A level-1, AGI-1 mob keeps flee low so every skill hit connects.
  defp spawn_target_mob(unit_id) do
    start_mob_session(
      mob_id: 1_002,
      unit_id: unit_id,
      map_name: @map,
      position: {151, 150},
      hp: 1_000_000,
      max_hp: 1_000_000,
      level: 1,
      agi: 1
    )
  end
end

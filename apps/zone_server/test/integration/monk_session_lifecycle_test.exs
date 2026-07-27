defmodule Aesir.ZoneServer.Integration.MonkSessionLifecycleTest do
  @moduledoc """
  Session-lifecycle cleanup for Monk-owned state: death, cross-map warp, and
  disconnect against a live `PlayerSession`.

  Verifies that spirit spheres and their timer, the combo window, the recovery
  and Fury statuses, and the paired Root lock are torn down on each exit path -
  including the eventually-consistent convergence of a Root peer whose partner
  cleared its status storage directly on termination (the disconnect path),
  which the per-second status tick reconciles.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @map "prontera"
  @dest_map "prt_fild01"
  @monk_job 15

  describe "death" do
    test "clears spheres, Fury, the recovery status, and the combo window" do
      Mimic.copy(Formulas)
      stub(Formulas, :trifecta_activation_rate, fn _level -> 100 end)

      monk = start_monk_session(7_001, {150, 150})
      mob = spawn_mob(7_101, {151, 150})

      # The swing runs inside the session process, so let it observe the stub.
      Mimic.allow(Formulas, self(), monk.pid)

      PlayerSession.summon_spirit_sphere(monk.pid, 600_000, 5)
      apply_fury(monk.character.id)
      apply_recovery(monk.character.id)
      open_combo(monk.pid, mob.unit_id)

      assert eventually(fn -> sphere_count(monk.pid) == 1 end)
      assert eventually(fn -> get_player_state(monk.pid).combo.stage == :quadruple end)

      full_hp = get_player_state(monk.pid).stats.current_state.hp
      PlayerSession.apply_damage(monk.pid, full_hp, 1)

      assert eventually(fn -> get_player_state(monk.pid).action_state == :dead end)

      state = get_player_state(monk.pid)
      assert SpiritSpheres.count(state.spirit_spheres) == 0
      assert state.combo.stage == :idle
      refute StatusStorage.has_status?(:player, monk.character.id, :sc_explosionspirits)
      refute StatusStorage.has_status?(:player, monk.character.id, :sc_extremityfist)
    end

    test "canonically closes an established Root pair" do
      monk = start_monk_session(7_002, {150, 150})
      mob = spawn_mob(7_102, {151, 150})
      establish_root(monk.character.id, mob)

      full_hp = get_player_state(monk.pid).stats.current_state.hp
      PlayerSession.apply_damage(monk.pid, full_hp, 1)

      assert eventually(fn -> get_player_state(monk.pid).action_state == :dead end)

      # Death runs on_expire, so the peer record is closed directly - no tick needed.
      refute Root.rooted?(:player, monk.character.id)
      refute Root.rooted?(:mob, mob.unit_id)
    end
  end

  describe "cross-map warp" do
    test "closes the Root pair via remove_on_map_change but keeps owned spheres" do
      monk = start_monk_session(7_003, {150, 150})
      mob = spawn_mob(7_103, {151, 150})

      for _ <- 1..3, do: PlayerSession.summon_spirit_sphere(monk.pid, 600_000, 5)
      assert eventually(fn -> sphere_count(monk.pid) == 3 end)
      establish_root(monk.character.id, mob)

      PlayerSession.warp(monk.pid, @dest_map, 100, 100)

      assert eventually(fn -> get_player_state(monk.pid).map_name == @dest_map end)

      # The pair ends on the map change; valid owned spheres survive the warp.
      refute Root.rooted?(:player, monk.character.id)
      refute Root.rooted?(:mob, mob.unit_id)
      assert sphere_count(monk.pid) == 3
    end
  end

  describe "disconnect" do
    test "discards spheres and its timer without leaking a stale expiry message" do
      monk = start_monk_session(7_004, {150, 150})
      PlayerSession.summon_spirit_sphere(monk.pid, 40, 5)
      assert eventually(fn -> sphere_count(monk.pid) == 1 end)

      ref = Process.monitor(monk.pid)
      :ok = GenServer.stop(monk.pid, :normal)
      assert_receive {:DOWN, ^ref, :process, _, :normal}, 1_000

      # The discarded timer fires no work after teardown; the session is gone and
      # its status storage was cleared, so nothing is left to converge for it.
      Process.sleep(80)
      assert StatusStorage.get_unit_statuses(:player, 7_004) == []
    end

    test "a Root peer left behind by a terminating session converges on the status tick" do
      monk = start_monk_session(7_005, {150, 150})
      mob = spawn_mob(7_105, {151, 150})
      establish_root(monk.character.id, mob)

      ref = Process.monitor(monk.pid)
      # Terminate bulk-clears the Monk's status storage without running on_expire,
      # stranding the mob's half of the pair.
      :ok = GenServer.stop(monk.pid, :normal)
      assert_receive {:DOWN, ^ref, :process, _, :normal}, 1_000

      assert Root.rooted?(:mob, mob.unit_id)
      refute StatusStorage.has_status?(:player, 7_005, :sc_bladestop)

      # The per-second peer check on the mob's record removes it once due.
      force_due(:mob, mob.unit_id, :sc_bladestop)
      StatusTickManager.force_tick()

      assert eventually(fn -> not Root.rooted?(:mob, mob.unit_id) end)
    end
  end

  # --- helpers -------------------------------------------------------------

  defp start_monk_session(id, {x, y}) do
    start_player_session(character: monk_character(id, {x, y}), map_name: @map, position: {x, y})
  end

  defp monk_character(id, {x, y}) do
    %Character{
      id: id,
      account_id: id,
      name: "Monk#{id}",
      char_num: 0,
      class: @monk_job,
      base_level: 99,
      job_level: 50,
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
      learned_skills: %{263 => 10},
      last_map: @map,
      last_x: x,
      last_y: y,
      save_map: @map,
      save_x: 150,
      save_y: 150,
      hair: 1,
      hair_color: 1,
      clothes_color: 0,
      online: true
    }
  end

  defp spawn_mob(unit_id, position) do
    start_mob_session(
      mob_id: 1_002,
      unit_id: unit_id,
      map_name: @map,
      position: position,
      hp: 200_000,
      max_hp: 200_000,
      level: 1,
      agi: 1
    )
  end

  defp sphere_count(pid), do: SpiritSpheres.count(get_player_state(pid).spirit_spheres)

  defp apply_fury(id) do
    :ok =
      StatusStorage.apply_status(:player, id, :sc_explosionspirits,
        val1: 5,
        caster_id: id,
        duration: 180_000
      )
  end

  defp apply_recovery(id) do
    :ok =
      StatusStorage.apply_status(:player, id, :sc_extremityfist,
        val1: 5,
        caster_id: id,
        duration: 3_000
      )
  end

  # Drives a real Trifecta swing through the live session so the Quadruple combo
  # window opens on the session's own state.
  defp open_combo(pid, mob_id) do
    PlayerSession.deliver_message(pid, %ActionRequest{target_id: mob_id, action: 0})
  end

  # Arms the Monk's Root stance and lets a live mob's real swing claim it.
  defp establish_root(monk_id, mob) do
    :ok =
      StatusStorage.apply_status(:player, monk_id, :sc_bladestop_wait,
        val1: 5,
        caster_id: monk_id,
        duration: 5_000
      )

    assert :intercepted = Combat.execute_mob_attack(mob.mob_state, monk_id)
    assert Root.rooted?(:player, monk_id)
    assert Root.rooted?(:mob, mob.unit_id)
  end

  defp force_due(unit_type, unit_id, status_type) do
    past = System.monotonic_time(:millisecond) - 1_000
    :ok = StatusStorage.update_next_tick(unit_type, unit_id, status_type, past)
  end
end

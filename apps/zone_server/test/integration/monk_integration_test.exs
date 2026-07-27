defmodule Aesir.ZoneServer.Integration.MonkIntegrationTest do
  @moduledoc """
  Playable Monk flows driven through the real skill, combat, status, movement,
  spirit-sphere, and protocol subsystems - only the network layer is captured.

  The skill-cast flows drive the real `Skill.Interpreter` two-phase pipeline
  (validate -> resolve cost -> run behaviour -> commit) synchronously against
  registered Monk `PlayerState` fixtures and live mob sessions, so the assertions
  observe genuine damage, status writes, resource drains, and staged directives.
  Session-owned and cross-session flows (sphere summon/expiry/broadcast, Ki
  Translation delivery) drive live `PlayerSession` processes.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.SpiritSphereUpdate
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter.Deferred
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoBodyrelocation
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoKitranslation
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.SpiritExchangeHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpawnView
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @monk_job 15

  # Every normal + quest Monk skill, learned at its maximum, so the interpreter's
  # learned-skill gate never blocks a fixture cast.
  @monk_skills %{
    261 => 5,
    262 => 1,
    263 => 10,
    264 => 1,
    266 => 5,
    267 => 5,
    268 => 5,
    269 => 5,
    270 => 5,
    271 => 5,
    272 => 5,
    273 => 5,
    1_015 => 1,
    1_016 => 1
  }

  # Skill damage and the Ki Explosion stun ride ordinary hit and status-landing
  # rolls; the Monk flows under test are the mechanics on top of a landed hit, so
  # pin both rolls to success to keep the damage assertions deterministic. Miss,
  # perfect-dodge, and resistance are covered by their own unit tests.
  setup do
    Mimic.copy(HitCalculations)
    Mimic.copy(Resistance)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    stub(Resistance, :roll_success, fn _rate -> true end)
    :ok
  end

  describe "spirit sphere lifecycle and protocol" do
    test "summoning caps at five and streams monotonically-revisioned updates to the owner" do
      monk = start_monk_session(1_001)
      flush_packets()

      for _ <- 1..7, do: PlayerSession.summon_spirit_sphere(monk.pid, 600_000, 5)

      assert eventually(fn -> sphere_count(monk.pid) == 5 end)

      revisions = collected_revisions(monk.character.id)
      assert length(revisions) >= 5
      assert revisions == Enum.sort(revisions)
      assert revisions == Enum.dedup(revisions)
      assert List.last(revisions) == get_player_state(monk.pid).spirit_sphere_revision
    end

    test "an owned sphere expires on its own timer and re-broadcasts the reduced count" do
      monk = start_monk_session(1_002)
      flush_packets()

      PlayerSession.summon_spirit_sphere(monk.pid, 80, 5)
      assert eventually(fn -> sphere_count(monk.pid) == 1 end)

      assert eventually(fn -> sphere_count(monk.pid) == 0 end)

      # The last update the owner sees carries the drained count and the highest
      # revision, so an out-of-order consumer keeps the authoritative state.
      updates = collect_sphere_updates(monk.character.id)
      last = List.last(updates)
      assert last.count == 0
      assert last.revision == get_player_state(monk.pid).spirit_sphere_revision
    end

    test "the spawn view exposes the authoritative sphere count and revision to an observer" do
      monk = start_monk_session(1_003)
      for _ <- 1..3, do: PlayerSession.summon_spirit_sphere(monk.pid, 600_000, 5)
      assert eventually(fn -> sphere_count(monk.pid) == 3 end)

      state = get_player_state(monk.pid)
      spawn = SpawnView.build(state)

      assert spawn.spirit_sphere_count == 3
      assert spawn.spirit_sphere_revision == state.spirit_sphere_revision
      assert spawn.spirit_sphere_revision > 0
    end
  end

  describe "cross-session spirit exchange" do
    test "Ki Translation validates a party member, sends one delivery, and the target commits it" do
      source = monk_fixture(5_001, party_id: 10, spheres: 1, position: {150, 150})
      target = monk_fixture(5_002, party_id: 10, position: {151, 150})
      _stranger = monk_fixture(5_099, party_id: 0, position: {152, 150})
      flush_packets()

      # Real eligibility over the live registry: same-party member is valid, an
      # unpartied stranger is not.
      assert :ok = MoKitranslation.validate(source, {:unit, 5_002}, 1, kitranslation_definition())

      assert {:error, :invalid_target} =
               MoKitranslation.validate(source, {:unit, 5_099}, 1, kitranslation_definition())

      # The source stages exactly one best-effort delivery to the target's session.
      assert :ok = SpiritExchangeHandler.transfer(%{game_state: source}, 5_002)

      assert_receive {:"$gen_cast",
                      {:receive_spirit_sphere,
                       %{source_id: 5_001, source_pid: source_pid, target_id: 5_002} = request}}

      assert source_pid == self()

      # The party member accepts it, commits the sphere, and rebroadcasts the count.
      assert {:noreply, received} =
               SpiritExchangeHandler.receive_sphere(
                 %{connection_pid: self(), game_state: target},
                 request
               )

      assert SpiritSpheres.count(received.game_state.spirit_spheres) == 1

      assert_receive {:send, :world,
                      {:spirit_sphere_update, %SpiritSphereUpdate{unit_id: 5_002, count: 1}}}
    end

    test "Absorb clears the caster's own spheres locally but a player target is PvP-gated" do
      caster = monk_fixture(5_003, spheres: 3, sp: 300)

      # Self absorb settles locally, clearing every sphere for a 7-per-sphere reward.
      assert {:deferred, cleared, %Deferred{effect: {:absorb_local, reward}}} =
               Interpreter.cast(caster, 262, 1, :self)

      assert SpiritSpheres.count(cleared.spirit_spheres) == 0
      assert reward == 7 * 3

      # A player target is refused by the current no-PvP targeting policy: the live
      # target keeps its spheres and the caster receives no reply.
      source = start_monk_session(5_004, position: {150, 150})
      victim = start_monk_session(5_005, position: {151, 150})
      for _ <- 1..2, do: PlayerSession.summon_spirit_sphere(victim.pid, 600_000, 5)
      assert eventually(fn -> sphere_count(victim.pid) == 2 end)

      token = make_ref()

      GenServer.cast(
        victim.pid,
        {:absorb_spirit_spheres, Map.put(delivery_request(source, victim), :token, token)}
      )

      Process.sleep(50)
      assert sphere_count(victim.pid) == 2
      refute_receive {:"$gen_cast", {:spirit_absorb_result, ^token, _, _}}
    end
  end

  describe "Trifecta combo chain" do
    test "Trifecta replaces the swing, opens Quadruple, and flows into Thrust on the retained target" do
      Mimic.copy(Formulas)
      stub(Formulas, :trifecta_activation_rate, fn _level -> 100 end)

      monk = monk_fixture(2_001, spheres: 5, sp: 300)
      mob = spawn_target_mob(2_101, {151, 150}, hp: 200_000)

      # A normal swing is fully replaced by Trifecta and returns the Quadruple
      # window directive for the retained mob.
      assert {:ok, {:combo, :quadruple, {:mob, 2_101}, delay}} =
               Combat.execute_attack(monk.stats, monk, mob.unit_id)

      assert delay > 0

      quad_state = %{monk | combo: Combo.open(Combo.new(), :quadruple, {:mob, 2_101}, future())}

      hp_before_quad = mob_hp(mob.pid)

      assert {:ok, after_quad} = Interpreter.cast(quad_state, 272, 5, {:unit, mob.unit_id})
      assert after_quad.combo.stage == :thrust
      assert mob_hp(mob.pid) < hp_before_quad

      hp_before_thrust = mob_hp(mob.pid)

      # The Quadruple commit armed an after-cast delay; the player waits it out
      # before the Thrust in a live chain, so clear it to continue the window.
      after_quad = %{after_quad | act_delay_until: 0}

      assert {:ok, after_thrust} = Interpreter.cast(after_quad, 273, 5, {:unit, mob.unit_id})
      assert after_thrust.combo.stage == :idle
      assert mob_hp(mob.pid) < hp_before_thrust
    end

    test "a Quadruple follow-up against a different target is rejected as an invalid combo" do
      monk = monk_fixture(2_002, spheres: 5, sp: 300)
      other = spawn_target_mob(2_102, {151, 150}, hp: 10_000)

      quad_state = %{monk | combo: Combo.open(Combo.new(), :quadruple, {:mob, 999_999}, future())}

      assert {:error, :invalid_combo} =
               Interpreter.cast(quad_state, 272, 5, {:unit, other.unit_id})
    end
  end

  describe "Root establishment and level-gated follow-ups" do
    test "a player attacker is caught and both sides hold the paired lock" do
      monk = monk_fixture(3_001, position: {150, 150})
      arm_root_wait(monk.character_id, 5)
      attacker = plain_player_fixture(3_101, {151, 150})

      assert :intercepted = Combat.execute_attack(attacker.stats, attacker, monk.character_id)

      assert Root.linked_peer(:player, monk.character_id) == {:player, 3_101}
      assert Root.linked_peer(:player, 3_101) == {:player, monk.character_id}
    end

    test "a monster attacker is caught within two cells but not beyond" do
      monk = monk_fixture(3_002, position: {150, 150})
      arm_root_wait(monk.character_id, 5)
      mob = spawn_target_mob(4_100, {151, 150}, hp: 5_000)

      # A swing from three cells away is ineligible and leaves the waiting stance
      # intact; the next swing from two cells claims it and establishes the pair.
      assert :continue =
               StatusInterpreter.before_weapon_hit(
                 :player,
                 monk.character_id,
                 mob_attack(3, mob.unit_id)
               )

      refute Root.rooted?(:player, monk.character_id)

      assert {:intercept, :blade_stop} =
               StatusInterpreter.before_weapon_hit(
                 :player,
                 monk.character_id,
                 mob_attack(2, mob.unit_id)
               )

      assert Root.linked_peer(:player, monk.character_id) == {:mob, mob.unit_id}
      assert Root.linked_peer(:mob, mob.unit_id) == {:player, monk.character_id}
    end

    test "a live mob swing establishes the pair through the real combat path" do
      monk = monk_fixture(3_003, position: {150, 150})
      arm_root_wait(monk.character_id, 5)
      mob = spawn_target_mob(4_101, {151, 150}, hp: 5_000)

      assert :intercepted = Combat.execute_mob_attack(mob.mob_state, monk.character_id)

      assert Root.rooted?(:player, monk.character_id)
      assert Root.rooted?(:mob, mob.unit_id)
      # Both participants are pull-gated out of acting through their status.
      refute StatusInterpreter.can_attack?(:mob, mob.unit_id)
      refute StatusInterpreter.can_move?(:player, monk.character_id)
    end

    test "Throw Spirit Sphere is admitted from Root level two and closes the pair" do
      {monk, mob} = rooted_pair(3_004, 4_102, 2, spheres: 3, sp: 300)

      assert StatusInterpreter.can_use_skill?(:player, monk.character_id, 267)
      hp_before = mob_hp(mob.pid)

      assert {:ok, _state} = Interpreter.cast(monk, 267, 5, {:unit, mob.unit_id})

      assert mob_hp(mob.pid) < hp_before
      refute Root.rooted?(:player, monk.character_id)
      refute Root.rooted?(:mob, mob.unit_id)
    end

    test "Occult Impaction is admitted from Root level three and closes the pair" do
      {monk, mob} = rooted_pair(3_005, 4_103, 3, spheres: 3, sp: 300)

      assert StatusInterpreter.can_use_skill?(:player, monk.character_id, 266)
      hp_before = mob_hp(mob.pid)

      assert {:ok, _state} = Interpreter.cast(monk, 266, 5, {:unit, mob.unit_id})

      assert mob_hp(mob.pid) < hp_before
      refute Root.rooted?(:player, monk.character_id)
      refute Root.rooted?(:mob, mob.unit_id)
    end

    test "Asura Strike is hard-gated below Root level five and admitted at five" do
      {monk_low, mob_low} = rooted_pair(3_006, 4_104, 4, spheres: 5, sp: 300, fury: true)

      assert {:error, :insufficient_root_level} =
               Interpreter.cast(monk_low, 271, 5, {:unit, mob_low.unit_id})

      # A rejected follow-up spends nothing and leaves the pair intact.
      assert Root.rooted?(:player, monk_low.character_id)

      {monk_ok, mob_ok} = rooted_pair(3_007, 4_105, 5, spheres: 5, sp: 300, fury: true)
      hp_before = mob_hp(mob_ok.pid)

      assert {:ok, after_asura} = Interpreter.cast(monk_ok, 271, 5, {:unit, mob_ok.unit_id})

      assert mob_hp(mob_ok.pid) < hp_before
      refute Root.rooted?(:player, monk_ok.character_id)
      assert after_asura.stats.current_state.sp == 0
    end
  end

  describe "Fury interactions" do
    test "Snap costs no sphere under Fury and relocates the Monk on the same map" do
      monk = start_monk_session(6_001, position: {150, 150})
      state = get_player_state(monk.pid)

      # Fury zeroes the sphere requirement; without it Snap needs one sphere.
      assert %Cost{sp: 14, spheres: 1} =
               MoBodyrelocation.dynamic_cost(state, {:ground, 156, 150}, 1, snap_definition())

      apply_fury(monk.character.id)
      state = get_player_state(monk.pid)

      assert %Cost{sp: 14, spheres: 0} =
               MoBodyrelocation.dynamic_cost(state, {:ground, 156, 150}, 1, snap_definition())

      {dest_x, dest_y} = walkable_near(@map, 150, 150)
      flush_packets()

      # The live session commits the instant cast with zero spheres and drains the
      # prevalidated relocation directive, moving the Monk in the spatial index.
      PlayerSession.deliver_message(monk.pid, %GroundSkillCast{
        skill_id: 264,
        level: 1,
        x: dest_x,
        y: dest_y
      })

      assert eventually(fn -> get_player_state(monk.pid).x == dest_x end)
      moved = get_player_state(monk.pid)
      assert {moved.x, moved.y} == {dest_x, dest_y}
      assert {:ok, {^dest_x, ^dest_y, @map}} = SpatialIndex.get_unit_position(:player, 6_001)
      assert SpiritSpheres.count(moved.spirit_spheres) == 0
    end

    test "Asura Strike requires Fury to be active" do
      monk = monk_fixture(6_002, spheres: 5, sp: 300)
      mob = spawn_target_mob(6_102, {151, 150}, hp: 10_000)

      assert {:error, :requires_explosion_spirits} =
               Interpreter.cast(monk, 271, 5, {:unit, mob.unit_id})

      apply_fury(6_002)
      assert {:ok, _state} = Interpreter.cast(monk, 271, 5, {:unit, mob.unit_id})
    end
  end

  describe "Mental Strength restrictions and exact modifiers" do
    test "fixes speed at 200, applies the ASPD penalty, prevents skills, and floors damage" do
      monk = start_monk_session(6_003)
      baseline = get_player_state(monk.pid)

      :ok = PlayerSession.apply_status(monk.pid, :sc_steelbody, caster_id: monk.character.id)

      assert eventually(fn -> get_player_state(monk.pid).walk_speed == 200 end)
      state = get_player_state(monk.pid)

      assert state.walk_speed == Formulas.mental_strength_walk_speed()
      assert state.stats.derived_stats.aspd != baseline.stats.derived_stats.aspd
      refute StatusInterpreter.can_use_skill?(:player, monk.character.id)

      # Renewal floor: incoming positive damage becomes max(1, damage / 10).
      assert StatusInterpreter.absorb_damage(:player, monk.character.id, 1_000, %{}) == 100
      assert StatusInterpreter.absorb_damage(:player, monk.character.id, 5, %{}) == 1
    end
  end

  describe "Asura Strike full commitment" do
    test "drains SP and spheres, ends Fury, applies recovery, damages, and stages the move" do
      monk = monk_fixture(6_004, spheres: 5, sp: 250, fury: true, position: {150, 150})
      mob = spawn_target_mob(6_104, {151, 150}, hp: 1_000_000)
      hp_before = mob_hp(mob.pid)

      assert {:ok, after_asura} = Interpreter.cast(monk, 271, 5, {:unit, mob.unit_id})

      # Damage was dealt from the pre-drain pool, then every resource committed.
      assert mob_hp(mob.pid) < hp_before
      assert after_asura.stats.current_state.sp == 0
      assert SpiritSpheres.count(after_asura.spirit_spheres) == 0

      refute StatusStorage.has_status?(:player, 6_004, :sc_explosionspirits)
      assert StatusStorage.has_status?(:player, 6_004, :sc_extremityfist)
      assert after_asura.combo.stage == :idle

      # The three-cell relocation toward the target is staged and prevalidated.
      assert %ForcedMovement{map_name: @map, x: 153, y: 150} =
               after_asura.pending_forced_movement

      # The after-cast delay is committed so the finisher cannot be spammed.
      refute PlayerState.act_ready?(after_asura, System.monotonic_time(:millisecond))
    end

    test "an unwalkable relocation still lands the strike but stages no move" do
      Mimic.copy(Cell)
      stub(Cell, :traversable?, fn @map, _x, _y -> false end)

      monk = monk_fixture(6_005, spheres: 5, sp: 250, fury: true, position: {150, 150})
      mob = spawn_target_mob(6_105, {151, 150}, hp: 1_000_000)
      hp_before = mob_hp(mob.pid)

      assert {:ok, after_asura} = Interpreter.cast(monk, 271, 5, {:unit, mob.unit_id})

      assert mob_hp(mob.pid) < hp_before
      assert after_asura.stats.current_state.sp == 0
      assert after_asura.pending_forced_movement == nil
    end
  end

  describe "Ki Explosion" do
    test "spends HP and SP, splashes damage, knocks back, and stuns the caught targets" do
      Mimic.copy(Formulas)
      stub(Formulas, :ki_explosion_stun_rate, fn -> 100 end)

      monk = monk_fixture(6_006, sp: 200, hp: 9_000, position: {150, 150})
      primary = spawn_target_mob(6_106, {151, 150}, hp: 500_000)
      splashed = spawn_target_mob(6_107, {152, 150}, hp: 500_000)

      primary_hp = mob_hp(primary.pid)
      splashed_hp = mob_hp(splashed.pid)

      assert {:ok, after_cast} = Interpreter.cast(monk, 1_016, 1, {:unit, primary.unit_id})

      assert after_cast.stats.current_state.hp == 9_000 - Formulas.ki_explosion_hp_cost()
      assert after_cast.stats.current_state.sp == 200 - Formulas.ki_explosion_sp_cost()

      assert mob_hp(primary.pid) < primary_hp
      assert mob_hp(splashed.pid) < splashed_hp

      assert StatusStorage.has_status?(:mob, primary.unit_id, :sc_stun)
      assert StatusStorage.has_status?(:mob, splashed.unit_id, :sc_stun)

      # The off-center splashed target is knocked away from the blast.
      assert {:ok, {new_x, _y, @map}} = SpatialIndex.get_unit_position(:mob, splashed.unit_id)
      assert new_x > 152
    end
  end

  # --- helpers -------------------------------------------------------------

  defp start_monk_session(id, opts \\ []) do
    character = monk_character(id, opts)

    start_player_session(
      character: character,
      map_name: @map,
      position: Keyword.get(opts, :position, {150, 150})
    )
  end

  defp monk_character(id, opts) do
    {x, y} = Keyword.get(opts, :position, {150, 150})

    %Character{
      id: id,
      account_id: id,
      name: "Monk#{id}",
      char_num: 0,
      class: @monk_job,
      base_level: Keyword.get(opts, :base_level, 99),
      job_level: 50,
      base_exp: 0,
      job_exp: 0,
      zeny: 5_000,
      str: Keyword.get(opts, :str, 60),
      agi: Keyword.get(opts, :agi, 40),
      vit: 40,
      int: 30,
      dex: Keyword.get(opts, :dex, 90),
      luk: 20,
      hp: Keyword.get(opts, :hp, 9_000),
      max_hp: 9_000,
      sp: Keyword.get(opts, :sp, 500),
      max_sp: 500,
      status_point: 0,
      skill_point: 0,
      learned_skills: Keyword.get(opts, :learned_skills, @monk_skills),
      party_id: Keyword.get(opts, :party_id, 0),
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

  defp sphere_count(pid), do: SpiritSpheres.count(get_player_state(pid).spirit_spheres)

  defp collect_sphere_updates(unit_id) do
    collect_sphere_updates(unit_id, [])
  end

  defp collect_sphere_updates(unit_id, acc) do
    receive do
      {:packet_sent, %SpiritSphereUpdate{unit_id: ^unit_id} = update, _channel} ->
        collect_sphere_updates(unit_id, [update | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end

  defp collected_revisions(unit_id) do
    unit_id |> collect_sphere_updates() |> Enum.map(& &1.revision)
  end

  # Builds a registered Monk `PlayerState` (not a live session) with real,
  # calculated combat stats. The high DEX/base level over a low-flee mob keeps
  # skill hits deterministic (hit rate clamps to 100%).
  defp monk_fixture(id, opts) do
    base = PlayerState.new(monk_character(id, opts))
    calculated = Stats.calculate_stats(base.stats, id, [])

    current = %{
      calculated.current_state
      | sp: Keyword.get(opts, :sp, 500),
        hp: Keyword.get(opts, :hp, 9_000)
    }

    state =
      %{base | stats: %{calculated | current_state: current}}
      |> add_spheres(Keyword.get(opts, :spheres, 0))

    if Keyword.get(opts, :fury, false), do: apply_fury(id)

    register_player_fixture(state)
    state
  end

  defp plain_player_fixture(id, {x, y}) do
    character = %{monk_character(id, position: {x, y}) | class: 0, learned_skills: %{}}
    base = PlayerState.new(character)
    calculated = Stats.calculate_stats(base.stats, id, [])
    state = %{base | stats: calculated}
    register_player_fixture(state)
    state
  end

  defp register_player_fixture(state) do
    :ok = UnitRegistry.register_player(state, self())
    :ok = SpatialIndex.add_unit(:player, state.character_id, state.x, state.y, state.map_name)
  end

  defp add_spheres(state, 0), do: state

  defp add_spheres(state, count) do
    spheres =
      Enum.reduce(1..count, SpiritSpheres.new(), fn _, acc ->
        {acc, _entry} = SpiritSpheres.summon(acc, future(), 5)
        acc
      end)

    %{state | spirit_spheres: spheres}
  end

  defp spawn_target_mob(unit_id, position, opts) do
    hp = Keyword.get(opts, :hp, 10_000)

    start_mob_session(
      mob_id: 1_002,
      unit_id: unit_id,
      map_name: @map,
      position: position,
      hp: hp,
      max_hp: hp,
      # A level-1 mob keeps flee small so the caster's hit rate clamps to 100%.
      level: 1,
      agi: 1
    )
  end

  defp mob_hp(pid), do: get_mob_state(pid).hp

  defp delivery_request(source, target) do
    %{source_id: source.character.id, source_pid: source.pid, target_id: target.character.id}
  end

  defp snap_definition, do: MoBodyrelocation.definition()

  defp kitranslation_definition, do: MoKitranslation.definition()

  # Finds a walkable destination a few cells from the origin so Snap has a valid
  # relocation regardless of the concrete prontera cell layout.
  defp walkable_near(map, x, y) do
    Enum.find_value(2..8, fn dx ->
      if Cell.traversable?(map, x + dx, y), do: {x + dx, y}
    end) || raise "no walkable cell found near #{x},#{y}"
  end

  defp apply_fury(id) do
    :ok =
      StatusStorage.apply_status(:player, id, :sc_explosionspirits,
        val1: 5,
        caster_id: id,
        duration: 180_000
      )
  end

  defp arm_root_wait(id, level) do
    :ok =
      StatusStorage.apply_status(:player, id, :sc_bladestop_wait,
        val1: level,
        caster_id: id,
        duration: 5_000
      )
  end

  # Establishes a Root pair by arming the Monk fixture at `root_level` and letting
  # a live mob's real swing claim it, so the Monk holds `root_level` and the mob
  # holds the monster level (5). Returns the Monk fixture and the caught mob.
  defp rooted_pair(monk_id, mob_id, root_level, opts) do
    monk = monk_fixture(monk_id, Keyword.merge([position: {150, 150}], opts))
    arm_root_wait(monk_id, root_level)
    mob = spawn_target_mob(mob_id, {151, 150}, hp: 200_000)

    assert :intercepted = Combat.execute_mob_attack(mob.mob_state, monk_id)
    assert Root.rooted?(:player, monk_id)

    {monk, mob}
  end

  defp mob_attack(distance, mob_id) do
    %{
      attacker: {:mob, mob_id},
      target: {:player, 0},
      attacker_boss?: false,
      attacker_root_level: 5,
      distance: distance
    }
  end

  defp future, do: System.monotonic_time(:millisecond) + 600_000
end

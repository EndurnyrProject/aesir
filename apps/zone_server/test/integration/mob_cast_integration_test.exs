defmodule Aesir.ZoneServer.Integration.MobCastIntegrationTest do
  @moduledoc """
  End-to-end coverage that mob-cast rows read from `MobSkill.Db` resolve into
  real effects through the converged dispatch path: `MobSkill.Executor` ->
  `Skill.Catalog` -> the same `Skill.Active` modules a player cast runs.

  Every scenario drives a real row against a real `Executor.execute/2` call,
  a real `PlayerSession`/`MobSession`, and asserts the observable outcome
  (damage packets, HP, status storage, spatial position) rather than
  stubbing the mechanic under test - a catalog or convergence regression that
  silently degrades a row back to a stub, or reintroduces archetype-era
  behavior, fails here.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.ParamChange
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.MobSkill.Db
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcEarthquake
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "prontera"

  # Wounded Morocc: carries both a level 5 `SA_DISPELL` row and a level 5
  # `SA_LANDPROTECTOR` row, plus a level 10 `MG_FIREBOLT` row. Level 5 makes
  # the skill's `50 + 10*lv`% roll a certainty, so the assertions do not
  # depend on randomness.
  @mob_id 3235

  # Tengu: carries `NPC_STUNATTACK` rows, weapon-class hit + status rider.
  @stun_mob_id 1_405

  # Corrupted Soul: carries `NPC_EARTHQUAKE` (self-targeted ground shockwave).
  @earthquake_mob_id 2_475

  # Egnigem Cenia: carries a level 5 `HT_SHOCKWAVE` row targeting `around2`.
  @shockwave_mob_id 2_952

  # Evil Nymph: carries an `AL_HEAL` row targeting `friend`.
  @heal_mob_id 1_416

  # Nydhoggur Memory: carries an `NPC_SUMMONSLAVE` row summoning a single
  # Scorpion (mob id 2143, `condition.val1`).
  @summon_mob_id 2_142
  @summon_slave_id 2_143

  # Wind Ghost: carries `WZ_JUPITEL` rows, which are castable by mobs.
  @jupitel_mob_id 1_450

  # Nidhoggr's Shadow carries level 11 WZ_METEOR; Dark Shadow carries level 21
  # WZ_VERMILION. Both exceed the player skill definitions' level 10 maximum.
  @meteor_mob_id 2_110
  @vermilion_mob_id 2_100

  # Gloom Under Night carries level 5 HT_FREEZINGTRAP around-self rows.
  @freezing_trap_mob_id 2_431

  # Kavach Icarus carries BA_MUSICALSTRIKE; Atroce Slave carries BA_FROSTJOKER.
  @musical_strike_mob_id 2_226
  @frost_joker_mob_id 2_437

  # These mobs carry the status rows exercised by the caster-generic sweep.
  @provoke_mob_id 1_057
  @endure_mob_id 1_060
  @sight_mob_id 1_129
  @hiding_mob_id 1_056
  @auto_counter_mob_id 2_017
  @lex_mob_id 1_637
  @frost_nova_mob_id 1_639

  setup :set_mimic_private
  setup :verify_on_exit!

  defp row!(mob_id, skill_name, opts \\ []) do
    level = Keyword.get(opts, :level)
    target = Keyword.get(opts, :target)

    row =
      Enum.find(Db.rows_for(mob_id), fn row ->
        row.skill == skill_name and
          (is_nil(level) or row.level == level) and
          (is_nil(target) or row.target == target)
      end)

    assert row != nil,
           "mob #{mob_id} must still ship a #{skill_name} row (this test's fixture)"

    row
  end

  defp await_map_coordinator(map_name, attempts \\ 40)

  defp await_map_coordinator(_map_name, 0), do: {:error, :map_coordinator_not_ready}

  defp await_map_coordinator(map_name, attempts) do
    case Registry.lookup(Aesir.ZoneServer.MapRegistry, map_name) do
      [_ | _] ->
        :ok

      [] ->
        Process.sleep(25)
        await_map_coordinator(map_name, attempts - 1)
    end
  end

  defp caster_targeting(char_id) do
    mob = spawn_test_mob(@map, {150, 150}, mob_id: @mob_id)
    %{get_mob_state(mob.pid) | target_ref: {:player, char_id}}
  end

  defp complete_mob_cast(mob, row, target_id) do
    :sys.replace_state(mob.pid, fn state ->
      state
      |> MobState.set_target(target_id)
      |> MobState.set_casting(%{row: row, complete_at: 0, timer_ref: nil})
    end)

    send(mob.pid, {:casting, :complete})
  end

  describe "caster-generic status rows" do
    test "a mob casts Provoke against a player" do
      player =
        start_player_session(id: 9_821, name: "Provoked", position: {151, 150}, map_name: @map)

      char_id = player.character.id
      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

      mob = spawn_test_mob(@map, {150, 150}, mob_id: @provoke_mob_id)
      row = row!(@provoke_mob_id, "SM_PROVOKE", level: 10, target: :target)

      complete_mob_cast(mob, row, char_id)

      assert_eventually(fn -> StatusStorage.has_status?(:player, char_id, :sc_provoke) end, 2_000)
    end

    test "mobs self-cast Endure, Sight, Hiding, and Auto Counter while targeting a player" do
      player =
        start_player_session(id: 9_822, name: "Targeted", position: {151, 150}, map_name: @map)

      char_id = player.character.id

      for {mob_id, skill, status} <- [
            {@endure_mob_id, "SM_ENDURE", :sc_endure},
            {@sight_mob_id, "MG_SIGHT", :sc_sight},
            {@hiding_mob_id, "TF_HIDING", :sc_hiding},
            {@auto_counter_mob_id, "KN_AUTOCOUNTER", :sc_auto_counter}
          ] do
        mob = spawn_test_mob(@map, {150, 150}, mob_id: mob_id)
        row = row!(mob_id, skill, target: :self)
        caster_id = get_mob_state(mob.pid).instance_id
        on_exit(fn -> StatusStorage.clear_unit_statuses(:mob, caster_id) end)

        complete_mob_cast(mob, row, char_id)

        assert_eventually(fn -> StatusStorage.has_status?(:mob, caster_id, status) end, 1_000)
      end
    end

    test "a mob casts Lex Aeterna and delayed Lex Divina against a player" do
      player =
        start_player_session(id: 9_823, name: "Lexed", position: {151, 150}, map_name: @map)

      char_id = player.character.id
      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

      for {skill, status, timeout} <- [
            {"PR_LEXAETERNA", :sc_aeterna, 1_000},
            {"PR_LEXDIVINA", :sc_silence, 2_000}
          ] do
        mob = spawn_test_mob(@map, {150, 150}, mob_id: @lex_mob_id)
        row = row!(@lex_mob_id, skill, target: :target)

        complete_mob_cast(mob, row, char_id)

        assert_eventually(fn -> StatusStorage.has_status?(:player, char_id, status) end, timeout)
      end
    end

    test "a mob casts Frost Nova and freezes a nearby player" do
      player =
        start_player_session(
          id: 9_824,
          name: "Frosted",
          position: {151, 150},
          map_name: @map,
          vit: 0,
          luk: 0
        )

      char_id = player.character.id
      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

      mob = spawn_test_mob(@map, {150, 150}, mob_id: @frost_nova_mob_id)
      row = row!(@frost_nova_mob_id, "WZ_FROSTNOVA", target: :self)

      Mimic.copy(Resistance)
      stub(Resistance, :roll_success, fn _success_rate -> true end)
      Mimic.allow(Resistance, self(), mob.pid)

      complete_mob_cast(mob, row, char_id)

      assert_eventually(fn -> StatusStorage.has_status?(:player, char_id, :sc_freeze) end, 1_000)
    end
  end

  describe "SA_DISPELL rows" do
    test "a mob dispel strips the player's buffs and debuffs, sparing no_dispel statuses" do
      player = start_player_session(id: 9_801, name: "Dispelled", base_level: 50)
      char_id = player.character.id

      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

      # Spawning the caster takes long enough under load for a Poison or
      # Bleeding tick to land, and their damage removes SC_HIDING (`on_damage`)
      # before the dispel ever runs. Have the caster ready first, then apply the
      # statuses and dispel back to back.
      caster = caster_targeting(char_id)

      :ok =
        StatusInterpreter.apply_status(:player, char_id, :sc_blessing,
          val1: 10,
          duration: 1_800_000
        )

      :ok = StatusInterpreter.apply_status(:player, char_id, :sc_poison, duration: 1_800_000)
      :ok = StatusInterpreter.apply_status(:player, char_id, :sc_bleeding, duration: 1_800_000)
      :ok = StatusInterpreter.apply_status(:player, char_id, :sc_hiding, duration: 1_800_000)

      assert :ok = Executor.execute(caster, row!(@mob_id, "SA_DISPELL", level: 5))

      refute StatusStorage.has_status?(:player, char_id, :sc_blessing)

      # Debuffs go too. rAthena's Dispell (src/map/skills/mage/dispell.cpp:36-72)
      # iterates the whole status_db and ends everything not flagged SCF_NODISPELL:
      # there is no buff/debuff distinction. Poison and Bleeding are NOT flagged
      # NoDispell in db/re/status.yml, so a mob dispel cures them - it is not a
      # bug to "fix" back into a buff-only strip.
      refute StatusStorage.has_status?(:player, char_id, :sc_poison)
      refute StatusStorage.has_status?(:player, char_id, :sc_bleeding)

      # SC_HIDING is NoDispell in db/re/status.yml.
      assert StatusStorage.has_status?(:player, char_id, :sc_hiding)
    end

    test "a mob dispel never consults the PvP gate" do
      player = start_player_session(id: 9_802, name: "PveOnly", base_level: 50)
      char_id = player.character.id

      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

      :ok =
        StatusInterpreter.apply_status(:player, char_id, :sc_blessing,
          val1: 10,
          duration: 1_800_000
        )

      # Mob -> player is PvE: the attacker is not a player, so the cast has no
      # business in Targeting.validate_enemy's PvP branch and must not reach it.
      # The gate exemption is structural - keep it that way.
      reject(&Targeting.validate_enemy/2)

      assert :ok =
               Executor.execute(caster_targeting(char_id), row!(@mob_id, "SA_DISPELL", level: 5))

      refute StatusStorage.has_status?(:player, char_id, :sc_blessing)
    end
  end

  describe "wizard ground rows above player max level" do
    test "Meteor Storm and Lord of Vermilion cast without raising and preserve row level" do
      target = spawn_test_mob(@map, {170, 170}, mob_id: @stun_mob_id)

      for {mob_id, skill_name, skill_atom, level} <- [
            {@meteor_mob_id, "WZ_METEOR", :wz_meteor, 11},
            {@vermilion_mob_id, "WZ_VERMILION", :wz_vermilion, 21}
          ] do
        mob = spawn_test_mob(@map, {169, 170}, mob_id: mob_id)
        caster = %{get_mob_state(mob.pid) | target_ref: {:mob, target.unit_id}}

        assert :ok = Executor.execute(caster, row!(mob_id, skill_name, level: level))

        assert %Group{level: ^level} =
                 group =
                 Enum.find(
                   Storage.all(),
                   &(&1.skill_name == skill_atom and &1.caster_id == caster.instance_id)
                 )

        on_exit(fn -> Storage.delete(group.group_id) end)
      end
    end
  end

  describe "HT_SHOCKWAVE rows" do
    test "a mob shockwave trap drains player SP without HP damage" do
      player =
        start_player_session(
          id: 9_807,
          name: "Shockwaved",
          map_name: @map,
          position: {150, 150},
          hp: 1_000,
          max_hp: 1_000,
          sp: 1_000,
          max_sp: 1_000
        )

      char_id = player.character.id
      before = get_player_state(player.pid)
      hp = before.stats.current_state.hp
      sp = before.stats.current_state.sp
      max_sp = before.stats.derived_stats.max_sp
      expected_sp = sp - div(max_sp * 80, 100)
      sp_param = StatusParams.sp()

      flush_packets()

      assert :ok =
               Executor.execute(
                 caster_targeting(char_id),
                 row!(@shockwave_mob_id, "HT_SHOCKWAVE", level: 5)
               )

      assert %Group{skill_name: :ht_shockwave} =
               group = Enum.find(Storage.all(), &(&1.skill_name == :ht_shockwave))

      on_exit(fn -> Storage.delete(group.group_id) end)
      assert :ok = Manager.trigger(group.group_id, {:player, char_id}, :on_touch)

      assert_receive {:packet_sent, %ParamChange{var_id: ^sp_param, value: ^expected_sp}, _},
                     1_000

      state = get_player_state(player.pid)
      assert state.stats.current_state.sp == expected_sp
      assert state.stats.current_state.hp == hp
    end
  end

  describe "SA_LANDPROTECTOR rows" do
    test "a mob land protector row places a real LP field cast by the mob" do
      player = start_player_session(id: 9_803, name: "Protected", base_level: 50)
      char_id = player.character.id

      assert :ok =
               Executor.execute(
                 caster_targeting(char_id),
                 row!(@mob_id, "SA_LANDPROTECTOR", level: 5)
               )

      assert %Group{} = group = Enum.find(Storage.all(), &(&1.skill_name == :sa_landprotector))
      assert group.caster_type == :mob
      assert group.level == 5
      assert Group.land_protector?(group)
      assert group.cells != []

      on_exit(fn -> Storage.delete(group.group_id) end)
    end
  end

  describe "MG_FIREBOLT formula parity + MDEF" do
    test "mob-cast magic damage matches the player formula and drops against higher MDEF" do
      player =
        start_player_session(
          id: 9_810,
          name: "Bolted",
          base_level: 50,
          hp: 20_000,
          max_hp: 20_000
        )

      char_id = player.character.id

      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

      caster = caster_targeting(char_id)
      caster = put_in(caster.mob_data.matk, 500)
      row = row!(@mob_id, "MG_FIREBOLT", level: 10)

      attacker = MobState.to_combatant(caster)
      target = PlayerState.to_combatant(get_player_state(player.pid))

      {:ok, %{damage: per_hit}} =
        MagicDamageCalculator.calculate_magic_damage(attacker, target,
          element: :fire,
          skill_ratio: 100,
          skill_id: row.skill_id
        )

      expected_damage = per_hit * row.level

      flush_packets()
      assert :ok = Executor.execute(caster, row)

      assert_packet_sent_with(SkillDamage, fn packet ->
        assert packet.skill_id == row.skill_id
        assert packet.target_id == char_id
        assert packet.damage == expected_damage
      end)

      assert :ok =
               StatusInterpreter.apply_status(:player, char_id, :sc_endure,
                 val1: 80,
                 val4: 1,
                 duration: 1_800_000
               )

      stats = PlayerSession.recalculate_stats(player.pid)
      assert stats.combat_stats.mdef == 80

      flush_packets()
      assert :ok = Executor.execute(caster, row)

      assert_packet_sent_with(SkillDamage, fn packet ->
        assert packet.damage < expected_damage
      end)
    end
  end

  describe "NPC_STUNATTACK on-connect status" do
    test "a forced-high flee target takes no damage and gets no sc_stun" do
      player = start_player_session(id: 9_811, name: "Evasive", base_level: 1, agi: 500, luk: 0)
      char_id = player.character.id

      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

      mob = spawn_test_mob(@map, {150, 150}, mob_id: @stun_mob_id)
      caster = %{get_mob_state(mob.pid) | target_ref: {:player, char_id}}

      flush_packets()
      assert :ok = Executor.execute(caster, row!(@stun_mob_id, "NPC_STUNATTACK"))

      refute_packet_sent(SkillDamage)
      refute StatusStorage.has_status?(:player, char_id, :sc_stun)
    end

    test "a normal-flee target takes damage and sc_stun applies on connect" do
      player =
        start_player_session(id: 9_812, name: "Rooted", base_level: 1, agi: 1, luk: 0, vit: 0)

      char_id = player.character.id

      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

      mob = spawn_test_mob(@map, {150, 150}, mob_id: @stun_mob_id, dex: 300)
      caster = %{get_mob_state(mob.pid) | target_ref: {:player, char_id}}

      flush_packets()
      assert :ok = Executor.execute(caster, row!(@stun_mob_id, "NPC_STUNATTACK"))

      assert_packet_sent(SkillDamage)
      assert StatusStorage.has_status?(:player, char_id, :sc_stun)
    end
  end

  describe "NPC_EARTHQUAKE ground cast" do
    test "damages a player standing on the footprint but spares a mob on the same footprint" do
      caster_mob = spawn_test_mob(@map, {160, 160}, mob_id: @earthquake_mob_id)
      caster = get_mob_state(caster_mob.pid)

      victim =
        start_player_session(id: 9_813, name: "Shaken", position: {161, 160}, map_name: @map)

      bystander_mob =
        spawn_test_mob(@map, {160, 161}, mob_id: @earthquake_mob_id, hp: 500, max_hp: 500)

      assert :ok = Executor.execute(caster, row!(@earthquake_mob_id, "NPC_EARTHQUAKE"))

      assert %Group{} = group = Enum.find(Storage.all(), &(&1.skill_name == :npc_earthquake))
      on_exit(fn -> Storage.delete(group.group_id) end)

      assert {:ok, _group} = NpcEarthquake.on_interval(group, System.system_time(:millisecond))

      assert get_player_state(victim.pid).stats.current_state.hp < 100
      assert get_mob_state(bystander_mob.pid).hp == 500
    end
  end

  describe "AL_HEAL friend row" do
    test "heals a damaged friendly mob through the shared heal path" do
      caster_mob = spawn_test_mob(@map, {180, 180}, mob_id: @heal_mob_id)
      friend_mob = spawn_test_mob(@map, {181, 180}, mob_id: @heal_mob_id, hp: 50, max_hp: 200)

      caster = get_mob_state(caster_mob.pid)
      row = row!(@heal_mob_id, "AL_HEAL", target: :friend)

      assert :ok = Executor.execute(caster, row)

      assert get_mob_state(friend_mob.pid).hp > 50
    end
  end

  describe "NPC_SUMMONSLAVE" do
    test "a mob-cast summon row threads master_id to the spawned slave" do
      # NPC_SUMMONSLAVE resolves through the real, permanently-running
      # "prontera" Map.Coordinator (boot's MapManager starts it
      # asynchronously), so a test running early relative to that boot must
      # wait for its registration instead of racing it.
      assert :ok = await_map_coordinator(@map)

      mob = spawn_test_mob(@map, {190, 190}, mob_id: @summon_mob_id)
      caster = get_mob_state(mob.pid)

      assert :ok = Executor.execute(caster, row!(@summon_mob_id, "NPC_SUMMONSLAVE"))

      slave =
        :mob
        |> UnitRegistry.list_units_by_type()
        |> Enum.find_value(fn id ->
          case UnitRegistry.get_unit(:mob, id) do
            {:ok, {_module, %MobState{master_id: master_id} = state, _pid}}
            when master_id == caster.instance_id ->
              state

            _ ->
              nil
          end
        end)

      assert %MobState{} = slave
      assert slave.mob_id == @summon_slave_id
    end
  end

  describe "HT_SKIDTRAP around2 effect" do
    test "Executor mob cast moves and stops a real PlayerSession from the same cell" do
      player =
        start_player_session(id: 9_815, name: "Skidded", position: {150, 150}, map_name: @map)

      mob = spawn_test_mob(@map, {150, 150}, mob_id: 1_214)
      row = row!(1_214, "HT_SKIDTRAP", level: 5, target: :around2)
      mob_state = get_mob_state(mob.pid)

      assert :ok = Executor.execute(mob_state, row)

      assert [%Group{center: {150, 150}, origin: {150, 150}} = group] =
               Storage.get_groups_by_skill_and_caster(:ht_skidtrap, :mob, mob.unit_id)

      assert :ok = Manager.trigger(group.group_id, {:player, player.character.id}, :on_touch)

      assert eventually(fn ->
               %{game_state: %{x: x, y: y}} = PlayerSession.get_state(player.pid)
               {x, y} == {160, 150}
             end)

      assert StatusStorage.has_status?(:player, player.character.id, :sc_stop)

      assert %Group{visibility: :party_only, state: %{trap: %{phase: :used}}} =
               Storage.get(group.group_id)
    end
  end

  describe "HT_FREEZINGTRAP ground lifecycle" do
    test "MobSession places it and PlayerSession movement triggers Water splash and Freeze" do
      activator =
        start_player_session(
          id: 9_815,
          name: "Activator",
          position: {150, 150},
          map_name: @map,
          hp: 2_000,
          max_hp: 2_000,
          vit: 0,
          luk: 0
        )

      connected =
        start_player_session(
          id: 9_816,
          name: "Connected",
          position: {150, 151},
          map_name: @map,
          hp: 2_000,
          max_hp: 2_000,
          vit: 0,
          luk: 0
        )

      outside =
        start_player_session(
          id: 9_817,
          name: "Outside",
          position: {150, 152},
          map_name: @map,
          hp: 2_000,
          max_hp: 2_000,
          vit: 0,
          luk: 0
        )

      ids = Enum.map([activator, connected, outside], & &1.character.id)
      on_exit(fn -> Enum.each(ids, &StatusStorage.clear_unit_statuses(:player, &1)) end)

      mob = spawn_test_mob(@map, {155, 150}, mob_id: @freezing_trap_mob_id, dex: 300)
      row = %{row!(@freezing_trap_mob_id, "HT_FREEZINGTRAP", level: 5) | target: :around5}

      :sys.replace_state(mob.pid, fn state ->
        state
        |> MobState.set_target(activator.character.id)
        |> MobState.set_casting(%{row: row, complete_at: 0, timer_ref: nil})
      end)

      send(mob.pid, {:casting, :complete})

      assert eventually(fn ->
               Enum.any?(Storage.all(), &(&1.skill_name == :ht_freezingtrap))
             end)

      group = Enum.find(Storage.all(), &(&1.skill_name == :ht_freezingtrap))
      assert group.center == {150, 150}
      assert group.caster_type == :mob

      simulate_incoming_message(activator.pid, %MoveRequest{dest_x: 149, dest_y: 150})

      assert eventually(fn ->
               match?(
                 {:ok, {149, 150, @map}},
                 SpatialIndex.get_unit_position(:player, activator.character.id)
               )
             end)

      simulate_incoming_message(activator.pid, %MoveRequest{dest_x: 151, dest_y: 150})

      assert eventually(fn -> Storage.get(group.group_id) == nil end)
      assert get_player_state(activator.pid).stats.current_state.hp < 2_000
      assert get_player_state(connected.pid).stats.current_state.hp < 2_000
      assert get_player_state(outside.pid).stats.current_state.hp == 2_000

      assert StatusStorage.has_status?(:player, activator.character.id, :sc_freeze)
      assert StatusStorage.has_status?(:player, connected.character.id, :sc_freeze)
      refute StatusStorage.has_status?(:player, outside.character.id, :sc_freeze)
    end
  end

  describe "retained Bard rows" do
    test "BA_MUSICALSTRIKE resolves through Executor as one real damage event" do
      Mimic.copy(HitCalculations)
      stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

      victim =
        start_player_session(
          id: 9_818,
          name: "Strummed",
          position: {150, 150},
          map_name: @map,
          hp: 5_000,
          max_hp: 5_000
        )

      caster = caster_targeting(victim.character.id)
      flush_packets()

      assert :ok =
               Executor.execute(
                 caster,
                 row!(@musical_strike_mob_id, "BA_MUSICALSTRIKE", level: 5)
               )

      victim_id = victim.character.id
      assert_receive {:packet_sent, %SkillDamage{skill_id: 316, target_id: ^victim_id}, _}, 1_000
      assert get_player_state(victim.pid).stats.current_state.hp < 5_000
    end

    test "BA_FROSTJOKER schedules on a real MobSession and freezes after three seconds" do
      victim =
        start_player_session(
          id: 9_819,
          name: "Frozen",
          position: {151, 150},
          map_name: @map,
          hp: 100_000,
          max_hp: 100_000,
          vit: 0,
          luk: 0
        )

      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, victim.character.id) end)

      mob = spawn_test_mob(@map, {150, 150}, mob_id: @frost_joker_mob_id)
      row = row!(@frost_joker_mob_id, "BA_FROSTJOKER", level: 3, target: :self)

      Mimic.copy(Resistance)
      stub(Resistance, :roll_success, fn _success_rate -> true end)
      Mimic.allow(Resistance, self(), mob.pid)

      :sys.replace_state(mob.pid, fn state ->
        MobState.set_casting(state, %{row: row, complete_at: 0, timer_ref: nil})
      end)

      send(mob.pid, {:casting, :complete})

      assert_eventually(fn -> get_mob_state(mob.pid).casting == nil end, 1_000)
      refute StatusStorage.has_status?(:player, victim.character.id, :sc_freeze)

      assert_eventually(
        fn -> StatusStorage.has_status?(:player, victim.character.id, :sc_freeze) end,
        4_000
      )
    end

    test "BA_FROSTJOKER real MobSession timer is cancelled by caster death" do
      victim =
        start_player_session(
          id: 9_820,
          name: "Unfrozen",
          position: {151, 150},
          map_name: @map,
          vit: 0,
          luk: 0
        )

      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, victim.character.id) end)

      mob = spawn_test_mob(@map, {150, 150}, mob_id: @frost_joker_mob_id, hp: 1, max_hp: 1)
      row = row!(@frost_joker_mob_id, "BA_FROSTJOKER", level: 3, target: :self)

      Mimic.copy(Resistance)
      stub(Resistance, :roll_success, fn _success_rate -> true end)
      Mimic.allow(Resistance, self(), mob.pid)

      :sys.replace_state(mob.pid, fn state ->
        MobState.set_casting(state, %{row: row, complete_at: 0, timer_ref: nil})
      end)

      send(mob.pid, {:casting, :complete})

      assert_eventually(fn -> get_mob_state(mob.pid).casting == nil end, 1_000)
      refute StatusStorage.has_status?(:player, victim.character.id, :sc_freeze)

      MobSession.apply_damage(mob.pid, 1)

      assert_eventually(fn -> get_mob_state(mob.pid).deferred_epoch == 1 end, 1_000)

      refute_eventually(
        fn -> StatusStorage.has_status?(:player, victim.character.id, :sc_freeze) end,
        3_200
      )
    end
  end

  describe "WZ_JUPITEL deferred effect" do
    test "a mob-cast row's deferred hit lands via MobSession's deferred handler" do
      assert Castability.check_by_id(84, :mob) == :ok,
             "WZ_JUPITEL (84) must be castable by mobs for this scenario to use the real path"

      victim =
        start_player_session(id: 9_814, name: "Struck", position: {153, 150}, map_name: @map)

      char_id = victim.character.id

      {:ok, orig_position} = SpatialIndex.get_unit_position(:player, char_id)

      mob = spawn_test_mob(@map, {150, 150}, mob_id: @jupitel_mob_id)
      row = row!(@jupitel_mob_id, "WZ_JUPITEL")

      # Drives the row through the real cast/complete/defer cycle on the mob's
      # own process so `Skill.defer/3`'s `Process.send_after(self(), ...)`
      # arms on the mob's pid, exactly like production `{:ai, :tick}` casting -
      # the same MobSession that later receives and dispatches the deferred
      # `{:skill, {:deferred, WzJupitel, _}}` message.
      :sys.replace_state(mob.pid, fn state ->
        state
        |> MobState.set_target(char_id)
        |> MobState.set_casting(%{row: row, complete_at: 0, timer_ref: nil})
      end)

      send(mob.pid, {:casting, :complete})

      Process.sleep(500)

      {:ok, new_position} = SpatialIndex.get_unit_position(:player, char_id)
      assert new_position != orig_position
    end
  end
end

defmodule Aesir.ZoneServer.Integration.HomunculusCommandsIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.HomunculusAttackCommand
  alias Aesir.Net.HomunculusCastSkillCommand
  alias Aesir.Net.HomunculusDeleteCommand
  alias Aesir.Net.HomunculusFeedCommand
  alias Aesir.Net.HomunculusFollowCommand
  alias Aesir.Net.HomunculusInspectCommand
  alias Aesir.Net.HomunculusLearnSkillCommand
  alias Aesir.Net.HomunculusMoveCommand
  alias Aesir.Net.HomunculusPrivateState
  alias Aesir.Net.HomunculusRenameCommand
  alias Aesir.Net.HomunculusReplaceAiCommand
  alias Aesir.Net.HomunculusRequest
  alias Aesir.Net.HomunculusRestCommand
  alias Aesir.Net.HomunculusResult
  alias Aesir.Net.HomunculusStandbyCommand
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MoveStop
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @pet_food 537

  test "routes inspect and all active action arms through the real packet/session flow" do
    inspect = start_owner()
    assert_success(inspect, 1, {:inspect, %HomunculusInspectCommand{}})

    move = start_owner()
    moved = assert_success(move, 2, {:move, %HomunculusMoveCommand{x: 151, y: 150}})
    assert moved.activity == :HOMUNCULUS_ACTIVITY_MOVING

    follow = start_owner(position: {155, 150})
    before_follow = PlayerSession.get_state(follow.pid).homunculus
    followed = assert_success(follow, 3, {:follow, %HomunculusFollowCommand{}})
    assert followed.activity == :HOMUNCULUS_ACTIVITY_MOVING

    assert_eventually(fn ->
      current = PlayerSession.get_state(follow.pid).homunculus
      {current.x, current.y} != {before_follow.x, before_follow.y}
    end)

    standby = start_owner()
    stood = assert_success(standby, 4, {:standby, %HomunculusStandbyCommand{}})
    assert stood.activity == :HOMUNCULUS_ACTIVITY_STANDBY

    attack = start_owner()
    mob = start_mob_session(map_name: "prontera", position: {151, 150})

    attacked =
      assert_success(attack, 5, {
        :attack,
        %HomunculusAttackCommand{target_id: mob.unit_id}
      })

    assert attacked.current_target_id == 0

    assert_receive {:packet_sent, %DamageDealt{src_id: src_id, target_id: target_id}, _},
                   1_000

    assert src_id == attacked.world_gid
    assert target_id == mob.unit_id
    unchanged = inspect_state(attack, 8)

    assert_error(
      attack,
      7,
      {:attack, %HomunculusAttackCommand{target_id: mob.unit_id}},
      :HOMUNCULUS_ERROR_BUSY,
      unchanged
    )

    cast = start_owner()

    casted =
      assert_success(cast, 6, {
        :cast_skill,
        %HomunculusCastSkillCommand{skill_id: 8002, level: 1, target: {:self, true}}
      })

    assert casted.sp < casted.max_sp
  end

  test "routes feed, rename, AI replacement, and learning as durable commands" do
    feed = start_owner(food?: true)
    before_feed = inspect_state(feed, 10)
    fed = assert_success(feed, 11, {:feed, %HomunculusFeedCommand{}})
    assert fed.hunger == before_feed.hunger + 10
    assert Repo.get_by!(Homunculus, character_id: feed.character.id).hunger == fed.hunger
    assert Repo.get_by(InventoryItem, char_id: feed.character.id, nameid: @pet_food) == nil

    rename = start_owner()
    renamed = assert_success(rename, 12, {:rename, %HomunculusRenameCommand{name: "  Éir  "}})
    assert renamed.name == "Éir"
    refute renamed.rename_eligible

    persisted_rename = Repo.get_by!(Homunculus, character_id: rename.character.id)
    assert persisted_rename.name == "Éir"
    refute persisted_rename.rename_available

    assert_error(
      rename,
      13,
      {:rename, %HomunculusRenameCommand{name: "Again"}},
      :HOMUNCULUS_ERROR_RENAME_NOT_ALLOWED,
      renamed
    )

    ai = start_owner()
    state = inspect_state(ai, 14)
    replacement = %{state.ai_config | stance: :HOMUNCULUS_AI_STANCE_PASSIVE}

    replaced =
      assert_success(ai, 15, {
        :replace_ai,
        %HomunculusReplaceAiCommand{config: replacement}
      })

    assert replaced.ai_config.stance == :HOMUNCULUS_AI_STANCE_PASSIVE

    assert Repo.get_by!(Homunculus, character_id: ai.character.id).ai_config["stance"] ==
             "passive"

    for invalid <- [
          %{replacement | skills: []},
          %{replacement | skills: [hd(replacement.skills), hd(replacement.skills)]},
          %{replacement | skills: [%{hd(replacement.skills) | skill_id: 99_999}]},
          %{replacement | skills: [nil | replacement.skills]}
        ] do
      assert_error(
        ai,
        System.unique_integer([:positive]),
        {:replace_ai, %HomunculusReplaceAiCommand{config: invalid}},
        :HOMUNCULUS_ERROR_INVALID_AI_CONFIG,
        replaced
      )
    end

    learner = start_owner(learned_skills: %{"8001" => 3})

    learned =
      assert_success(learner, 17, {:learn_skill, %HomunculusLearnSkillCommand{skill_id: 8002}})

    assert Enum.find(learned.skills, &(&1.skill_id == 8002)).level == 1
    assert Enum.any?(learned.ai_config.skills, &(&1.skill_id == 8002))

    persisted = Repo.get_by!(Homunculus, character_id: learner.character.id)
    assert persisted.learned_skills["8002"] == 1
    assert persisted.skill_points == 0
    assert Enum.any?(persisted.ai_config["skills"], &(&1["skill_id"] == 8002))
  end

  test "routes rest and confirmed deletion with authoritative post-state" do
    rest = start_owner()
    owner_sp = get_player_state(rest.pid).stats.current_state.sp
    rested = assert_success(rest, 20, {:rest, %HomunculusRestCommand{}})
    assert rested.lifecycle == :HOMUNCULUS_LIFECYCLE_RESTED
    assert get_player_state(rest.pid).stats.current_state.sp == owner_sp - 50
    assert get_player_state(rest.pid).skill_cooldowns[244] > System.monotonic_time(:millisecond)
    assert Repo.get_by!(Homunculus, character_id: rest.character.id).lifecycle == "rested"
    refute_receive {:packet_sent, %HomunculusPrivateState{}, _}, 50

    deletion = start_owner()
    before = inspect_state(deletion, 21)

    assert_error(
      deletion,
      22,
      {:delete, %HomunculusDeleteCommand{confirmed: false}},
      :HOMUNCULUS_ERROR_CONFIRMATION_REQUIRED,
      before
    )

    request(deletion, 23, {:delete, %HomunculusDeleteCommand{confirmed: true}})

    assert_receive {:packet_sent, %HomunculusResult{request_id: 23, success: true, state: nil},
                    _},
                   1_000

    refute_receive {:packet_sent, %HomunculusResult{request_id: 23}, _}, 50
    assert Repo.get_by(Homunculus, character_id: deletion.character.id) == nil
    assert_runtime_cleared(deletion.pid)
  end

  test "rest runs every ordinary owner session gate without mutation" do
    cases = [
      {:insufficient_sp, fn state -> put_in(state.game_state.stats.current_state.sp, 49) end},
      {:on_cooldown,
       fn state ->
         put_in(
           state.game_state.skill_cooldowns[244],
           System.monotonic_time(:millisecond) + 60_000
         )
       end},
      {:pending_interaction,
       fn state -> %{state | interaction_lock: {self(), make_ref(), 1}} end},
      {:active_cast,
       fn state -> %{state | game_state: %{state.game_state | casting: %{token: make_ref()}}} end},
      {:pending_deferred, fn state -> %{state | deferred_skill_result: %{pending: true}} end},
      {:busy, fn state -> %{state | game_state: %{state.game_state | action_state: :sitting}} end}
    ]

    Enum.each(cases, fn {name, mutate} ->
      owner = start_owner()
      before_character = Repo.get!(Character, owner.character.id)
      before_row = Repo.get_by!(Homunculus, character_id: owner.character.id)
      before_inventory = InventoryPersistence.load_inventory(owner.character.id)
      :sys.replace_state(owner.pid, mutate)
      before_session = PlayerSession.get_state(owner.pid)
      expected = inspect_state(owner, System.unique_integer([:positive]))

      assert_error(
        owner,
        System.unique_integer([:positive]),
        {:rest, %HomunculusRestCommand{}},
        command_gate_error(name),
        expected
      )

      assert PlayerSession.get_state(owner.pid) == before_session
      assert Repo.get!(Character, owner.character.id) == before_character
      assert Repo.get_by!(Homunculus, character_id: owner.character.id) == before_row
      assert InventoryPersistence.load_inventory(owner.character.id) == before_inventory
      refute_receive {:packet_sent, %HomunculusPrivateState{}, _}, 25
    end)

    status_owner = start_owner()
    before_session = PlayerSession.get_state(status_owner.pid)
    before_character = Repo.get!(Character, status_owner.character.id)
    before_row = Repo.get_by!(Homunculus, character_id: status_owner.character.id)
    expected = inspect_state(status_owner, System.unique_integer([:positive]))
    :ok = StatusStorage.apply_status(:player, status_owner.character.id, :sc_stun)

    assert_error(
      status_owner,
      System.unique_integer([:positive]),
      {:rest, %HomunculusRestCommand{}},
      :HOMUNCULUS_ERROR_BUSY,
      expected
    )

    assert PlayerSession.get_state(status_owner.pid) == before_session
    assert Repo.get!(Character, status_owner.character.id) == before_character
    assert Repo.get_by!(Homunculus, character_id: status_owner.character.id) == before_row
    :ok = StatusStorage.remove_status(:player, status_owner.character.id, :sc_stun)
  end

  test "failed rest while moving preserves the path, durable state, and client movement" do
    owner = start_owner()

    :sys.replace_state(owner.pid, fn state ->
      game_state = %{
        state.game_state
        | action_state: :moving,
          movement_state: :moving,
          walk_path: [{151, 150}]
      }

      state
      |> Map.put(:game_state, game_state)
      |> put_in(
        [
          Access.key(:game_state),
          Access.key(:stats),
          Access.key(:current_state),
          Access.key(:sp)
        ],
        49
      )
    end)

    before_session = PlayerSession.get_state(owner.pid)
    before_character = Repo.get!(Character, owner.character.id)
    before_row = Repo.get_by!(Homunculus, character_id: owner.character.id)
    before_inventory = InventoryPersistence.load_inventory(owner.character.id)
    expected = inspect_state(owner, 51)

    assert_error(
      owner,
      52,
      {:rest, %HomunculusRestCommand{}},
      :HOMUNCULUS_ERROR_INSUFFICIENT_SP,
      expected
    )

    refute_receive {:packet_sent, %MoveStop{}, _}, 50
    assert PlayerSession.get_state(owner.pid) == before_session
    assert Repo.get!(Character, owner.character.id) == before_character
    assert Repo.get_by!(Homunculus, character_id: owner.character.id) == before_row
    assert InventoryPersistence.load_inventory(owner.character.id) == before_inventory
  end

  test "successful rest resumes an attacking owner's live combat lock" do
    owner = start_owner()
    mob = start_mob_session(map_name: "prontera", position: {151, 150})

    :sys.replace_state(owner.pid, fn state ->
      game_state = %{
        state.game_state
        | action_state: :attacking,
          combat_target_id: mob.unit_id,
          combat_action_type: 7
      }

      %{state | game_state: game_state}
    end)

    rested = assert_success(owner, 53, {:rest, %HomunculusRestCommand{}})
    assert rested.lifecycle == :HOMUNCULUS_LIFECYCLE_RESTED
    refute_receive {:packet_sent, %HomunculusPrivateState{}, _}, 50

    assert_eventually(fn ->
      game_state = get_player_state(owner.pid)

      game_state.combat_target_id == mob.unit_id and
        game_state.action_state in [:attacking, :combat_moving]
    end)
  end

  test "rest rejects an unlearned owner skill and a dead owner without mutation" do
    unlearned = start_owner(owner_learned_skills: %{"238" => 1})
    unlearned_state = inspect_state(unlearned, 25)

    assert_error(
      unlearned,
      26,
      {:rest, %HomunculusRestCommand{}},
      :HOMUNCULUS_ERROR_SKILL_NOT_LEARNED,
      unlearned_state
    )

    dead_owner = start_owner(owner_hp: 0)
    dead_state = inspect_state(dead_owner, 27)

    assert_error(
      dead_owner,
      28,
      {:rest, %HomunculusRestCommand{}},
      :HOMUNCULUS_ERROR_INVALID_LIFECYCLE,
      dead_state
    )
  end

  test "follow succeeds when the production pathfinder returns an already-adjacent path" do
    owner = start_owner()
    state = PlayerSession.get_state(owner.pid)
    homunculus = %{state.homunculus | x: state.game_state.x, y: state.game_state.y - 1}

    :ok =
      Movement.set_position(:homunculus, homunculus.world_gid, homunculus, homunculus.map_name)

    :sys.replace_state(owner.pid, fn current -> %{current | homunculus: homunculus} end)

    followed = assert_success(owner, 29, {:follow, %HomunculusFollowCommand{}})
    assert followed.activity == :HOMUNCULUS_ACTIVITY_IDLE
  end

  test "foreign typed targets are never reinterpreted as mobs" do
    attacker = start_owner()
    foreign = start_owner()
    before = inspect_state(attacker, 46)

    assert_error(
      attacker,
      47,
      {:attack, %HomunculusAttackCommand{target_id: foreign.character.id}},
      :HOMUNCULUS_ERROR_INVALID_TARGET,
      before
    )

    mob = start_mob_session(map_name: "prontera", position: {151, 150})
    foreign_state = get_player_state(foreign.pid)

    :ok =
      UnitRegistry.register_unit(
        :player,
        mob.unit_id,
        foreign_state.__struct__,
        foreign_state,
        foreign.pid
      )

    on_exit(fn -> UnitRegistry.unregister_unit(:player, mob.unit_id) end)

    assert_error(
      attacker,
      48,
      {:attack, %HomunculusAttackCommand{target_id: mob.unit_id}},
      :HOMUNCULUS_ERROR_INVALID_TARGET,
      before
    )
  end

  test "skill rank preflight wins over ambiguous typed target resolution" do
    caster = start_owner(learned_skills: %{"8001" => 3})
    foreign = start_owner()
    collision_id = foreign.character.id
    collision = %{PlayerSession.get_state(caster.pid).homunculus | world_gid: collision_id}

    :ok =
      UnitRegistry.register_unit(
        :homunculus,
        collision_id,
        collision.__struct__,
        collision,
        caster.pid
      )

    on_exit(fn -> UnitRegistry.unregister_unit(:homunculus, collision_id) end)
    before = inspect_state(caster, 54)

    assert_error(
      caster,
      55,
      {:cast_skill,
       %HomunculusCastSkillCommand{
         skill_id: 8002,
         level: 6,
         target: {:target_id, collision_id}
       }},
      :HOMUNCULUS_ERROR_INVALID_SKILL_RANK,
      before
    )

    assert_error(
      caster,
      56,
      {:cast_skill,
       %HomunculusCastSkillCommand{
         skill_id: 8002,
         level: 1,
         target: {:target_id, collision_id}
       }},
      :HOMUNCULUS_ERROR_SKILL_NOT_LEARNED,
      before
    )

    :sys.replace_state(caster.pid, fn state ->
      homunculus = %{state.homunculus | learned_skills: %{8001 => 3, 8002 => 1}}
      %{state | homunculus: homunculus}
    end)

    valid_before = inspect_state(caster, 57)

    assert_error(
      caster,
      58,
      {:cast_skill,
       %HomunculusCastSkillCommand{
         skill_id: 8002,
         level: 1,
         target: {:target_id, collision_id}
       }},
      :HOMUNCULUS_ERROR_INVALID_TARGET,
      valid_before
    )
  end

  test "operationally missing durable state is busy and leaves feed inventory unchanged" do
    owner = start_owner(food?: true)
    before = inspect_state(owner, 49)
    inventory = InventoryPersistence.load_inventory(owner.character.id)
    Repo.delete!(Repo.get_by!(Homunculus, character_id: owner.character.id))

    assert_error(
      owner,
      50,
      {:feed, %HomunculusFeedCommand{}},
      :HOMUNCULUS_ERROR_BUSY,
      before
    )

    assert InventoryPersistence.load_inventory(owner.character.id) == inventory
  end

  test "zero-intimacy feed deletes only after persistence and clears every runtime field" do
    session = start_owner(food?: true, hunger: 100, intimacy_hundredths: 50)
    request(session, 24, {:feed, %HomunculusFeedCommand{}})

    assert_receive {:packet_sent, %HomunculusResult{request_id: 24, success: true, state: nil},
                    _},
                   1_000

    assert Repo.get_by(Homunculus, character_id: session.character.id) == nil
    assert_runtime_cleared(session.pid)
  end

  test "returns stable malformed, absent, position, target, range, item, HP, name, points, and busy errors" do
    absent = start_owner(homunculus?: false)
    request(absent, 30, {:inspect, %HomunculusInspectCommand{}})

    assert_receive {:packet_sent,
                    %HomunculusResult{
                      request_id: 30,
                      success: false,
                      error: :HOMUNCULUS_ERROR_NO_COMPANION,
                      state: nil
                    }, _},
                   1_000

    malformed = start_owner()
    request(malformed, 0, nil)

    assert_receive {:packet_sent,
                    %HomunculusResult{
                      request_id: 0,
                      success: false,
                      error: :HOMUNCULUS_ERROR_MALFORMED_COMMAND,
                      state: malformed_state
                    }, _},
                   1_000

    assert malformed_state.name == "Lif"

    assert_error(
      malformed,
      31,
      {:move, %HomunculusMoveCommand{x: -1, y: -1}},
      :HOMUNCULUS_ERROR_INVALID_POSITION,
      malformed_state
    )

    assert_error(
      malformed,
      32,
      {:attack, %HomunculusAttackCommand{target_id: 4_000_000}},
      :HOMUNCULUS_ERROR_INVALID_TARGET,
      malformed_state
    )

    assert_error(
      malformed,
      45,
      {:attack, %HomunculusAttackCommand{target_id: malformed.character.id}},
      :HOMUNCULUS_ERROR_INVALID_TARGET,
      malformed_state
    )

    far_mob = start_mob_session(map_name: "prontera", position: {160, 160})

    assert_error(
      malformed,
      33,
      {:attack, %HomunculusAttackCommand{target_id: far_mob.unit_id}},
      :HOMUNCULUS_ERROR_OUT_OF_RANGE,
      malformed_state
    )

    assert_error(
      malformed,
      34,
      {:feed, %HomunculusFeedCommand{}},
      :HOMUNCULUS_ERROR_MISSING_ITEM,
      malformed_state
    )

    assert_error(
      malformed,
      35,
      {:rename, %HomunculusRenameCommand{name: ""}},
      :HOMUNCULUS_ERROR_INVALID_NAME,
      malformed_state
    )

    assert_error(
      malformed,
      36,
      {:cast_skill, %HomunculusCastSkillCommand{skill_id: 8002, level: 6, target: {:self, true}}},
      :HOMUNCULUS_ERROR_INVALID_SKILL_RANK,
      malformed_state
    )

    assert_error(
      malformed,
      48,
      {:cast_skill,
       %HomunculusCastSkillCommand{skill_id: 99_999, level: 1, target: {:self, true}}},
      :HOMUNCULUS_ERROR_SKILL_NOT_LEARNED,
      malformed_state
    )

    assert_error(
      malformed,
      43,
      {:cast_skill,
       %HomunculusCastSkillCommand{skill_id: 8002, level: 6, target: {:target_id, 4_000_000}}},
      :HOMUNCULUS_ERROR_INVALID_SKILL_RANK,
      malformed_state
    )

    assert_error(
      malformed,
      44,
      {:cast_skill,
       %HomunculusCastSkillCommand{skill_id: 8002, level: 1, target: {:target_id, 0}}},
      :HOMUNCULUS_ERROR_MALFORMED_COMMAND,
      malformed_state
    )

    insufficient_sp = start_owner(sp: 0)
    insufficient_sp_state = inspect_state(insufficient_sp, 37)

    assert_error(
      insufficient_sp,
      38,
      {:cast_skill, %HomunculusCastSkillCommand{skill_id: 8002, level: 1, target: {:self, true}}},
      :HOMUNCULUS_ERROR_INSUFFICIENT_SP,
      insufficient_sp_state
    )

    cooldown = start_owner(cooldowns: %{"8002" => 60_000})
    cooldown_state = inspect_state(cooldown, 39)

    assert_error(
      cooldown,
      40,
      {:cast_skill, %HomunculusCastSkillCommand{skill_id: 8002, level: 1, target: {:self, true}}},
      :HOMUNCULUS_ERROR_ON_COOLDOWN,
      cooldown_state
    )

    dead = start_owner(lifecycle: "dead", hp: 0)
    dead_state = inspect_state(dead, 41)

    assert_error(
      dead,
      42,
      {:follow, %HomunculusFollowCommand{}},
      :HOMUNCULUS_ERROR_INVALID_LIFECYCLE,
      dead_state
    )

    no_points = start_owner(skill_points: 0)
    no_points_state = inspect_state(no_points, 36)

    assert_error(
      no_points,
      37,
      {:learn_skill, %HomunculusLearnSkillCommand{skill_id: 8002}},
      :HOMUNCULUS_ERROR_INSUFFICIENT_SKILL_POINTS,
      no_points_state
    )

    low_hp = start_owner(hp: 799, max_hp: 1_000)
    low_hp_state = inspect_state(low_hp, 38)

    assert_error(
      low_hp,
      39,
      {:rest, %HomunculusRestCommand{}},
      :HOMUNCULUS_ERROR_HP_GATE,
      low_hp_state
    )

    busy = start_owner()
    assert_success(busy, 40, {:move, %HomunculusMoveCommand{x: 151, y: 150}})
    busy_state = inspect_state(busy, 41)

    assert_error(
      busy,
      42,
      {:cast_skill, %HomunculusCastSkillCommand{skill_id: 8002, level: 1, target: {:self, true}}},
      :HOMUNCULUS_ERROR_BUSY,
      busy_state
    )
  end

  defp assert_runtime_cleared(pid) do
    state = PlayerSession.get_state(pid)
    assert state.homunculus == nil
    assert state.homunculus_runtime == %Runtime{private_dirty: false}
  end

  defp inspect_state(session, request_id) do
    assert_success(session, request_id, {:inspect, %HomunculusInspectCommand{}})
  end

  defp assert_success(session, request_id, command) do
    request(session, request_id, command)

    assert_receive {:packet_sent,
                    %HomunculusResult{
                      request_id: ^request_id,
                      success: true,
                      error: :HOMUNCULUS_ERROR_NONE,
                      state: state
                    }, _},
                   1_000

    refute is_nil(state)
    refute_receive {:packet_sent, %HomunculusResult{request_id: ^request_id}, _}, 25
    state
  end

  defp assert_error(session, request_id, command, error, expected_state) do
    request(session, request_id, command)

    assert_receive {:packet_sent,
                    %HomunculusResult{
                      request_id: ^request_id,
                      success: false,
                      error: ^error,
                      state: state
                    }, _},
                   1_000

    assert stable_state(state) == stable_state(expected_state)
    refute_receive {:packet_sent, %HomunculusResult{request_id: ^request_id}, _}, 25
    state
  end

  defp stable_state(state) do
    %{
      state
      | active_remaining_ms: 0,
        cooldowns: Enum.map(state.cooldowns, &%{&1 | remaining_ms: 0})
    }
  end

  defp request(session, request_id, command) do
    simulate_incoming_message(session.pid, %HomunculusRequest{
      request_id: request_id,
      command: command
    })
  end

  defp start_owner(opts \\ []) do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "homcmd_#{suffix}",
        user_pass: "password",
        email: "homcmd-#{suffix}@example.com"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Cmd#{suffix}",
        class: 5,
        base_level: 50,
        job_level: 50,
        hp: Keyword.get(opts, :owner_hp, 1_000),
        max_hp: 1_000,
        sp: Keyword.get(opts, :owner_sp, 500),
        max_sp: 500,
        learned_skills: Keyword.get(opts, :owner_learned_skills, %{"238" => 1, "244" => 1}),
        last_map: "prontera",
        last_x: 150,
        last_y: 150
      })
      |> Repo.insert!()

    if Keyword.get(opts, :food?, false) do
      {:ok, _item} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: @pet_food,
          amount: 1,
          identify: 1
        })
    end

    if Keyword.get(opts, :homunculus?, true) do
      %Homunculus{}
      |> Homunculus.changeset(%{
        character_id: character.id,
        class_id: 6001,
        name: "Lif",
        lifecycle: Keyword.get(opts, :lifecycle, "active"),
        level: 50,
        skill_points: Keyword.get(opts, :skill_points, 1),
        hp: Keyword.get(opts, :hp, 1_000),
        max_hp: Keyword.get(opts, :max_hp, 1_000),
        sp: Keyword.get(opts, :sp, 200),
        max_sp: 200,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        hunger: Keyword.get(opts, :hunger, 32),
        intimacy_hundredths: Keyword.get(opts, :intimacy_hundredths, 75_100),
        active_remaining_ms:
          if(Keyword.get(opts, :lifecycle, "active") == "active", do: 1_800_000, else: 0),
        learned_skills: Keyword.get(opts, :learned_skills, %{"8001" => 3, "8002" => 1}),
        cooldowns: Keyword.get(opts, :cooldowns, %{}),
        ai_config: %{}
      })
      |> Repo.insert!()
    end

    character = Repo.preload(character, :homunculus)
    position = Keyword.get(opts, :position, {150, 150})
    session = start_player_session(character: character, map_name: "prontera", position: position)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    simulate_incoming_message(session.pid, %MapLoaded{})
    Process.sleep(20)
    flush_packets()
    session
  end

  defp command_gate_error(:insufficient_sp), do: :HOMUNCULUS_ERROR_INSUFFICIENT_SP
  defp command_gate_error(:on_cooldown), do: :HOMUNCULUS_ERROR_ON_COOLDOWN
  defp command_gate_error(:pending_deferred), do: :HOMUNCULUS_ERROR_BUSY
  defp command_gate_error(_busy), do: :HOMUNCULUS_ERROR_BUSY
end

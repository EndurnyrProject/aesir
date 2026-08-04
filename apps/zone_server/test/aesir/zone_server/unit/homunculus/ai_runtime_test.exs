defmodule Aesir.ZoneServer.Unit.Homunculus.AiRuntimeTest do
  use Aesir.DataCase, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.HomunculusPrivateState
  alias Aesir.Net.ItemRemoved
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "hom_ai_runtime_map"

  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 50, 50)})
    :ok
  end

  test "a matching movement tick advances one cell and a stale reference is inert" do
    session = active_session()
    moving = MovementHandler.move_to(session, {4, 2})
    ref = moving.homunculus_runtime.movement_timer_ref

    assert is_reference(ref)
    assert moving.homunculus.movement_state == :moving

    stale = MovementHandler.tick(make_ref(), moving)
    assert stale.homunculus.x == 2
    assert stale.homunculus_runtime.movement_timer_ref == ref

    advanced = MovementHandler.tick(ref, moving)
    assert advanced.homunculus.x == 3
    assert advanced.homunculus.y == 2
  end

  test "a blocked first step repaths or stops without crossing the blocker" do
    moving = active_session() |> MovementHandler.move_to({6, 2})
    ref = moving.homunculus_runtime.movement_timer_ref

    for {dx, dy} <- [{0, -1}, {-1, 0}, {1, 0}, {0, 1}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}] do
      :ok =
        Cell.put(@map, 2 + dx, 2 + dy, :test_barrier, abs(dx * 10 + dy) + 20,
          blocks_movement: true
        )
    end

    stopped = MovementHandler.tick(ref, moving)

    assert {stopped.homunculus.x, stopped.homunculus.y} == {2, 2}
    assert stopped.homunculus.action_state == :idle
    assert stopped.homunculus_runtime.movement_path == []
    assert stopped.homunculus_runtime.movement_timer_ref == nil
  end

  test "a disappearing typed chase target clears path and target on its next tick" do
    register_mob(910, 8, 2)
    chasing = MovementHandler.chase(active_session(), {:mob, 910})
    ref = chasing.homunculus_runtime.movement_timer_ref

    assert chasing.homunculus.target == {:mob, 910}
    assert is_reference(ref)

    UnitRegistry.unregister_unit(:mob, 910)
    SpatialIndex.remove_unit(:mob, 910)

    stopped = MovementHandler.tick(ref, chasing)
    assert stopped.homunculus.target == nil
    assert stopped.homunculus_runtime.movement_path == []
    assert stopped.homunculus_runtime.movement_timer_ref == nil
  end

  test "standby cancels movement and clears casting and target state" do
    session = active_session()
    moving = MovementHandler.move_to(session, {6, 2})
    standing = MovementHandler.standby(moving)

    assert standing.homunculus.standby?
    assert standing.homunculus.action_state == :idle
    assert standing.homunculus.movement_state == :standing
    assert standing.homunculus.target == nil
    assert standing.homunculus_runtime.movement_path == []
    assert standing.homunculus_runtime.movement_timer_ref == nil
  end

  test "separation timeout is singleton, stale-safe, and revalidates before relocation" do
    session = active_session(homunculus: %{homunculus() | x: 30, y: 30})
    armed = MovementHandler.sync_separation(session)
    ref = armed.homunculus_runtime.separation_timer_ref

    assert is_reference(ref)
    assert MovementHandler.sync_separation(armed).homunculus_runtime.separation_timer_ref == ref
    assert MovementHandler.separation_timeout(make_ref(), armed).homunculus.x == 30

    reunited = %{armed | homunculus: %{armed.homunculus | x: 3, y: 2}}
    unchanged = MovementHandler.separation_timeout(ref, reunited)
    assert {unchanged.homunculus.x, unchanged.homunculus.y} == {3, 2}

    relocated = MovementHandler.separation_timeout(ref, armed)
    assert {relocated.homunculus.x, relocated.homunculus.y} == {2, 1}
    assert relocated.homunculus_runtime.separation_timer_ref == nil
  end

  test "missing food falls through to aggressive combat instead of selecting feed forever" do
    register_mob(900, 8, 2)

    config =
      config(
        stance: :aggressive,
        auto_feed: true,
        auto_feed_threshold: 11
      )

    session = active_session(homunculus: %{homunculus() | hunger: 10, ai_config: config})

    refute HungerHandler.food_available?(
             session.homunculus.class_id,
             session.game_state.inventory
           )

    {:noreply, chasing} = ai_tick(session)

    assert chasing.homunculus.target == {:mob, 900}
    assert chasing.homunculus.movement_state == :moving
    assert is_reference(chasing.homunculus_runtime.movement_timer_ref)
  end

  test "available food executes one durable feed and publishes exact inventory and private deltas" do
    character = insert_character()
    row = insert_homunculus(character.id, %{hunger: 10, intimacy_hundredths: 25_100})

    {:ok, item} =
      InventoryPersistence.insert_item(character.id, %{nameid: 537, amount: 2, identify: 1})

    inventory = PlayerState.from_list([item])
    owner = %{player() | character_id: character.id, inventory: inventory}

    config = config(auto_feed: true, auto_feed_threshold: 11)

    companion = %{
      homunculus()
      | id: row.id,
        owner_character_id: character.id,
        hunger: 10,
        intimacy_hundredths: 25_100,
        ai_config: config
    }

    session = active_session(owner: owner, homunculus: companion)
    assert {:ok, 0} = HungerHandler.food_index(companion.class_id, inventory)

    {:noreply, fed} = ai_tick(session)

    assert fed.homunculus.hunger == 20
    assert fed.homunculus.intimacy_hundredths == 25_150
    assert fed.game_state.inventory[0].amount == 1
    refute fed.homunculus_runtime.private_dirty

    assert %Homunculus{hunger: 20, intimacy_hundredths: 25_150} =
             Persistence.load_for_character(character.id)

    assert [%InventoryItem{amount: 1}] = InventoryPersistence.load_inventory(character.id)

    assert_received {:send, :gameplay, {:item_removed, %ItemRemoved{amount: 1}}}

    assert_received {:send, :bulk,
                     {:homunculus_private_state, %HomunculusPrivateState{hunger: 20}}}

    refute_received {:send, :gameplay, {:item_removed, %ItemRemoved{}}}
    refute_received {:send, :bulk, {:homunculus_private_state, %HomunculusPrivateState{}}}
  end

  test "assist joins the owner's exact typed target on the same tick" do
    register_mob(920, 8, 2)
    session = active_session()
    session = %{session | game_state: %{session.game_state | combat_target_id: 920}}

    {:noreply, chasing} = ai_tick(session)

    assert chasing.homunculus.target == {:mob, 920}
    assert chasing.homunculus.movement_state == :moving
  end

  test "retaliation recognizes exact owner and Homunculus typed targets" do
    for {id, target_ref} <- [
          {930, {:player, 42}},
          {931, {:homunculus, 700}}
        ] do
      register_mob(id, 8, 2, target_ref)
      {:noreply, chasing} = ai_tick(active_session())

      assert chasing.homunculus.target == {:mob, id}
      assert chasing.homunculus.movement_state == :moving

      UnitRegistry.unregister_unit(:mob, id)
      SpatialIndex.remove_unit(:mob, id)
    end
  end

  test "retaliation false does not join a hostile targeting the owner" do
    register_mob(940, 8, 2, {:player, 42})
    session = active_session(homunculus: %{homunculus() | ai_config: config(retaliate: false)})

    {:noreply, unchanged} = ai_tick(session)

    assert unchanged.homunculus.target == nil
    assert unchanged.homunculus_runtime.movement_timer_ref == nil
  end

  test "AI adapts self targets and settles real SP and cooldown state" do
    skill_config = auto_skill_config(8_004, :self)

    companion = %{
      homunculus()
      | class_id: 6_009,
        learned_skills: %{8_004 => 1},
        ai_config: skill_config
    }

    {:noreply, cast} = ai_tick(active_session(homunculus: companion))

    assert cast.homunculus.sp == 49
    assert cast.homunculus.action_state == :idle
    assert cast.homunculus.casting == nil
    assert cast.homunculus.cooldowns[8_004] > System.monotonic_time(:millisecond)
    assert is_reference(cast.homunculus_runtime.cooldown_timer_ref)
  end

  test "AI adapts typed enemy targets through timed cast completion" do
    register_mob(950, 3, 2)
    skill_config = auto_skill_config(8_002, :enemy, stance: :aggressive)

    companion = %{
      homunculus()
      | learned_skills: %{8_002 => 1},
        ai_config: skill_config
    }

    {:noreply, casting} = ai_tick(active_session(homunculus: companion))

    assert casting.homunculus.action_state == :casting
    assert casting.homunculus.casting.target == {:unit, {:mob, 950}}
    assert is_reference(casting.homunculus_runtime.cast_timer_ref)

    timer_ref = casting.homunculus_runtime.cast_timer_ref
    token = casting.homunculus.casting.token
    assert {:noreply, completed} = CastingHandler.complete(timer_ref, token, casting)

    assert_received {:homunculus_test_attack, {:unit, {:mob, 950}}, 1}
    assert completed.homunculus.sp == 30
    assert completed.homunculus.action_state == :idle
    assert completed.homunculus.casting == nil
    assert completed.homunculus.cooldowns[8_002] > System.monotonic_time(:millisecond)
  end

  test "automatic SP reserve blocks while the existing manual cast crosses it" do
    skill_config = auto_skill_config(8_004, :self, auto_cast_sp_reserve_percent: 20)

    companion = %{
      homunculus()
      | class_id: 6_009,
        sp: 1,
        max_sp: 50,
        learned_skills: %{8_004 => 1},
        ai_config: skill_config
    }

    {:noreply, blocked} = ai_tick(active_session(homunculus: companion))
    assert blocked.homunculus.sp == 1
    assert blocked.homunculus.cooldowns == %{}

    assert {:ok, manually_cast} = CastingHandler.begin(blocked, 8_004, 1, :self)
    assert manually_cast.homunculus.sp == 0
    assert manually_cast.homunculus.cooldowns[8_004] > System.monotonic_time(:millisecond)
  end

  test "dirty tick emits one private state and clears dirty while clean and stale ticks emit none" do
    dirty = active_session()
    dirty = %{dirty | homunculus_runtime: %{dirty.homunculus_runtime | private_dirty: true}}

    {:noreply, published} = ai_tick(dirty)
    refute published.homunculus_runtime.private_dirty

    assert_received {:send, :bulk, {:homunculus_private_state, %HomunculusPrivateState{}}}
    refute_received {:send, :bulk, {:homunculus_private_state, %HomunculusPrivateState{}}}

    {:noreply, clean} = ai_tick(published)
    refute clean.homunculus_runtime.private_dirty
    refute_received {:send, :bulk, {:homunculus_private_state, %HomunculusPrivateState{}}}

    ref = clean.homunculus_runtime.ai_timer_ref
    assert {:noreply, stale} = CommandHandler.info(:ai_tick, make_ref(), clean)
    assert stale.homunculus_runtime.ai_timer_ref == ref
    refute_received {:send, :bulk, {:homunculus_private_state, %HomunculusPrivateState{}}}
  end

  test "passive remains idle while aggressive starts a chase through the movement handler" do
    register_mob(960, 8, 2)

    {:noreply, passive_after} = ai_tick(active_session())
    assert passive_after.homunculus_runtime.movement_timer_ref == nil

    companion = %{homunculus() | ai_config: config(stance: :aggressive)}
    {:noreply, chasing} = ai_tick(active_session(homunculus: companion))

    assert chasing.homunculus.target == {:mob, 960}
    assert chasing.homunculus.movement_state == :moving
    assert is_reference(chasing.homunculus_runtime.movement_timer_ref)
    assert is_reference(chasing.homunculus_runtime.ai_timer_ref)
  end

  test "stale AI delivery neither mutates state nor creates a second timer chain" do
    armed = AiHandler.arm(active_session())
    ref = armed.homunculus_runtime.ai_timer_ref

    assert {:noreply, unchanged} = CommandHandler.info(:ai_tick, make_ref(), armed)
    assert unchanged.homunculus_runtime.ai_timer_ref == ref
  end

  defp ai_tick(session) do
    armed = AiHandler.arm(session)
    AiHandler.tick(armed.homunculus_runtime.ai_timer_ref, armed)
  end

  defp active_session(overrides \\ []) do
    owner = Keyword.get(overrides, :owner, player())
    companion = Keyword.get(overrides, :homunculus, homunculus())

    UnitRegistry.register_unit(:player, owner.character_id, PlayerState, owner, self())
    SpatialIndex.add_unit(:player, owner.character_id, owner.x, owner.y, owner.map_name)

    UnitRegistry.register_unit(
      :homunculus,
      companion.world_gid,
      HomunculusState,
      companion,
      self()
    )

    SpatialIndex.add_unit(
      :homunculus,
      companion.world_gid,
      companion.x,
      companion.y,
      companion.map_name
    )

    session = %SessionState{game_state: owner, connection_pid: self(), homunculus: companion}

    runtime = %{
      session.homunculus_runtime
      | clocks_online: true,
        active_deadline_ms: Clock.fresh_active_deadline(Clock.now_ms())
    }

    %{session | homunculus_runtime: runtime}
  end

  defp player do
    %PlayerState{
      character_id: 42,
      character_name: "Owner",
      account_id: 43,
      map_name: @map,
      x: 2,
      y: 2,
      dir: 0,
      action_state: :idle,
      movement_state: :standing,
      combat_target_id: nil,
      inventory: %{},
      stats: %{current_state: %{hp: 100}, derived_stats: %{max_hp: 100}},
      visible_players: MapSet.new(),
      visible_mobs: MapSet.new(),
      visible_homunculi: MapSet.new(),
      visible_warps: MapSet.new(),
      visible_npcs: MapSet.new(),
      visible_shops: MapSet.new(),
      visible_items: MapSet.new(),
      visible_skill_units: MapSet.new(),
      party_id: 0
    }
  end

  defp homunculus do
    %HomunculusState{
      id: 1,
      owner_character_id: 42,
      owner_session_pid: self(),
      class_id: 6_001,
      name: "Lif",
      lifecycle: :active,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      hunger: 50,
      ai_config: Config.default([]),
      world_gid: 700,
      map_name: @map,
      x: 2,
      y: 2,
      action_state: :idle,
      movement_state: :standing
    }
  end

  defp config(overrides) do
    Config.default()
    |> Map.from_struct()
    |> Map.merge(Map.new(overrides))
    |> then(&struct!(Config, &1))
  end

  defp auto_skill_config(id, target, overrides \\ []) do
    spec = %{id: id, target: target, allowed_thresholds: []}
    config = Config.default([spec])
    skill = %{config.skills[id] | mode: :auto}

    config
    |> Map.from_struct()
    |> Map.merge(Map.new(overrides))
    |> Map.put(:skills, %{id => skill})
    |> then(&struct!(Config, &1))
  end

  defp register_mob(id, x, y, target_ref \\ nil) do
    definition = %MobDefinition{
      id: 1_001,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 50,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :plant,
      element: {:water, 1},
      walk_speed: 200,
      attack_delay: 500,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 200
    }

    mob = %MobState{
      instance_id: id,
      mob_id: definition.id,
      mob_data: definition,
      spawn_ref: nil,
      x: x,
      y: y,
      map_name: @map,
      hp: definition.hp,
      max_hp: definition.hp,
      sp: 0,
      max_sp: 0,
      target_ref: target_ref,
      spawned_at: 0
    }

    UnitRegistry.register_unit(:mob, id, MobState, mob, self())
    SpatialIndex.add_unit(:mob, id, x, y, @map)
  end

  defp insert_character do
    suffix = System.unique_integer([:positive])
    username = "airt#{suffix}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: username,
        userid: username,
        user_pass: "password",
        email: "airt#{suffix}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "AIRT#{suffix}",
        class: 1,
        base_level: 99,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })
      |> Repo.insert()

    character
  end

  defp insert_homunculus(character_id, attrs) do
    defaults = %{
      character_id: character_id,
      class_id: 6_001,
      name: "Lif",
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50
    }

    {:ok, homunculus} =
      %Homunculus{}
      |> Homunculus.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    homunculus
  end
end

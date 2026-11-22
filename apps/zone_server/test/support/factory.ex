defmodule Aesir.ZoneServer.Factory do
  @moduledoc """
  ExMachina factories for zone-server runtime structs (values held in memory, never
  inserted). Persisted rows come from `Aesir.Factory`.

      import Aesir.ZoneServer.Factory

      officer = build(:guild_member, position_index: 5)
      guild = build(:guild_state, members: [officer])
      state = build(:coordinator_state, mobs_awake: true)

  Each factory fills only the enforced keys; everything else keeps its struct default,
  so a test states the fields it cares about.
  """

  use ExMachina

  alias Aesir.TestMob
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.CandidateSnapshot
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config, as: AiConfig
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.HomunculusSnapshot
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.OwnerSnapshot
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.SkillSnapshot
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry, as: ItemGroupEntry
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group, as: ItemGroup
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.SubGroup
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes.Recipe
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Entry, as: RandomOptionEntry
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Group, as: RandomOptionGroup
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.Mmo.PetManagement.PetDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.Refine.Chance
  alias Aesir.ZoneServer.Mmo.Refine.LevelInfo
  alias Aesir.ZoneServer.Mmo.Skill.Definition, as: SkillDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell, as: SkillUnitCell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group, as: SkillUnitGroup
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Navigation.Portal
  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Route.Leg
  alias Aesir.ZoneServer.Navigation.Session
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Party.Member, as: PartyMember
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CombatStats

  @player_combatant_inputs %{
    base_level: 10,
    job_level: 1,
    str: 5,
    agi: 5,
    vit: 5,
    int: 5,
    dex: 5,
    luk: 5,
    weapon_type: :fist,
    weapon_element: :neutral,
    weapon_size: :all,
    flat_atk: 0,
    passive_atk: 0
  }

  @mob_combatant_inputs %{
    base_level: 5,
    str: 10,
    agi: 8,
    vit: 12,
    int: 3,
    dex: 7,
    luk: 5,
    atk: 50,
    atk2: nil,
    def: 10,
    soft_def: 0
  }

  @doc """
  A level 1 guild with no members and no master (`master_char_id: 0`); set the master
  when the test reads it. `members:` takes a list of `Member`s and keys them by
  `char_id`, the shape `State.members` holds.
  """
  @spec guild_state_factory(map()) :: State.t()
  def guild_state_factory(attrs) do
    {members, attrs} = Map.pop(attrs, :members, [])

    %State{
      guild_id: sequence(:guild_state_id, & &1, start_at: 1),
      name: sequence(:guild_state_name, &"Guild #{&1}"),
      master_char_id: 0,
      members: Map.new(members, &{&1.char_id, &1})
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  @doc "An online level 1 party member with a sequenced character id and name."
  @spec party_member_factory() :: PartyMember.t()
  def party_member_factory do
    %PartyMember{
      char_id: sequence(:party_member_char_id, & &1, start_at: 1),
      name: sequence(:party_member_name, &"Member #{&1}"),
      base_level: 1,
      online: true
    }
  end

  @doc "An empty party with sharing off and no leader. `members:` takes a list keyed by `char_id`."
  @spec party_state_factory(map()) :: PartyState.t()
  def party_state_factory(attrs) do
    {members, attrs} = Map.pop(attrs, :members, [])

    %PartyState{
      party_id: sequence(:party_state_id, & &1, start_at: 1),
      name: sequence(:party_state_name, &"Party #{&1}"),
      leader_char_id: 0,
      exp_share: false,
      item_pickup_share: false,
      members: Map.new(members, &{&1.char_id, &1})
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  @doc "An online level 1 member at the Newbie position (19)."
  @spec guild_member_factory() :: Member.t()
  def guild_member_factory do
    %Member{
      char_id: sequence(:guild_member_char_id, & &1, start_at: 1),
      name: sequence(:guild_member_name, &"Member #{&1}"),
      base_level: 1,
      online: true
    }
  end

  @doc """
  The state of a `"prontera"` coordinator before its first visit: no map data,
  no spawn lines, mobs neither spawned nor awake.
  """
  @spec coordinator_state_factory() :: Coordinator.t()
  def coordinator_state_factory do
    %Coordinator{map_name: "prontera"}
  end

  @doc "An unstored status entry with empty custom state. Set the type and any values the test uses."
  @spec status_entry_factory() :: StatusEntry.t()
  def status_entry_factory, do: %StatusEntry{state: %{}}

  @doc "A synthetic castle on `aldeg_cas01` with 24 treasure cells and eight soldier slots."
  @spec castle_factory() :: Castle.t()
  def castle_factory do
    %Castle{
      id: sequence(:castle_id, & &1, start_at: 10_000),
      map: "aldeg_cas01",
      name: "Test Castle",
      client_id: 0,
      emperium: {5, 5},
      respawn: {10, 10},
      treasure: %{box_id: 7_000, cells: for(i <- 0..23, do: {100 + i, 200 + i})},
      guardians: for(i <- 0..7, do: %{type: :soldier, cell: {30 + i, 30}})
    }
  end

  @doc "A portal from `nav_a` to `nav_b`, at {0, 0} on both maps, with a sequenced id."
  @spec navigation_portal_factory() :: Portal.t()
  def navigation_portal_factory do
    %Portal{
      id: sequence(:navigation_portal_id, &"portal-#{&1}"),
      map: "nav_a",
      x: 0,
      y: 0,
      to_map: "nav_b",
      to_x: 0,
      to_y: 0
    }
  end

  @doc "An attached NPC script with a player snapshot and the test process as its connection."
  @spec script_ctx_factory(map()) :: Ctx.t()
  def script_ctx_factory(attrs) do
    {player, attrs} =
      Map.pop_lazy(attrs, :game_state, fn -> build(:player_state, account_id: 100) end)

    %Ctx{
      char_id: player.character_id,
      account_id: player.account_id,
      connection_pid: self(),
      game_state: player,
      source: {:npc, :test_npc}
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  @doc "An NPC with view class 58 at {0, 0} on `prontera`."
  @spec npc_placement_factory() :: Placement.t()
  def npc_placement_factory, do: %Placement{map: "prontera", x: 0, y: 0, sprite: 58}

  @doc "An empty vendor with view class 85 at {0, 0} on `prontera`, with a sequenced id."
  @spec npc_shop_factory() :: Shop.t()
  def npc_shop_factory do
    %Shop{
      id: sequence(:npc_shop_id, &"shop-#{&1}"),
      map: "prontera",
      x: 0,
      y: 0,
      dir: 0,
      sprite: 85
    }
  end

  @doc "A warp from `nav_a` to `nav_b`, at {0, 0} on both maps, with a sequenced id."
  @spec warp_factory() :: Warp.t()
  def warp_factory do
    %Warp{
      id: sequence(:warp_id, &"warp-#{&1}"),
      map: "nav_a",
      x: 0,
      y: 0,
      to_map: "nav_b",
      to_x: 0,
      to_y: 0
    }
  end

  @doc "An empty navigation route; pass `legs:` to describe a route through maps."
  @spec navigation_route_factory() :: Route.t()
  def navigation_route_factory, do: %Route{legs: []}

  @doc "Leg zero on `nav_a`, with neither a materialized path nor an exit/arrival."
  @spec navigation_leg_factory() :: Leg.t()
  def navigation_leg_factory do
    %Leg{index: 0, map: "nav_a", cells: nil, exit_portal: nil, next_map: nil, arrive: nil}
  end

  @doc "A pending navigation to `nav_a`, with a fresh epoch reference."
  @spec navigation_session_factory() :: Session.t()
  def navigation_session_factory, do: %Session{ref: make_ref(), target: {:map, "nav_a"}}

  @doc "A level 1 monster with 100 HP and one-cell melee range."
  @spec mob_definition_factory() :: MobDefinition.t()
  def mob_definition_factory do
    %MobDefinition{
      id: 1002,
      aegis_name: "TEST_MOB",
      name: "Test Mob",
      level: 1,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400
    }
  end

  @doc "A quest with a sequenced id and no time limit, objectives or drops."
  @spec quest_definition_factory() :: QuestDefinition.t()
  def quest_definition_factory do
    id = sequence(:quest_definition_id, & &1, start_at: 1)
    %QuestDefinition{id: id, title: "Quest #{id}"}
  end

  @doc "A refine level with no bonus or cost options."
  @spec refine_level_factory() :: LevelInfo.t()
  def refine_level_factory, do: %LevelInfo{}

  @doc "A refine cost option with no effect or material by default."
  @spec refine_chance_factory() :: Chance.t()
  def refine_chance_factory, do: %Chance{}

  @doc "An inert Poring species with its egg, no other items, bonuses or evolutions."
  @spec pet_definition_factory() :: PetDefinition.t()
  def pet_definition_factory do
    %PetDefinition{
      mob_id: 1002,
      tame_item_id: 0,
      egg_item_id: 9001,
      equip_item_id: 0,
      food_item_id: 0,
      fullness: 0,
      hungry_delay_ms: 0,
      hunger_increase: 0,
      intimacy_start: 0,
      intimacy_fed: 0,
      intimacy_overfed: 0,
      intimacy_hungry: 0,
      intimacy_owner_die: 0,
      capture_rate: 0,
      special_performance: false,
      attack_rate: 0,
      retaliate_rate: 0,
      change_target_rate: 0,
      allow_auto_feed: false,
      bonus_program: [],
      support_ops: [],
      evolution: []
    }
  end

  @doc "A guaranteed, instant Fire Bolt at the current target, in the attack state."
  @spec mob_skill_row_factory(map()) :: MobSkillDb.row()
  def mob_skill_row_factory(attrs) do
    {condition, attrs} = Map.pop(attrs, :condition, %{})

    %{
      skill: "MG_FIREBOLT",
      skill_id: 19,
      state: :attack,
      level: 1,
      rate: 10_000,
      cast_time: 0,
      delay: 0,
      cancelable: false,
      target: :target,
      condition:
        Map.merge(
          %{type: :always, value: 0, val1: nil, val2: nil, val3: nil, val4: nil, val5: nil},
          condition
        ),
      emotion: nil
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  @doc """
  A plain monster line spawning one Poring (1002) at the fixed cell `{100, 100}`,
  respawning after 5 s with no variance.
  """
  @spec mob_spawn_factory() :: MobSpawn.t()
  def mob_spawn_factory do
    %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100}
    }
  end

  @doc """
  An idle, standing, living player on `"prontera"` at `{150, 150}`, with the
  configured view range and empty visibility sets, the shape `PlayerState.new/1`
  gives a player on a map. `stats:` takes a partial map: `PlayerStateFixture`
  fills the rest (100 HP, 100 SP, all base stats 1).
  """
  @spec player_state_factory(map()) :: PlayerState.t()
  def player_state_factory(attrs) do
    %{
      character_id: sequence(:player_state_character_id, & &1, start_at: 1),
      map_name: "prontera",
      x: 150,
      y: 150,
      view_range: Config.view_range(),
      stats: %{},
      visible_players: MapSet.new(),
      visible_mobs: MapSet.new(),
      visible_warps: MapSet.new(),
      visible_npcs: MapSet.new(),
      visible_shops: MapSet.new(),
      visible_items: MapSet.new(),
      visible_skill_units: MapSet.new()
    }
    |> Map.merge(attrs)
    |> PlayerStateFixture.build()
  end

  @doc """
  A live mob built through `MobState.new/6`: an instance of
  `Aesir.TestMob.definition/0` on `"prontera"` at `{100, 100}`, spawned from a
  `:mob_spawn` line at that cell. Takes `instance_id`, `mob_data` (the
  definition), `map_name`, `x` and `y` as constructor inputs; any other key
  overrides a field of the built state.
  """
  @spec mob_state_factory(map()) :: MobState.t()
  def mob_state_factory(attrs) do
    {mob_data, attrs} = Map.pop_lazy(attrs, :mob_data, &TestMob.definition/0)

    {instance_id, attrs} =
      Map.pop_lazy(attrs, :instance_id, fn -> sequence(:mob_state_id, & &1) end)

    {map_name, attrs} = Map.pop(attrs, :map_name, "prontera")
    {x, attrs} = Map.pop(attrs, :x, 100)
    {y, attrs} = Map.pop(attrs, :y, 100)

    spawn = build(:mob_spawn, mob: mob_data.id, spawn_area: %MobSpawn.SpawnArea{x: x, y: y})

    instance_id
    |> MobState.new(mob_data, spawn, map_name, x, y)
    |> struct!(attrs)
  end

  @doc """
  A player's stats with `PlayerStateFixture`'s defaults for every section the
  attributes leave out: all base stats 1, 100 of 100 HP and SP, job 0, no
  equipment and no modifiers. Nested sections take a struct or a partial map.
  """
  @spec player_stats_factory(map()) :: PlayerStats.t()
  def player_stats_factory(attrs), do: PlayerStateFixture.stats(attrs)

  @doc """
  A level 10 skill 1 (`:test_skill`) with every cast, cost and flag field at its
  struct default: instant, no fixed cast and DEX-scaled.
  """
  @spec skill_definition_factory() :: SkillDefinition.t()
  def skill_definition_factory do
    %SkillDefinition{id: 1, name: :test_skill, display_name: "Test Skill", max_level: 10}
  end

  @doc "A ground group with a sequenced ID and synthetic skill name; all other fields use struct defaults."
  @spec skill_unit_group_factory() :: SkillUnitGroup.t()
  def skill_unit_group_factory do
    %SkillUnitGroup{
      group_id: sequence(:skill_unit_group_id, & &1, start_at: 1),
      skill_name: :test_skill
    }
  end

  @doc "An unplaced cell with a sequenced ID; tests supply the owning group and coordinates."
  @spec skill_unit_cell_factory() :: SkillUnitCell.t()
  def skill_unit_cell_factory do
    %SkillUnitCell{cell_id: sequence(:skill_unit_cell_id, & &1, start_at: 1), group_id: 0}
  end

  @doc "A level 1 neutral dagger in the right hand: item 1, 100 base ATK, no refine."
  @spec weapon_hand_factory() :: WeaponHand.t()
  def weapon_hand_factory do
    %WeaponHand{
      item_id: 1,
      subtype: :dagger,
      element: :neutral,
      base_atk: 100,
      weapon_level: 1,
      refine_atk: 0,
      overrefine_band: 0,
      slot: :right_hand
    }
  end

  @doc """
  A player combatant (unit 1001, base level 10, job level 1, all stats 5, bare
  fist, neutral medium human at `{100, 100}` on `"test_map"`).

  Besides any `Combatant` field, takes the inputs its combat stats derive from:
  `base_level`, `job_level`, the six base stats, `weapon_type`/`weapon_element`/
  `weapon_size`, and the independent `flat_atk` (equipment) and `passive_atk`
  (mastery) contributions. Status ATK uses the booted mode's player formula; DEF
  (`vit * base_level / 2`), HIT (`base_level + dex`), FLEE (`base_level + agi`) and
  perfect dodge (`luk / 10 + 1`) are arranged values, not the rAthena formulas.
  Built through `Combatant.new!/1`, so its relationship roots default like a
  production combatant's (a `unit_type: :homunculus` one is owned by player 1001
  unless its roots are given); an unknown key raises.
  """
  @spec player_combatant_factory(map()) :: Combatant.t()
  def player_combatant_factory(attrs) do
    {inputs, fields} = split_combatant_attrs(@player_combatant_inputs, attrs)

    status_atk =
      Mechanics.player_formulas().base_atk(
        %{
          str: inputs.str,
          dex: inputs.dex,
          luk: inputs.luk,
          pow: 0,
          base_level: inputs.base_level
        },
        WeaponTypes.is_ranged?(inputs.weapon_type)
      )

    combatant(
      Map.merge(
        %{
          unit_id: 1001,
          unit_type: :player,
          base_stats: base_stats(inputs),
          combat_stats: %CombatStats{
            atk: status_atk + inputs.flat_atk + inputs.passive_atk,
            physical_attack: %{
              status_atk: status_atk,
              flat_atk: inputs.flat_atk,
              mastery_atk: inputs.passive_atk,
              str: inputs.str,
              dex: inputs.dex
            },
            def: trunc(inputs.vit * inputs.base_level / 2),
            hit: inputs.base_level + inputs.dex,
            flee: inputs.base_level + inputs.agi,
            perfect_dodge: trunc(inputs.luk / 10) + 1,
            passive_atk: inputs.passive_atk
          },
          progression: %{base_level: inputs.base_level, job_level: inputs.job_level},
          element: :neutral,
          race: :human,
          size: :medium,
          weapon: %{
            type: inputs.weapon_type,
            element: inputs.weapon_element,
            size: inputs.weapon_size
          },
          attack_range: 1,
          attack_delay_ms: 500,
          position: {100, 100},
          map_name: "test_map"
        },
        fields
      )
    )
  end

  @doc """
  A mob combatant (unit 2001, a Poring's monster id 1002, base level 5, STR 10,
  AGI 8, VIT 12, INT 3, DEX 7, LUK 5, earth medium brute at `{105, 105}` on
  `"test_map"`, claw weapon).

  Besides any `Combatant` field, takes the inputs its combat stats derive from:
  `base_level`, the six base stats, the database `atk` (50) and classic `atk2`
  (defaults to `atk`), and `def` (10) / `soft_def` (0). Status ATK and the weapon
  roll bounds are the booted mode's raw monster base (`MobState.new/6`) with no
  status modifiers; HIT (`base_level + dex + 5`), FLEE (`base_level + agi + 3`)
  and perfect dodge (`luk / 10 + 1`) are arranged values. Built through
  `Combatant.new!/1`; an unknown key raises.
  """
  @spec mob_combatant_factory(map()) :: Combatant.t()
  def mob_combatant_factory(attrs) do
    {inputs, fields} = split_combatant_attrs(@mob_combatant_inputs, attrs)

    mob =
      TestMob.definition(
        level: inputs.base_level,
        atk: inputs.atk,
        atk2: inputs.atk2 || inputs.atk,
        stats: Map.take(inputs, [:str, :agi, :vit, :int, :dex, :luk])
      )

    %{batk: status_atk, watk_min: atk_min, watk_max: atk_max} =
      build(:mob_state, mob_data: mob).base

    combatant(
      Map.merge(
        %{
          unit_id: 2001,
          unit_type: :mob,
          monster_id: 1002,
          base_stats: base_stats(inputs),
          combat_stats: %CombatStats{
            atk: status_atk,
            atk_min: min(atk_min, atk_max),
            atk_max: atk_max,
            def: inputs.def,
            soft_def: inputs.soft_def,
            hit: inputs.base_level + inputs.dex + 5,
            flee: inputs.base_level + inputs.agi + 3,
            perfect_dodge: trunc(inputs.luk / 10) + 1
          },
          progression: %{base_level: inputs.base_level, job_level: 1},
          element: :earth,
          race: :brute,
          size: :medium,
          weapon: %{type: :claw, element: :neutral, size: :all},
          attack_range: 1,
          attack_delay_ms: 500,
          position: {105, 105},
          map_name: "test_map"
        },
        fields
      )
    )
  end

  @doc """
  A rested level 1 Lif (class 6001) with a sequenced id and owner and
  `Config.default/0` AI; every other field is the struct default.
  """
  @spec homunculus_state_factory() :: HomunculusState.t()
  def homunculus_state_factory do
    %HomunculusState{
      id: sequence(:homunculus_state_id, & &1, start_at: 1),
      owner_character_id: sequence(:homunculus_state_owner_id, & &1, start_at: 1),
      class_id: 6001,
      name: "Homunculus",
      ai_config: AiConfig.default()
    }
  end

  @doc """
  A living owner as the Homunculus AI sees it: a sequenced player at `{0, 0}` with
  100 of 100 HP and no target.
  """
  @spec ai_owner_snapshot_factory() :: OwnerSnapshot.t()
  def ai_owner_snapshot_factory do
    %OwnerSnapshot{
      ref: {:player, sequence(:ai_owner_snapshot_id, & &1, start_at: 1)},
      position: {0, 0},
      hp: 100,
      max_hp: 100,
      alive?: true
    }
  end

  @doc """
  An active, idle Homunculus as its AI sees it: a sequenced ref at `{0, 0}`, 100 of
  100 HP and SP, hunger 50 with no food, melee range, `Config.default/0`, no target
  and no castable skills.
  """
  @spec ai_homunculus_snapshot_factory() :: HomunculusSnapshot.t()
  def ai_homunculus_snapshot_factory do
    %HomunculusSnapshot{
      ref: {:homunculus, sequence(:ai_homunculus_snapshot_id, & &1, start_at: 1)},
      lifecycle: :active,
      alive?: true,
      busy?: false,
      standby?: false,
      position: {0, 0},
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      hunger: 50,
      food_available?: false,
      attack_range: 1,
      ai_config: AiConfig.default()
    }
  end

  @doc """
  An unclaimed, non-boss Poring (class 1002) with 100 of 100 HP at `{1, 0}`, in
  melee range of a Homunculus at `{0, 0}`, with a sequenced mob ref.
  """
  @spec ai_candidate_snapshot_factory() :: CandidateSnapshot.t()
  def ai_candidate_snapshot_factory do
    %CandidateSnapshot{
      ref: {:mob, sequence(:ai_candidate_snapshot_id, & &1, start_at: 1)},
      position: {1, 0},
      hp: 100,
      max_hp: 100,
      class_id: 1002,
      boss?: false
    }
  end

  @doc "A free, ready level 1 self-target skill (8001); set `id` for any other skill."
  @spec ai_skill_snapshot_factory() :: SkillSnapshot.t()
  def ai_skill_snapshot_factory do
    %SkillSnapshot{id: 8001, level: 1, target: :self, sp_cost: 0, cooldown_ready?: true}
  end

  @doc """
  A plain `:etc` item definition named after its id. The id is sequenced from
  9,000,001, beyond every item-db id, so it never resolves to a real item; pass
  `id:` when the test needs a catalog item.
  """
  @spec item_definition_factory(map()) :: ItemDefinition.t()
  def item_definition_factory(attrs) do
    {id, attrs} =
      Map.pop_lazy(attrs, :id, fn -> sequence(:item_definition_id, & &1, start_at: 9_000_001) end)

    %ItemDefinition{id: id, aegis_name: "Item_#{id}", name: "Item #{id}"}
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  @doc """
  One identified, public, plain Red Potion (501) on the cell `{100, 100}` at
  sub-cell `{3, 3}`, with a sequenced ground id, dropped at monotonic time 0.
  """
  @spec ground_item_factory() :: GroundItem.t()
  def ground_item_factory do
    %GroundItem{
      id: sequence(:ground_item_id, & &1, start_at: 1),
      nameid: 501,
      amount: 1,
      x: 100,
      y: 100,
      sub_x: 3,
      sub_y: 3,
      identified: true,
      dropped_at: 0
    }
  end

  @doc "An item-group entry granting one Red Potion (501) at rate 0; set `rate:` to weight it."
  @spec item_group_entry_factory() :: ItemGroupEntry.t()
  def item_group_entry_factory, do: %ItemGroupEntry{item_id: 501}

  @doc "A `:random` subgroup 1 with no entries."
  @spec item_subgroup_factory() :: SubGroup.t()
  def item_subgroup_factory, do: %SubGroup{number: 1, algorithm: :random, entries: []}

  @doc "An item group with a sequenced key and no subgroups."
  @spec item_group_factory() :: ItemGroup.t()
  def item_group_factory do
    %ItemGroup{key: sequence(:item_group_key, &:"test_group_#{&1}"), subgroups: []}
  end

  @doc """
  A random-option candidate for option 1 with the fixed value 1, parameter 0 and a
  10,000 (always) chance.
  """
  @spec random_option_entry_factory() :: RandomOptionEntry.t()
  def random_option_entry_factory do
    %RandomOptionEntry{option_id: 1, min: 1, max: 1, param: 0, chance: 10_000}
  end

  @doc "A random option group with a sequenced id, no fixed slots and no random picks."
  @spec random_option_group_factory() :: RandomOptionGroup.t()
  def random_option_group_factory do
    id = sequence(:random_option_group_id, & &1, start_at: 1)
    %RandomOptionGroup{id: id, name: "Group #{id}", slots: [], max_random: 0, random: []}
  end

  @doc """
  A level 1 Pharmacy (228) recipe for a Red Potion (501), item level 22, made from
  one Jellopy (1002), with a sequenced recipe id.
  """
  @spec production_recipe_factory() :: Recipe.t()
  def production_recipe_factory do
    %Recipe{
      id: sequence(:production_recipe_id, & &1, start_at: 1),
      product_id: 501,
      item_level: 22,
      skill_id: 228,
      skill_level: 1,
      materials: [%{item_id: 1002, amount: 1}]
    }
  end

  defp combatant(attrs) do
    attrs = owner_roots(attrs)
    _unknown_keys_raise = struct!(Combatant, attrs)
    Combatant.new!(attrs)
  end

  defp owner_roots(%{unit_type: :homunculus} = attrs) do
    attrs
    |> Map.put_new(:social_root, {:player, 1001})
    |> Map.put_new(:reward_root, {:player, 1001})
  end

  defp owner_roots(attrs), do: attrs

  defp split_combatant_attrs(input_defaults, attrs) do
    {inputs, fields} = Map.split(attrs, Map.keys(input_defaults))
    {Map.merge(input_defaults, inputs), fields}
  end

  defp base_stats(inputs) do
    %BaseStats{
      str: inputs.str,
      agi: inputs.agi,
      vit: inputs.vit,
      int: inputs.int,
      dex: inputs.dex,
      luk: inputs.luk
    }
  end
end

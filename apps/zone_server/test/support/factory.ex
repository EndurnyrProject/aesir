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
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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
  roll bounds come from the booted mode's mob formulas with no status modifiers;
  HIT (`base_level + dex + 5`), FLEE (`base_level + agi + 3`) and perfect dodge
  (`luk / 10 + 1`) are arranged values. Built through `Combatant.new!/1`; an
  unknown key raises.
  """
  @spec mob_combatant_factory(map()) :: Combatant.t()
  def mob_combatant_factory(attrs) do
    {inputs, fields} = split_combatant_attrs(@mob_combatant_inputs, attrs)
    formulas = Mechanics.mob_formulas()

    mob =
      struct(MobDefinition,
        level: inputs.base_level,
        atk: inputs.atk,
        atk2: inputs.atk2 || inputs.atk
      )

    {atk_min, atk_max} = formulas.attack_bounds(mob, %{})

    combatant(
      Map.merge(
        %{
          unit_id: 2001,
          unit_type: :mob,
          monster_id: 1002,
          base_stats: base_stats(inputs),
          combat_stats: %CombatStats{
            atk: formulas.status_attack(mob, inputs.str, 0, %{}),
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

defmodule Aesir.ZoneServer.Unit.Mob.MobState do
  @moduledoc """
  Represents the state of a mob entity in the game world.
  Implements the Entity behaviour for status effect calculations.
  Similar to PlayerState but for monsters with AI and combat capabilities.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Mob.Calculated
  alias Aesir.ZoneServer.Unit.Mob.Stats
  alias Aesir.ZoneServer.Unit.Ref

  @behaviour Aesir.ZoneServer.Unit

  @typedoc """
  The mob skill state: `:berserk`/`:angry` attack (angry when aggressive),
  `:rush`/`:follow` chase (follow when aggressive), `:idle`, `:walk` (random
  walk), `:loot` and `:dead`.
  """
  @type skill_state :: :idle | :walk | :loot | :dead | :berserk | :angry | :rush | :follow
  @type movement_state :: :standing | :moving | :returning

  @enforce_keys [
    :instance_id,
    :mob_id,
    :mob_data,
    :spawn_ref,
    :x,
    :y,
    :map_name,
    :hp,
    :sp,
    :spawned_at
  ]
  defstruct [
    # Core identification
    instance_id: nil,
    mob_id: nil,
    level: nil,
    mob_data: nil,
    base: nil,
    calculated: nil,
    spawn_ref: nil,
    process_pid: nil,

    # Position & Movement
    x: nil,
    y: nil,
    map_name: nil,
    dir: 0,

    # Movement state machine
    movement_state: :standing,
    walk_path: [],
    walk_delay_until: 0,
    # Where a move request made while walking redirects the walk once the
    # pending step lands.
    walk_target: nil,
    # The step the walk scheduled last, read by the hit stop (`HitStop`).
    pending_step: nil,
    # An escape walk that damage cannot stop; it ends when the walk does.
    can_escape: false,
    # Whether the walk paths in a straight line (diagonal first) instead of
    # around obstacles, for its start and every re-path.
    walk_easy: false,
    # Consecutive walk steps an icewall cell held the mob on; any step taken
    # resets it. Read only by the walk for now.
    walk_fail_count: 0,
    # A chase walk (the source's attack_continue): entering its path puts the
    # mob in its rush state before the first cell's skill check.
    chase_walk: false,
    # The end (ms) of the fake cast bar a monster shows while it moves, kept
    # until Speed Up ends it.
    trickcasting: nil,

    # AI state
    skill_state: :idle,
    # Whether the mob is in its aggressive (angry) mode: set from the angry
    # mode on every entry into a non-attack, non-chase state, cleared by an
    # attacked event, a provoke and a search that finds a target in attack
    # range. Picks `:angry`/`:follow` over `:berserk`/`:rush` in `set_state/2`.
    aggressive: false,
    # The target of the mob's standing attack order and the time (ms) its
    # attack timer fires; set when the AI orders an attack, cleared when it
    # stops attacking (target unlock, chase start, a refused order).
    attack_target: nil,
    attack_timer_at: nil,
    # The unit or floor item the mob is walking to, and the monotonic time (ms)
    # a chase walk held by the walk delay resumes at.
    chase_target: nil,
    chase_resume_at: nil,
    # The unit whose provoke last locked the mob's target; a lock onto any
    # other unit clears it.
    provoke_flag: nil,
    # The skill of the mob's last cast, until its next swing (the `afterskill`
    # condition).
    last_skill_id: nil,
    # The AI does not start a random walk before this time (ms).
    next_walktime: nil,
    # The last think (ms) at which the mob could move; an immobile mob unlocks
    # its target 2 s after it.
    last_canmove: nil,
    # The last think (ms) that ran the periodic skill check in a non-attack state.
    last_skillcheck: nil,
    # The players that have had the mob in their active range since it was
    # placed on its map; a mob no player has spotted neither wanders nor uses
    # idle skills under the lazy AI.
    spotted_by: MapSet.new(),
    ai_awake: true,
    ai_timer_ref: nil,
    # The cell the mob actually spawned on.
    spawn_point: nil,
    target_ref: nil,
    loot_target_id: nil,
    looted_items: [],
    # The pending attacked event: the retaliation target of the last landed hit
    # (and of the last "norm" hit, a normal attack on the mob in its attack
    # state from within its attack range + 1), consumed by the next AI think.
    attacked_ref: nil,
    norm_attacked_ref: nil,
    # Rude attacks counted by the AI's target-change step; the `rudeattacked`
    # skill condition reads it.
    attacked_count: 0,
    # Per-skill cooldown gate: `skill_id => expires_at` in the same
    # millisecond timestamp domain as the melee `last_attack_time` delay. The
    # `casting` map (`%{row: row, complete_at: ms, timer_ref: ref}`) marks an
    # in-progress cast; `timer_ref` is the pending `{:casting, :complete}` timer
    # so an interruption can cancel it. `master_id` links a summoned slave back
    # to its summoner's instance id.
    skill_cooldowns: %{},
    casting: nil,
    master_id: nil,
    last_linktime: 0,
    can_summon: false,
    owner_player_id: nil,
    # The summon class a player-owned monster belongs to (`:sphere`, `:flora`).
    # It selects which spawn-time stat adjustments apply and whether the summon
    # lends its master's equipment procs to its attacks.
    summon_kind: nil,
    guild_id: 0,
    no_exp: false,
    no_drops: false,
    # True until the first AI tick after spawn has run skill selection; that
    # tick selects with the `:spawn` event so `onspawn` rows can fire.
    spawn_tick_pending?: true,
    last_ai_tick: nil,
    aggro_list: %{},
    aggro_order: [],
    typed_aggro_list: %{},
    typed_aggro_order: [],
    last_action_time: nil,
    act_delay_until: nil,
    last_attack_time: nil,
    # The (absolute) time (ms) an established attack delay ends. A delay is
    # stamped when it starts, so a later attack-speed change cannot move it.
    attack_delay_until: nil,
    # The AI does not think before this time (ms): after an attack or a cast's
    # end it rests for its attack motion.
    next_think_at: nil,

    # Combat state
    hp: nil,
    sp: nil,
    is_dead: false,

    # Spatial awareness
    view_range: 12,
    visible_entities: %MapSet{},

    # Lifecycle
    spawned_at: nil,
    last_damage_time: nil,
    respawn_delay: 0,
    deferred_epoch: 0,

    # Status effects
    status_effects: %{},

    # Skill interaction flags
    stolen_from: false,
    coin_stolen: false,

    # Attack-type of recent damaging hits, keyed by the typed attacker ref
    # (e.g. `{:player, id}` / the raw attacker id form the combat path uses).
    # Written just before each hit is applied so the death path can read the
    # killing blow's classification (`:melee | :ranged | :magic`) to grant the
    # attacker's on-kill HP/SP gain equipment bonuses. Keyed by attacker so
    # simultaneous attackers never read each other's classification.
    last_hit_types: %{},

    # OnMyMobDead owner event (rAthena): a raw "Name::OnLabel" ref threaded
    # through from the summoning op's `event:` opt, resolved only at death
    # time. `nil` for every ordinary spawn -- exactly today's behavior.
    owner_event: nil
  ]

  @type t() :: %__MODULE__{
          instance_id: integer(),
          mob_id: integer(),
          level: non_neg_integer() | nil,
          base: Calculated.t() | nil,
          calculated: Calculated.t() | nil,
          loot_target_id: pos_integer() | nil,
          looted_items: [GroundItem.t()],
          mob_data: MobDefinition.t(),
          spawn_ref: MobSpawn.t(),
          process_pid: pid() | nil,
          x: integer(),
          y: integer(),
          map_name: String.t(),
          dir: integer(),
          movement_state: movement_state(),
          walk_path: list(),
          walk_delay_until: integer(),
          walk_target: {integer(), integer()} | nil,
          pending_step: HitStop.step(),
          can_escape: boolean(),
          walk_easy: boolean(),
          walk_fail_count: non_neg_integer(),
          chase_walk: boolean(),
          trickcasting: integer() | nil,
          skill_state: skill_state(),
          aggressive: boolean(),
          attack_target: Ref.t() | nil,
          attack_timer_at: integer() | nil,
          chase_target: Ref.t() | {:item, pos_integer()} | nil,
          chase_resume_at: integer() | nil,
          provoke_flag: Ref.t() | nil,
          last_skill_id: integer() | nil,
          next_walktime: integer() | nil,
          last_canmove: integer() | nil,
          last_skillcheck: integer() | nil,
          spotted_by: MapSet.t(integer()),
          ai_awake: boolean(),
          ai_timer_ref: reference() | nil,
          spawn_point: {integer(), integer()} | nil,
          target_ref: Ref.t() | nil,
          attacked_ref: Ref.t() | nil,
          norm_attacked_ref: Ref.t() | nil,
          attacked_count: non_neg_integer(),
          skill_cooldowns: %{optional(integer()) => integer()},
          casting: map() | nil,
          master_id: integer() | nil,
          last_linktime: integer(),
          can_summon: boolean(),
          owner_player_id: integer() | nil,
          summon_kind: atom() | nil,
          guild_id: non_neg_integer(),
          no_exp: boolean(),
          no_drops: boolean(),
          spawn_tick_pending?: boolean(),
          last_ai_tick: integer() | nil,
          aggro_list: map(),
          aggro_order: [integer()],
          typed_aggro_list: %{
            optional(Ref.t()) => %{
              contributor: Ref.t(),
              source_type: atom(),
              reward_owner_id: integer() | nil,
              damage: non_neg_integer(),
              first_hit_order: non_neg_integer()
            }
          },
          typed_aggro_order: [Ref.t()],
          last_action_time: integer() | nil,
          act_delay_until: integer() | nil,
          last_attack_time: integer() | nil,
          attack_delay_until: integer() | nil,
          next_think_at: integer() | nil,
          hp: integer(),
          sp: integer(),
          is_dead: boolean(),
          view_range: integer(),
          visible_entities: MapSet.t(),
          spawned_at: integer(),
          last_damage_time: integer() | nil,
          respawn_delay: integer(),
          deferred_epoch: non_neg_integer(),
          status_effects: map(),
          stolen_from: boolean(),
          coin_stolen: boolean(),
          last_hit_types: %{optional(term()) => {:melee | :ranged | :magic, integer() | nil}},
          owner_event: String.t() | nil
        }

  @doc """
  Creates a new mob state instance.
  """
  @spec new(integer(), MobDefinition.t(), MobSpawn.t(), String.t(), integer(), integer()) :: t()
  def new(instance_id, mob_data, spawn_ref, map_name, x, y) do
    current_time = System.system_time(:second)

    state = %__MODULE__{
      instance_id: instance_id,
      mob_id: mob_data.id,
      level: mob_data.level,
      mob_data: mob_data,
      spawn_ref: spawn_ref,
      map_name: map_name,
      x: x,
      y: y,
      spawn_point: {x, y},
      hp: max(mob_data.hp, 1),
      sp: mob_data.sp,
      spawned_at: current_time,
      last_ai_tick: current_time,
      status_effects: %{},
      view_range: mob_data.skill_range,
      respawn_delay: spawn_ref.respawn_time,
      aggressive: :angry in (mob_data.modes || [])
    }

    base = Stats.base(state)
    %{state | base: base, calculated: base, sp: base.max_sp}
  end

  @doc "The runtime level, which can differ from the current form's database level."
  @spec get_level(t()) :: non_neg_integer()
  def get_level(%__MODULE__{level: level}) when is_integer(level), do: level
  def get_level(%__MODULE__{mob_data: data}), do: data.level

  @impl Aesir.ZoneServer.Unit
  def get_race(%__MODULE__{mob_data: mob_data}) do
    mob_data.race
  end

  @impl Aesir.ZoneServer.Unit
  def get_element(%__MODULE__{calculated: %Calculated{def_ele: element, ele_lv: level}}) do
    {element, level}
  end

  def get_element(%__MODULE__{mob_data: %{element: element}}), do: element

  @doc "The monster class the mob runs as, from its calculated mode."
  @spec monster_class(t()) :: MobMode.class()
  def monster_class(%__MODULE__{calculated: %Calculated{class: class}}), do: class
  def monster_class(%__MODULE__{mob_data: %{modes: modes}}), do: MobMode.class(modes || [])
  def monster_class(%__MODULE__{}), do: :normal

  @doc "The monster's calculated mode atoms."
  @spec modes(t()) :: [atom()]
  def modes(%__MODULE__{} = state), do: mode_atoms(state)

  @doc "Whether the monster's calculated mode includes `mode`."
  @spec mode?(t(), atom()) :: boolean()
  def mode?(%__MODULE__{} = state, mode), do: mode in mode_atoms(state)

  @impl Aesir.ZoneServer.Unit
  def is_boss?(%__MODULE__{} = mob_state), do: monster_class(mob_state) == :boss

  @doc "Whether the monster resists being knocked back: the knockback-immune mode."
  @impl Aesir.ZoneServer.Unit
  def knockback_immune?(%__MODULE__{calculated: %Calculated{mode: mode}}),
    do: :knockback_immune in MobMode.from_mask(mode)

  def knockback_immune?(%__MODULE__{}), do: false

  @doc """
  Whether the monster is status-immune (MD_STATUSIMMUNE): the boss, guardian
  and battlefield classes.
  """
  @spec status_immune?(t()) :: boolean()
  def status_immune?(%__MODULE__{calculated: %Calculated{mode: mode}}),
    do: :status_immune in MobMode.from_mask(mode)

  def status_immune?(%__MODULE__{}), do: false

  @doc "Whether the monster has detector mode, seeing through Hiding and Cloaking."
  @spec detector?(t()) :: boolean()
  def detector?(%__MODULE__{calculated: %Calculated{mode: mode}}),
    do: :detector in MobMode.from_mask(mode)

  def detector?(%__MODULE__{}), do: false

  @impl Aesir.ZoneServer.Unit
  def get_size(%__MODULE__{mob_data: mob_data}) do
    mob_data.size
  end

  @impl Aesir.ZoneServer.Unit
  def get_stats(%__MODULE__{base: base, calculated: calculated} = mob) do
    # The status-effect view of a mob: published primary stats, vitals, level
    # and the calculated combat numbers. Derived combat stats live in
    # `to_combatant/1`.
    %{
      str: calculated.str,
      agi: calculated.agi,
      vit: calculated.vit,
      int: calculated.int,
      dex: calculated.dex,
      luk: calculated.luk,
      # A mob carries no job, equipment or allocated split: its stats are calculated.
      total_stats: primary_stats(calculated),
      unbuffed_stats: primary_stats(base || calculated),
      base_level: get_level(mob),
      job_level: 1,
      hp: mob.hp,
      max_hp: calculated.max_hp,
      sp: mob.sp,
      max_sp: calculated.max_sp,
      atk: calculated.batk,
      matk: calculated.matk_max,
      def: calculated.def,
      mdef: calculated.mdef
    }
  end

  @spec primary_stats(map()) :: %{atom() => integer()}
  defp primary_stats(stats) do
    %{
      str: stats.str,
      agi: stats.agi,
      vit: stats.vit,
      int: stats.int,
      dex: stats.dex,
      luk: stats.luk
    }
  end

  @impl Aesir.ZoneServer.Unit
  def get_entity_info(%__MODULE__{} = mob) do
    Unit.build_entity_info(__MODULE__, mob)
    |> Map.put(:entity_type, :mob)
  end

  @impl Aesir.ZoneServer.Unit
  def get_process_pid(%__MODULE__{process_pid: pid}), do: pid

  @impl Aesir.ZoneServer.Unit
  def get_unit_id(%__MODULE__{instance_id: instance_id}) do
    instance_id
  end

  @impl Aesir.ZoneServer.Unit
  def get_unit_type(_mob) do
    :mob
  end

  @impl Aesir.ZoneServer.Unit
  def get_custom_immunities(%__MODULE__{} = mob) do
    modes = mode_atoms(mob)
    immunities = if :status_immune in modes, do: [:status_immune], else: []

    immunities =
      if :plant in modes do
        # Plant-type mobs are immune to many status effects
        [:stun, :freeze, :stone, :sleep | immunities]
      else
        immunities
      end

    immunities =
      if :undead in modes do
        # Undead mobs have special immunities
        [:blessing, :increase_agi, :decrease_agi | immunities]
      else
        immunities
      end

    immunities
  end

  @impl Aesir.ZoneServer.Unit
  def living?(%__MODULE__{is_dead: false, hp: hp}) when is_integer(hp) and hp > 0, do: true
  def living?(%__MODULE__{}), do: false

  @impl Aesir.ZoneServer.Unit
  def corpse?(%__MODULE__{}), do: false

  @impl Aesir.ZoneServer.Unit
  def to_combatant(%__MODULE__{} = mob_state) do
    mob_data = mob_state.mob_data
    calculated = mob_state.calculated
    {heal_matk_min, heal_matk_max} = heal_matk(mob_state, calculated)

    Combatant.new!(%{
      unit_id: mob_state.instance_id,
      unit_type: :mob,
      social_root: {:mob, mob_state.instance_id},
      reward_root: nil,
      guild_id: mob_state.guild_id,
      base_stats: %{
        str: calculated.str,
        agi: calculated.agi,
        vit: calculated.vit,
        int: calculated.int,
        dex: calculated.dex,
        luk: calculated.luk
      },
      combat_stats: %{
        hit: calculated.hit,
        flee: calculated.flee,
        perfect_dodge: calculated.flee2,
        def: calculated.def,
        soft_def: calculated.def2,
        atk: calculated.batk,
        atk_min: min(calculated.watk_min, calculated.watk_max),
        atk_max: calculated.watk_max,
        matk: calculated.matk_max,
        matk_min: calculated.matk_min,
        matk_max: calculated.matk_max,
        heal_matk_min: heal_matk_min,
        heal_matk_max: heal_matk_max,
        mdef: calculated.mdef,
        soft_mdef: calculated.mdef2,
        ignore_size_penalty: false,
        max_weapon_damage: false
      },
      max_hp: calculated.max_hp,
      max_sp: calculated.max_sp,
      progression: %{
        base_level: get_level(mob_state),
        job_level: 1
      },
      element: {calculated.def_ele, calculated.ele_lv},
      race: calculated.race,
      race2: mob_data.race_groups,
      size: calculated.size,
      weapon: %{
        type: :fist,
        element: calculated.attack_element,
        size: calculated.size
      },
      attack_range: mob_data.attack_range,
      attack_delay_ms: get_attack_delay(mob_state),
      amotion: get_attack_motion(mob_state),
      position: {mob_state.x, mob_state.y},
      map_name: mob_state.map_name,
      class: calculated.class,
      status_immune: status_immune?(mob_state),
      detector: detector?(mob_state),
      ignore_modes:
        Enum.filter(MobMode.from_mask(calculated.mode), &(&1 in Combatant.ignore_modes())),
      monster_id: mob_state.mob_id,
      proc_owner_id: proc_owner_id(mob_state),
      equip_modifiers: %{}
    })
  end

  # A player-owned summon attacks with its master's equipment procs. Monster
  # classes the reference excludes lend nothing, and `summon_kind` is nil for
  # every ordinary spawn.
  defp proc_owner_id(%__MODULE__{summon_kind: kind, owner_player_id: owner})
       when is_atom(kind) and is_integer(owner),
       do: owner

  defp proc_owner_id(%__MODULE__{}), do: nil

  # Renewal Heal adds the database MATK on top of the base bounds again
  # (`skill_calc_heal`'s weapon MATK, with no variance for a monster). The
  # bounds come from the calculated INT and the runtime level, never from the
  # amplified cached MATK band.
  defp heal_matk(mob_state, calculated) do
    data = %{mob_state.mob_data | level: get_level(mob_state)}
    {minimum, maximum} = Mechanics.mob_formulas().magic_attack_bounds(data, calculated.int, %{})
    {minimum + mob_state.mob_data.matk, maximum + mob_state.mob_data.matk}
  end

  # State Management Functions

  @doc """
  Sets the process PID for this mob state.
  """
  @spec set_process_pid(t(), pid()) :: t()
  def set_process_pid(%__MODULE__{} = state, pid) when is_pid(pid) do
    %{state | process_pid: pid}
  end

  @doc """
  Tags this mob state with an OnMyMobDead owner event ref (rAthena
  "Name::OnLabel"), resolved only when the mob dies.
  """
  @spec set_owner_event(t(), String.t() | nil) :: t()
  def set_owner_event(%__MODULE__{} = state, owner_event) do
    %{state | owner_event: owner_event}
  end

  @doc "Advances the generation used to invalidate deferred work."
  @spec advance_deferred_epoch(t()) :: t()
  def advance_deferred_epoch(%__MODULE__{deferred_epoch: epoch} = state) do
    %{state | deferred_epoch: epoch + 1}
  end

  @doc """
  Updates position and handles movement state transitions.
  """
  @spec update_position(t(), integer(), integer()) :: t()
  def update_position(%__MODULE__{} = state, new_x, new_y) do
    %{state | x: new_x, y: new_y}
  end

  @doc """
  Sets a movement path and starts moving.
  """
  @spec set_path(t(), [{integer(), integer()}]) :: t()
  def set_path(%__MODULE__{} = state, path) when is_list(path) do
    if path != [] do
      %{
        state
        | walk_path: path,
          movement_state: :moving
      }
    else
      %{
        state
        | walk_path: path,
          movement_state: :standing
      }
    end
  end

  @doc """
  Stops movement and clears the path.
  """
  @spec stop_movement(t()) :: t()
  def stop_movement(%__MODULE__{} = state) do
    %{
      state
      | walk_path: [],
        movement_state: :standing,
        walk_target: nil,
        walk_easy: false,
        chase_walk: false,
        pending_step: nil
    }
  end

  @spec apply_walk_delay(t(), non_neg_integer(), integer()) :: t()
  def apply_walk_delay(%__MODULE__{} = state, duration, now) do
    %{
      state
      | walk_delay_until: max(active_walk_delay(state.walk_delay_until, now), now + duration)
    }
  end

  @spec walk_delayed?(t(), integer()) :: boolean()
  def walk_delayed?(%__MODULE__{walk_delay_until: 0}, _now), do: false
  def walk_delayed?(%__MODULE__{walk_delay_until: until}, now), do: until > now

  defp active_walk_delay(0, now), do: now
  defp active_walk_delay(until, _now), do: until

  @doc """
  Sets the skill state: an attack state (`:berserk`/`:angry`) or a chase state
  (`:rush`/`:follow`) resolves to its angry form when the mob is aggressive;
  any other state first resets `aggressive` from the angry mode.
  """
  @spec set_state(t(), skill_state()) :: t()
  def set_state(%__MODULE__{aggressive: aggressive} = state, attack)
      when attack in [:berserk, :angry],
      do: %{state | skill_state: if(aggressive, do: :angry, else: :berserk)}

  def set_state(%__MODULE__{aggressive: aggressive} = state, chase)
      when chase in [:rush, :follow],
      do: %{state | skill_state: if(aggressive, do: :follow, else: :rush)}

  def set_state(%__MODULE__{} = state, skill_state)
      when skill_state in [:idle, :walk, :loot, :dead] do
    %{state | skill_state: skill_state, aggressive: :angry in mode_atoms(state)}
  end

  # The mode bits a status can alter live in the calculated snapshot, never in
  # the immutable form definition.
  defp mode_atoms(%__MODULE__{calculated: %Calculated{mode: mode}}),
    do: MobMode.from_mask(mode)

  defp mode_atoms(%__MODULE__{mob_data: %{modes: modes}}), do: modes || []
  defp mode_atoms(%__MODULE__{}), do: []

  @doc """
  Resets the mob as it leaves its map for a warp: the attack and chase orders,
  the attacked event and the spotting players are dropped, its attack and walk
  delays end and the mob goes idle. Its target, and the norm attacked event,
  stay.
  """
  @spec leave_map(t()) :: t()
  def leave_map(%__MODULE__{} = state) do
    %{
      set_state(state, :idle)
      | attack_target: nil,
        attack_timer_at: nil,
        chase_target: nil,
        chase_resume_at: nil,
        attacked_ref: nil,
        spotted_by: MapSet.new(),
        last_attack_time: nil,
        attack_delay_until: nil,
        walk_delay_until: 0
    }
  end

  @doc "Whether the mob is in a chase state."
  @spec chasing?(t()) :: boolean()
  def chasing?(%__MODULE__{skill_state: skill_state}), do: skill_state in [:rush, :follow]

  @doc "Whether the mob's attack timer is armed."
  @spec attacking?(t()) :: boolean()
  def attacking?(%__MODULE__{attack_timer_at: at}), do: at != nil

  @doc "Records the attack order on `target_ref`."
  @spec set_attack_target(t(), Ref.t()) :: t()
  def set_attack_target(%__MODULE__{} = state, target_ref),
    do: %{state | attack_target: target_ref}

  @doc "Arms the attack timer to fire at `at` (ms)."
  @spec arm_attack_timer(t(), integer()) :: t()
  def arm_attack_timer(%__MODULE__{} = state, at), do: %{state | attack_timer_at: at}

  @doc "Drops the standing attack order and its timer."
  @spec stop_attack(t()) :: t()
  def stop_attack(%__MODULE__{} = state), do: %{state | attack_target: nil, attack_timer_at: nil}

  @doc """
  Sets the combat target.
  """
  @spec set_target(t(), Ref.t() | integer() | nil) :: t()
  def set_target(%__MODULE__{} = state, target_id) when is_integer(target_id),
    do: %{state | target_ref: {:player, target_id}}

  def set_target(%__MODULE__{} = state, target_ref), do: %{state | target_ref: target_ref}

  @doc """
  Stores an attacked event: `attacker_ref` becomes the pending attacker (and the
  norm attacker when `norm?`), and the mob leaves its aggressive mode; its
  skill state stays as it is until it next changes.
  """
  @spec set_attacked(t(), Ref.t(), boolean()) :: t()
  def set_attacked(%__MODULE__{} = state, attacker_ref, norm?) do
    norm_ref = if norm?, do: attacker_ref, else: state.norm_attacked_ref
    %{state | attacked_ref: attacker_ref, norm_attacked_ref: norm_ref, aggressive: false}
  end

  @doc "The mob's skill state."
  @spec skill_state(t()) :: skill_state()
  def skill_state(%__MODULE__{skill_state: skill_state}), do: skill_state

  @doc "Clears the pending attacked event."
  @spec clear_attacked(t()) :: t()
  def clear_attacked(%__MODULE__{} = state),
    do: %{state | attacked_ref: nil, norm_attacked_ref: nil}

  @doc """
  Records the attack-type classification and skill id (`nil` for a basic
  attack) of an incoming hit, keyed by its attacker, so the death path can grant
  the killer the matching on-kill HP/SP gains. Overwrites any prior entry for
  the same attacker.
  """
  @spec note_hit_type(t(), term(), :melee | :ranged | :magic, integer() | nil) :: t()
  def note_hit_type(%__MODULE__{last_hit_types: types} = state, attacker, bf, skill_id) do
    %{state | last_hit_types: Map.put(types, attacker, {bf, skill_id})}
  end

  @doc """
  Returns the recorded attack-type classification of `attacker`'s most recent
  hit, or `:other` when none was recorded (no gain-eligible blow).
  """
  @spec hit_type(t(), term()) :: :melee | :ranged | :magic | :other
  def hit_type(%__MODULE__{last_hit_types: types}, attacker) do
    case Map.get(types, attacker) do
      {bf, _skill_id} -> bf
      nil -> :other
    end
  end

  @doc """
  Returns the skill id of `attacker`'s most recent recorded hit, or `nil` for a
  basic attack or when none was recorded.
  """
  @spec hit_skill(t(), term()) :: integer() | nil
  def hit_skill(%__MODULE__{last_hit_types: types}, attacker) do
    case Map.get(types, attacker) do
      {_bf, skill_id} -> skill_id
      nil -> nil
    end
  end

  @doc """
  Records the per-skill cooldown gate: stores `expires_at` for `skill_id`.
  `expires_at` is a millisecond timestamp in the same domain the caller uses
  for `skill_ready?/3`, following `Aesir.ZoneServer.Mmo.Skill.Cooldown`'s
  clock-agnostic lazy-comparison model (no time is read here).
  """
  @spec put_skill_cooldown(t(), integer(), integer()) :: t()
  def put_skill_cooldown(%__MODULE__{skill_cooldowns: cooldowns} = state, skill_id, expires_at) do
    %{state | skill_cooldowns: Map.put(cooldowns, skill_id, expires_at)}
  end

  @doc "Drops every per-skill cooldown gate: the monster may immediately reuse any skill."
  @spec clear_skill_cooldowns(t()) :: t()
  def clear_skill_cooldowns(%__MODULE__{} = state), do: %{state | skill_cooldowns: %{}}

  @doc """
  Returns `true` when `skill_id` has no cooldown entry or `now` has reached
  the recorded `expires_at`. `now` is a millisecond timestamp in the same
  domain as `put_skill_cooldown/3`.
  """
  @spec skill_ready?(t(), integer(), integer()) :: boolean()
  def skill_ready?(%__MODULE__{skill_cooldowns: cooldowns}, skill_id, now) do
    case Map.fetch(cooldowns, skill_id) do
      :error -> true
      {:ok, expires_at} -> now >= expires_at
    end
  end

  @doc """
  Sets the in-progress cast descriptor (`%{row: row, complete_at: ms,
  timer_ref: ref}`), or `nil` to indicate no cast. `timer_ref` is the pending
  `{:casting, :complete}` timer, kept so a status effect that prevents skill
  use can interrupt it. The target is not captured here; it is re-resolved fresh at
  `{:casting, :complete}` so a stale target aborts instead of firing.
  """
  @spec set_casting(t(), map() | nil) :: t()
  def set_casting(%__MODULE__{} = state, casting) do
    %{state | casting: casting}
  end

  @doc """
  Clears the in-progress cast descriptor.
  """
  @spec clear_casting(t()) :: t()
  def clear_casting(%__MODULE__{} = state) do
    %{state | casting: nil}
  end

  @doc """
  Links this mob to its summoner by instance id (used by slave summons for
  owner-death events and the `slavele` skill condition).
  """
  @spec set_master(t(), integer() | nil) :: t()
  def set_master(%__MODULE__{} = state, master_id) do
    %{state | master_id: master_id}
  end

  @doc """
  Configures player summon ownership, reward policy, optional HP override, and
  an optional flat DEF/MDEF stat bonus.

  `guardian_recalculation` runs the full post-spawn calculation a guardian's
  spawn performs, which folds its base attack-speed adjustment into its motion.
  """
  @spec configure_summon(t(), keyword()) :: t()
  def configure_summon(%__MODULE__{} = state, opts) do
    state =
      %{
        state
        | owner_player_id: Keyword.get(opts, :owner_player_id),
          summon_kind: Keyword.get(opts, :summon_kind),
          guild_id: Keyword.get(opts, :guild_id, 0),
          no_exp: Keyword.get(opts, :no_exp, false),
          no_drops: Keyword.get(opts, :no_drops, false)
      }

    level = if state.level in 1..275, do: state.level, else: state.mob_data.level
    state = %{state | level: level}
    base = Stats.prepare_base(state, opts)
    seeded = %{state | base: base}

    calculated =
      if Keyword.get(opts, :guardian_recalculation, false),
        do: Stats.recalculate_spawn(seeded),
        else: base

    %{seeded | calculated: calculated, hp: calculated.max_hp, sp: calculated.max_sp}
  end

  @doc """
  Adopts `definition` as the monster's current form: the form identity and data
  change, while the runtime level is kept when it is a level the monster may
  hold and the replacement's level is adopted otherwise.
  """
  @spec change_form(t(), MobDefinition.t()) :: t()
  def change_form(%__MODULE__{} = state, %MobDefinition{} = definition) do
    level = if state.level in 1..275, do: state.level, else: definition.level

    %{state | mob_id: definition.id, mob_data: definition, level: level}
  end

  @doc """
  Marks the mob as having been stolen from.
  """
  @spec mark_stolen(t()) :: t()
  def mark_stolen(%__MODULE__{} = state) do
    %{state | stolen_from: true}
  end

  @doc """
  Marks the mob as having had its zeny stolen.
  """
  @spec mark_coin_stolen(t()) :: t()
  def mark_coin_stolen(%__MODULE__{} = state) do
    %{state | coin_stolen: true}
  end

  @doc """
  Adds or updates aggro for a target.
  """
  @spec add_aggro(t(), integer(), integer()) :: t()
  def add_aggro(
        %__MODULE__{aggro_list: aggro_list, aggro_order: aggro_order} = state,
        target_id,
        damage
      ) do
    current_aggro = Map.get(aggro_list, target_id, 0)
    updated_aggro = Map.put(aggro_list, target_id, current_aggro + damage)

    updated_aggro_order =
      if target_id in aggro_order, do: aggro_order, else: [target_id | aggro_order]

    %{state | aggro_list: updated_aggro, aggro_order: updated_aggro_order}
  end

  @doc "Records cumulative damage and hit-time reward ownership by exact typed contributor."
  @spec add_typed_aggro(t(), Ref.t(), integer() | nil, integer()) :: t()
  def add_typed_aggro(
        %__MODULE__{typed_aggro_list: aggro, typed_aggro_order: order} = state,
        {source_type, _id} = contributor_ref,
        reward_owner_id,
        damage
      ) do
    {updated, updated_order} =
      case Map.fetch(aggro, contributor_ref) do
        {:ok, entry} ->
          {Map.put(aggro, contributor_ref, %{entry | damage: entry.damage + damage}), order}

        :error ->
          entry = %{
            contributor: contributor_ref,
            source_type: source_type,
            reward_owner_id: reward_owner_id,
            damage: damage,
            first_hit_order: length(order)
          }

          {Map.put(aggro, contributor_ref, entry), [contributor_ref | order]}
      end

    %{state | typed_aggro_list: updated, typed_aggro_order: updated_order}
  end

  @doc "Returns typed cumulative contributors in stable first-hit order."
  @spec typed_damage_log(t()) :: [map()]
  def typed_damage_log(%__MODULE__{typed_aggro_list: aggro, typed_aggro_order: order}) do
    Enum.map(Enum.reverse(order), &Map.fetch!(aggro, &1))
  end

  @doc """
  Returns the rAthena-style damage log used for loot-owner ranking.
  """
  @spec damage_log(t()) :: [{integer(), integer()}]
  def damage_log(%__MODULE__{aggro_list: aggro_list, aggro_order: aggro_order}) do
    Enum.map(Enum.reverse(aggro_order), fn attacker_id ->
      {attacker_id, Map.fetch!(aggro_list, attacker_id)}
    end)
  end

  @doc "Returns the exact typed contributor with the highest aggro."
  @spec get_highest_typed_aggro_target(t()) :: Ref.t() | nil
  def get_highest_typed_aggro_target(%__MODULE__{} = state) do
    case Enum.max_by(typed_damage_log(state), & &1.damage, fn -> nil end) do
      %{contributor: target_ref} -> target_ref
      nil -> nil
    end
  end

  @doc """
  Gets the highest aggro target.
  """
  @spec get_highest_aggro_target(t()) :: integer() | nil
  def get_highest_aggro_target(%__MODULE__{aggro_list: aggro_list}) do
    case Enum.max_by(aggro_list, fn {_id, aggro} -> aggro end, fn -> nil end) do
      {target_id, _aggro} -> target_id
      nil -> nil
    end
  end

  @doc """
  Clears all aggro.
  """
  @spec clear_aggro(t()) :: t()
  def clear_aggro(%__MODULE__{} = state) do
    %{state | aggro_list: %{}, aggro_order: [], typed_aggro_list: %{}, typed_aggro_order: []}
  end

  @doc """
  Marks the mob as dead.
  """
  @spec set_dead(t()) :: t()
  def set_dead(%__MODULE__{} = state) do
    %{
      state
      | is_dead: true,
        hp: 0,
        skill_state: :dead,
        attack_target: nil,
        attack_timer_at: nil,
        chase_target: nil,
        target_ref: nil,
        aggro_list: %{},
        aggro_order: [],
        typed_aggro_list: %{},
        typed_aggro_order: [],
        movement_state: :standing,
        walk_path: [],
        pending_step: nil,
        walk_target: nil
    }
  end

  @doc """
  Updates direction based on movement or target.
  """
  @spec update_direction(t(), integer()) :: t()
  def update_direction(%__MODULE__{} = state, new_dir) when new_dir in 0..7 do
    %{state | dir: new_dir}
  end

  # Public API Functions

  @doc """
  Gets the mob's current position.
  """
  @spec get_position(t()) :: {integer(), integer()}
  def get_position(%__MODULE__{x: x, y: y}), do: {x, y}

  @doc """
  Applies damage to the mob.
  """
  @spec apply_damage(t(), integer()) :: {t(), :alive | :dead}
  def apply_damage(%__MODULE__{hp: current_hp} = mob, damage) do
    new_hp = max(0, current_hp - damage)
    updated_mob = %{mob | hp: new_hp}

    if new_hp == 0 do
      {updated_mob, :dead}
    else
      {updated_mob, :alive}
    end
  end

  @doc """
  Checks if the mob should be aggressive towards players.
  """
  @spec aggressive?(t()) :: boolean()
  def aggressive?(%__MODULE__{calculated: %Calculated{mode: mode}}),
    do: :aggressive in MobMode.from_mask(mode)

  def aggressive?(%__MODULE__{mob_data: mob_data}), do: :aggressive in (mob_data.modes || [])

  @doc """
  Gets the mob's attack range.
  """
  @spec get_attack_range(t()) :: integer()
  def get_attack_range(%__MODULE__{mob_data: mob_data}) do
    mob_data.attack_range
  end

  @doc """
  Gets the mob's chase range.
  """
  @spec get_chase_range(t()) :: integer()
  def get_chase_range(%__MODULE__{mob_data: mob_data}) do
    mob_data.chase_range
  end

  @min_amotion 100
  @max_motion 8_000

  @doc """
  Gets the mob's attack delay in milliseconds: its database delay scaled by an
  `aspd_rate` bonus that only ever shortens it, kept between its attack motion
  and 8000.
  """
  @spec get_attack_delay(t()) :: integer()
  def get_attack_delay(%__MODULE__{calculated: %Calculated{adelay: adelay, amotion: amotion}}) do
    adelay |> max(amotion) |> min(@max_motion)
  end

  @doc """
  Starts the monster's attack delay from `now` (ms), never shortening a
  deadline an earlier delay already established.
  """
  @spec start_attack_delay(t(), integer()) :: t()
  def start_attack_delay(%__MODULE__{} = state, now) do
    deadline = now + get_attack_delay(state)

    %{
      state
      | last_attack_time: now,
        attack_delay_until: max(state.attack_delay_until || deadline, deadline)
    }
  end

  @doc """
  Gets the mob's attack motion in milliseconds: its calculated motion, kept
  between 100 and 8000.
  """
  @spec get_attack_motion(t()) :: integer()
  def get_attack_motion(%__MODULE__{calculated: %Calculated{amotion: amotion}}) do
    amotion |> max(@min_amotion) |> min(@max_motion)
  end

  @doc """
  Rests the mob's AI for its attack motion from `now` (ms), never shortening a
  longer rest.
  """
  @spec rest(t(), integer()) :: t()
  def rest(%__MODULE__{} = state, now) do
    %{state | next_think_at: max(now + get_attack_motion(state), state.next_think_at || now)}
  end

  @doc "Whether the mob's AI may think at `now` (ms)."
  @spec thinking?(t(), integer()) :: boolean()
  def thinking?(%__MODULE__{next_think_at: nil}, _now), do: true
  def thinking?(%__MODULE__{next_think_at: next}, now), do: now >= next
end

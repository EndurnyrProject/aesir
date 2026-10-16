defmodule Aesir.ZoneServer.Unit.Mob.MobState do
  @moduledoc """
  Represents the state of a mob entity in the game world.
  Implements the Entity behaviour for status effect calculations.
  Similar to PlayerState but for monsters with AI and combat capabilities.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ElementalChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Ref

  @behaviour Aesir.ZoneServer.Unit

  @type ai_state :: :idle | :alert | :combat | :chase | :return
  @type movement_state :: :standing | :moving | :returning
  @type stat_bonus :: %{
          optional(:def) => integer(),
          optional(:mdef) => integer(),
          optional(:atk) => integer(),
          optional(:aspd_rate) => 0..100
        }

  @enforce_keys [
    :instance_id,
    :mob_id,
    :mob_data,
    :spawn_ref,
    :x,
    :y,
    :map_name,
    :hp,
    :max_hp,
    :sp,
    :max_sp,
    :spawned_at
  ]
  defstruct [
    # Core identification
    instance_id: nil,
    mob_id: nil,
    mob_data: nil,
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
    walk_speed: 200,
    walk_delay_until: 0,
    target_position: nil,
    # The step the walk scheduled last, read by the hit stop (`HitStop`).
    pending_step: nil,
    # An escape walk that damage cannot stop; it ends when the walk does.
    can_escape: false,

    # AI state machine
    ai_state: :idle,
    ai_awake: true,
    ai_timer_ref: nil,
    # The cell the mob actually spawned on. AI wander/return anchors here, not
    # on `spawn_ref.spawn_area`, whose 0,0 means "random cell anywhere".
    spawn_point: nil,
    target_ref: nil,
    # true when aggro was acquired by the aggressive scan (mob walked up to a
    # target that has not hit it), false when acquired by taking damage. Reads
    # the `angry` vs `attack` skill-state distinction.
    initiated_by_self?: false,
    # true once an attacked event has taken the mob out of its aggressive mode:
    # its skill state keeps `initiated_by_self?` until its next state change or
    # attack (`settle_skill_state/1`), which then clears it.
    left_aggressive?: false,
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
    owner_player_id: nil,
    guild_id: 0,
    stat_bonus: %{},
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
    last_movement_end_time: nil,
    last_idle_movement_time: nil,
    last_attack_time: nil,
    # The AI does not think before this time (ms): after an attack or a cast's
    # end it rests for its attack motion.
    next_think_at: nil,

    # Combat state
    hp: nil,
    max_hp: nil,
    # Immutable un-buffed HP ceiling. `max_hp` tracks the effective ceiling
    # after `:max_hp_rate` statuses (e.g. SC_DELUGE); this is what the recalc
    # scales from so a buff never compounds on a previous buff.
    base_max_hp: nil,
    sp: nil,
    max_sp: nil,
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
          mob_data: MobDefinition.t(),
          spawn_ref: MobSpawn.t(),
          process_pid: pid() | nil,
          x: integer(),
          y: integer(),
          map_name: String.t(),
          dir: integer(),
          movement_state: movement_state(),
          walk_path: list(),
          walk_speed: integer(),
          walk_delay_until: integer(),
          target_position: {integer(), integer()} | nil,
          pending_step: HitStop.step(),
          can_escape: boolean(),
          ai_state: ai_state(),
          ai_awake: boolean(),
          ai_timer_ref: reference() | nil,
          spawn_point: {integer(), integer()} | nil,
          target_ref: Ref.t() | nil,
          initiated_by_self?: boolean(),
          left_aggressive?: boolean(),
          attacked_ref: Ref.t() | nil,
          norm_attacked_ref: Ref.t() | nil,
          attacked_count: non_neg_integer(),
          skill_cooldowns: %{optional(integer()) => integer()},
          casting: map() | nil,
          master_id: integer() | nil,
          owner_player_id: integer() | nil,
          guild_id: non_neg_integer(),
          stat_bonus: stat_bonus(),
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
          last_movement_end_time: integer() | nil,
          last_idle_movement_time: integer() | nil,
          last_attack_time: integer() | nil,
          next_think_at: integer() | nil,
          hp: integer(),
          max_hp: integer(),
          base_max_hp: integer() | nil,
          sp: integer(),
          max_sp: integer(),
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

    %__MODULE__{
      instance_id: instance_id,
      mob_id: mob_data.id,
      mob_data: mob_data,
      spawn_ref: spawn_ref,
      map_name: map_name,
      x: x,
      y: y,
      spawn_point: {x, y},
      hp: max(mob_data.hp, 1),
      max_hp: max(mob_data.hp, 1),
      base_max_hp: max(mob_data.hp, 1),
      sp: mob_data.sp,
      max_sp: mob_data.sp,
      spawned_at: current_time,
      last_ai_tick: current_time,
      status_effects: %{},
      walk_speed: mob_data.walk_speed,
      view_range: calculate_view_range(mob_data),
      respawn_delay: spawn_ref.respawn_time
    }
  end

  @impl Aesir.ZoneServer.Unit
  def get_race(%__MODULE__{mob_data: mob_data}) do
    mob_data.race
  end

  # Reads the `:sc_elementalchange` entry directly instead of going through
  # `Interpreter.get_all_modifiers/2`: that path builds a context for every
  # active status via `ContextBuilder.get_unit_stats/2`, which calls back into
  # `UnitRegistry.get_unit_info/2` -> `get_entity_info/1` ->
  # `Unit.build_entity_info/2` -> this very function. Routing through the
  # aggregator here would recurse forever the moment the mob carries any
  # active status at all.
  @impl Aesir.ZoneServer.Unit
  def get_element(%__MODULE__{instance_id: instance_id, mob_data: %{element: element}}) do
    case StatusStorage.get_status(:mob, instance_id, :sc_elementalchange) do
      nil -> element
      instance -> ElementalChange.modifiers(instance, %{}).element_override
    end
  end

  @impl Aesir.ZoneServer.Unit
  def is_boss?(%__MODULE__{mob_data: mob_data}) do
    :boss in (mob_data.modes || [])
  end

  @doc """
  Whether the monster is status-immune (MD_STATUSIMMUNE): the boss, guardian
  and battlefield classes.
  """
  @spec status_immune?(t()) :: boolean()
  def status_immune?(%__MODULE__{mob_data: mob_data}),
    do: :status_immune in (mob_data.modes || [])

  @doc "Whether the monster has detector mode, seeing through Hiding and Cloaking."
  @spec detector?(t()) :: boolean()
  def detector?(%__MODULE__{mob_data: mob_data}), do: :detector in (mob_data.modes || [])

  @impl Aesir.ZoneServer.Unit
  def get_size(%__MODULE__{mob_data: mob_data}) do
    mob_data.size
  end

  @impl Aesir.ZoneServer.Unit
  def get_stats(%__MODULE__{mob_data: mob_data} = mob) do
    # The status-effect view of a mob: primary stats, vitals, level and the
    # database combat numbers. Derived combat stats live in `to_combatant/1`.
    %{
      str: mob_data.stats.str,
      agi: mob_data.stats.agi,
      vit: mob_data.stats.vit,
      int: mob_data.stats.int,
      dex: mob_data.stats.dex,
      luk: mob_data.stats.luk,
      # A mob carries no job, equipment or allocated split: its stats are calculated.
      total_stats: primary_stats(mob_data.stats),
      unbuffed_stats: primary_stats(mob_data.stats),
      base_level: mob_data.level,
      job_level: 1,
      hp: mob.hp,
      max_hp: mob.max_hp,
      sp: mob.sp,
      max_sp: mob.max_sp,
      atk: mob_data.atk,
      matk: mob_data.matk,
      def: mob_data.def,
      mdef: mob_data.mdef
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
  def get_custom_immunities(%__MODULE__{mob_data: mob_data}) do
    modes = mob_data.modes || []
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
    formulas = Mechanics.mob_formulas()
    modifiers = Interpreter.get_all_modifiers(:mob, mob_state.instance_id)

    stat_bonus = mob_state.stat_bonus
    str = mob_data.stats.str + modifier(modifiers, :str)
    int = mob_data.stats.int + modifier(modifiers, :int)
    guard_up = Map.get(stat_bonus, :atk, 0)
    {atk_min, atk_max} = formulas.attack_bounds(mob_data, modifiers)
    atk_max = atk_max + guard_up
    {matk_min, matk_max} = formulas.magic_attack_bounds(mob_data, int, modifiers)
    # Renewal Heal adds the database MATK on top of the base bounds again
    # (`skill_calc_heal`'s weapon MATK, no variance for a monster).
    {heal_matk_min, heal_matk_max} = formulas.magic_attack_bounds(mob_data, int, %{})

    {heal_matk_min, heal_matk_max} =
      {heal_matk_min + mob_data.matk, heal_matk_max + mob_data.matk}

    Combatant.new!(%{
      unit_id: mob_state.instance_id,
      unit_type: :mob,
      social_root: {:mob, mob_state.instance_id},
      reward_root: nil,
      guild_id: mob_state.guild_id,
      base_stats: %{
        str: str,
        agi: mob_data.stats.agi + modifier(modifiers, :agi),
        vit: mob_data.stats.vit + modifier(modifiers, :vit),
        int: int,
        dex: mob_data.stats.dex + modifier(modifiers, :dex),
        luk: mob_data.stats.luk + modifier(modifiers, :luk)
      },
      combat_stats: %{
        hit: formulas.calculate_hit(mob_data) + modifier(modifiers, :hit),
        flee:
          max(
            div(
              (formulas.calculate_flee(mob_data) + modifier(modifiers, :flee)) *
                (100 + modifier(modifiers, :flee_rate)),
              100
            ),
            1
          ),
        perfect_dodge: formulas.calculate_perfect_dodge(mob_data),
        def:
          formulas.calculate_defense(mob_data) + modifier(modifiers, :def) +
            Map.get(stat_bonus, :def, 0),
        soft_def: formulas.calculate_soft_defense(mob_data),
        atk: formulas.status_attack(mob_data, str, guard_up, modifiers),
        atk_min: min(atk_min + guard_up, atk_max),
        atk_max: atk_max,
        matk: matk_max,
        matk_min: matk_min,
        matk_max: matk_max,
        heal_matk_min: heal_matk_min,
        heal_matk_max: heal_matk_max,
        mdef:
          formulas.calculate_magic_defense(mob_data) + modifier(modifiers, :mdef) +
            Map.get(stat_bonus, :mdef, 0),
        soft_mdef:
          apply_rate(formulas.calculate_soft_mdef(mob_data), modifier(modifiers, :mdef2_rate)),
        ignore_size_penalty: false,
        max_weapon_damage: false
      },
      max_hp: mob_state.max_hp,
      max_sp: mob_state.max_sp,
      progression: %{
        base_level: mob_data.level,
        job_level: 1
      },
      element: Map.get(modifiers, :element_override, mob_data.element),
      race: mob_data.race,
      race2: mob_data.race_groups,
      size: mob_data.size,
      weapon: %{
        type: :fist,
        element: elem(mob_data.element, 0),
        size: mob_data.size
      },
      attack_range: mob_data.attack_range,
      attack_delay_ms: get_attack_delay(mob_state),
      amotion: get_attack_motion(mob_state),
      position: {mob_state.x, mob_state.y},
      map_name: mob_state.map_name,
      class: if(is_boss?(mob_state), do: :boss, else: :normal),
      status_immune: :status_immune in mob_data.modes,
      detector: detector?(mob_state),
      monster_id: mob_state.mob_id,
      equip_modifiers: %{}
    })
  end

  # State Management Functions

  @doc """
  Recomputes `max_hp` from the immutable `base_max_hp` and the unit's aggregated
  `:max_hp_rate` status modifier (e.g. SC_DELUGE), then clamps current HP to the
  new ceiling.

  Mirrors rAthena's `status_calc_maxhp` for non-PC units (`status.cpp:6213`,
  `status.cpp:8712`): a buff raises the ceiling without healing, and its removal
  caps any overflow HP back down. Unlike a player's cached stats, every other
  mob combat number is folded live in `to_combatant/1`, so only the stored HP
  ceiling needs an explicit recompute.
  """
  @spec recalculate_max_hp(t()) :: t()
  def recalculate_max_hp(%__MODULE__{instance_id: instance_id} = state) do
    base = state.base_max_hp || state.max_hp
    rate = :mob |> Interpreter.get_all_modifiers(instance_id) |> Map.get(:max_hp_rate, 0)
    new_max = max(1, div(base * (100 + rate), 100))
    %{state | max_hp: new_max, hp: min(state.hp, new_max)}
  end

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
        target_position: nil,
        pending_step: nil,
        last_movement_end_time: System.system_time(:millisecond)
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
  Sets the AI state, settling the skill state (`settle_skill_state/1`).
  """
  @spec set_ai_state(t(), ai_state()) :: t()
  def set_ai_state(%__MODULE__{} = state, new_ai_state) do
    settle_skill_state(%{
      state
      | ai_state: new_ai_state,
        last_ai_tick: System.system_time(:second)
    })
  end

  @doc """
  Applies a pending exit from the aggressive mode: a mob that was attacked
  since its last state change or attack is no longer self-initiated. Called on
  every AI state change and every attack the mob orders.
  """
  @spec settle_skill_state(t()) :: t()
  def settle_skill_state(%__MODULE__{left_aggressive?: true} = state),
    do: %{state | initiated_by_self?: false, left_aggressive?: false}

  def settle_skill_state(%__MODULE__{} = state), do: state

  @doc """
  Sets the combat target.
  """
  @spec set_target(t(), Ref.t() | integer() | nil) :: t()
  def set_target(%__MODULE__{} = state, target_id) when is_integer(target_id),
    do: %{state | target_ref: {:player, target_id}}

  def set_target(%__MODULE__{} = state, target_ref), do: %{state | target_ref: target_ref}

  @doc """
  Records whether the mob initiated combat itself (aggressive scan) or is
  retaliating after taking damage.
  """
  @spec set_initiated(t(), boolean()) :: t()
  def set_initiated(%__MODULE__{} = state, initiated_by_self?)
      when is_boolean(initiated_by_self?) do
    %{state | initiated_by_self?: initiated_by_self?}
  end

  @doc """
  Stores an attacked event: `attacker_ref` becomes the pending attacker (and the
  norm attacker when `norm?`), and the mob leaves its aggressive mode. Its
  skill state stays as it is until it next changes state or attacks
  (`settle_skill_state/1`), so the think of the event still sees it.
  """
  @spec set_attacked(t(), Ref.t(), boolean()) :: t()
  def set_attacked(%__MODULE__{} = state, attacker_ref, norm?) do
    norm_ref = if norm?, do: attacker_ref, else: state.norm_attacked_ref
    %{state | attacked_ref: attacker_ref, norm_attacked_ref: norm_ref, left_aggressive?: true}
  end

  @doc """
  The mob skill state the AI state stands for: combat is `:angry` when the mob
  initiated it, else `:berserk` (the attack state); chase is `:follow` or
  `:rush` the same way; idle and alert are `:idle`; return is `:walk`.
  """
  @spec skill_state(t()) :: :berserk | :angry | :rush | :follow | :idle | :walk
  def skill_state(%__MODULE__{ai_state: :combat, initiated_by_self?: true}), do: :angry
  def skill_state(%__MODULE__{ai_state: :combat}), do: :berserk
  def skill_state(%__MODULE__{ai_state: :chase, initiated_by_self?: true}), do: :follow
  def skill_state(%__MODULE__{ai_state: :chase}), do: :rush
  def skill_state(%__MODULE__{ai_state: :return}), do: :walk
  def skill_state(%__MODULE__{}), do: :idle

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
  """
  @spec configure_summon(t(), keyword()) :: t()
  def configure_summon(%__MODULE__{} = state, opts) do
    state =
      %{
        state
        | owner_player_id: Keyword.get(opts, :owner_player_id),
          guild_id: Keyword.get(opts, :guild_id, 0),
          no_exp: Keyword.get(opts, :no_exp, false),
          no_drops: Keyword.get(opts, :no_drops, false),
          stat_bonus: Keyword.get(opts, :stat_bonus, %{})
      }

    case Keyword.get(opts, :hp_override) do
      nil -> state
      hp -> %{state | hp: hp, max_hp: hp, base_max_hp: hp}
    end
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
        ai_state: :idle,
        target_ref: nil,
        aggro_list: %{},
        aggro_order: [],
        typed_aggro_list: %{},
        typed_aggro_order: [],
        movement_state: :standing,
        walk_path: []
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
  def aggressive?(%__MODULE__{mob_data: mob_data}) do
    :aggressive in (mob_data.modes || [])
  end

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
  def get_attack_delay(%__MODULE__{mob_data: mob_data, stat_bonus: stat_bonus} = state) do
    rate = max(Map.get(stat_bonus, :aspd_rate, 0), 0)

    (mob_data.attack_delay * (100 - rate))
    |> div(100)
    |> max(get_attack_motion(state))
    |> min(@max_motion)
  end

  @doc """
  Gets the mob's attack motion in milliseconds: its database motion scaled by
  its `aspd_rate` bonus, kept between 100 and 8000.
  """
  @spec get_attack_motion(t()) :: integer()
  def get_attack_motion(%__MODULE__{mob_data: mob_data, stat_bonus: stat_bonus}) do
    rate = Map.get(stat_bonus, :aspd_rate, 0)

    (mob_data.attack_motion * (100 - rate))
    |> div(100)
    |> max(@min_amotion)
    |> min(@max_motion)
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

  # Private Helper Functions

  defp calculate_view_range(mob_data) do
    # Base view range, bosses have larger range
    if :boss in (mob_data.modes || []) do
      20
    else
      12
    end
  end

  defp modifier(modifiers, key), do: Map.get(modifiers, key, 0)

  defp apply_rate(value, rate), do: div(value * (100 + rate), 100)
end

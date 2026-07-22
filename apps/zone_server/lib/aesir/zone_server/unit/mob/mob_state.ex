defmodule Aesir.ZoneServer.Unit.Mob.MobState do
  @moduledoc """
  Represents the state of a mob entity in the game world.
  Implements the Entity behaviour for status effect calculations.
  Similar to PlayerState but for monsters with AI and combat capabilities.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ElementalChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.CombatCalculations, as: MobCombatCalc

  @behaviour Aesir.ZoneServer.Unit

  @type ai_state :: :idle | :alert | :combat | :chase | :return
  @type movement_state :: :standing | :moving | :returning

  typedstruct do
    # Core identification
    field :instance_id, integer(), enforce: true
    field :mob_id, integer(), enforce: true
    field :mob_data, MobDefinition.t(), enforce: true
    field :spawn_ref, MobSpawn.t(), enforce: true
    field :process_pid, pid() | nil, default: nil

    # Position & Movement
    field :x, integer(), enforce: true
    field :y, integer(), enforce: true
    field :map_name, String.t(), enforce: true
    field :dir, integer(), default: 0

    # Movement state machine
    field :movement_state, movement_state(), default: :standing
    field :walk_path, list(), default: []
    field :walk_speed, integer(), default: 200
    field :walk_delay_until, integer(), default: 0
    field :target_position, {integer(), integer()} | nil, default: nil

    # AI state machine
    field :ai_state, ai_state(), default: :idle
    field :ai_awake, boolean(), default: true
    field :ai_timer_ref, reference() | nil, default: nil
    # The cell the mob actually spawned on. AI wander/return anchors here, not
    # on `spawn_ref.spawn_area`, whose 0,0 means "random cell anywhere".
    field :spawn_point, {integer(), integer()} | nil, default: nil
    field :target_id, integer() | nil, default: nil
    # true when aggro was acquired by the aggressive scan (mob walked up to a
    # target that has not hit it), false when acquired by taking damage. Reads
    # the `angry` vs `attack` skill-state distinction.
    field :initiated_by_self?, boolean(), default: false
    # Cumulative count of hits taken from beyond chase_range, plus a transient
    # per-reaction flag. Phase 2's `rudeattacked` skill condition consumes them;
    # Phase 1 only records the signal (no teleport/flee).
    field :rude_attack_count, integer(), default: 0
    field :rude_attacked?, boolean(), default: false
    # Per-skill cooldown gate: `skill_name => expires_at` in the same
    # millisecond timestamp domain as the melee `last_attack_time` delay. The
    # `casting` map (`%{row: row, complete_at: ms, timer_ref: ref}`) marks an
    # in-progress cast; `timer_ref` is the pending `{:casting, :complete}` timer
    # so an interruption can cancel it. `master_id` links a summoned slave back
    # to its summoner's instance id.
    field :skill_cooldowns, %{optional(String.t()) => integer()}, default: %{}
    field :casting, map() | nil, default: nil
    field :master_id, integer() | nil, default: nil
    # True until the first AI tick after spawn has run skill selection; that
    # tick selects with the `:spawn` event so `onspawn` rows can fire.
    field :spawn_tick_pending?, boolean(), default: true
    field :last_ai_tick, integer() | nil, default: nil
    field :aggro_list, map(), default: %{}
    field :last_action_time, integer() | nil, default: nil
    field :last_movement_end_time, integer() | nil, default: nil
    field :last_idle_movement_time, integer() | nil, default: nil
    field :last_attack_time, integer() | nil, default: nil

    # Combat state
    field :hp, integer(), enforce: true
    field :max_hp, integer(), enforce: true
    field :sp, integer(), enforce: true
    field :max_sp, integer(), enforce: true
    field :is_dead, boolean(), default: false

    # Spatial awareness
    field :view_range, integer(), default: 12
    field :visible_entities, MapSet.t(), default: %MapSet{}

    # Lifecycle
    field :spawned_at, integer(), enforce: true
    field :last_damage_time, integer() | nil, default: nil
    field :respawn_delay, integer(), default: 0

    # Status effects
    field :status_effects, map(), default: %{}

    # Skill interaction flags
    field :stolen_from, boolean(), default: false

    # OnMyMobDead owner event (rAthena): a raw "Name::OnLabel" ref threaded
    # through from the summoning op's `event:` opt, resolved only at death
    # time. `nil` for every ordinary spawn -- exactly today's behavior.
    field :owner_event, String.t() | nil, default: nil
  end

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
      hp: mob_data.hp,
      max_hp: mob_data.hp,
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

  @impl Aesir.ZoneServer.Unit
  def get_size(%__MODULE__{mob_data: mob_data}) do
    mob_data.size
  end

  @impl Aesir.ZoneServer.Unit
  def get_stats(%__MODULE__{mob_data: mob_data} = mob) do
    # Return stats in the format expected by status effect formulas
    %{
      str: mob_data.stats.str,
      agi: mob_data.stats.agi,
      vit: mob_data.stats.vit,
      int: mob_data.stats.int,
      dex: mob_data.stats.dex,
      luk: mob_data.stats.luk,
      base_level: mob_data.level,
      job_level: 1,
      hp: mob.hp,
      max_hp: mob.max_hp,
      sp: mob.sp,
      max_sp: mob.max_sp,
      atk: mob_data.atk,
      matk: mob_data.matk,
      def: mob_data.def,
      mdef: mob_data.mdef,
      hit: calculate_hit(mob_data),
      flee: calculate_flee(mob_data),
      crit: calculate_crit(mob_data),
      aspd: calculate_aspd(mob_data)
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
    # Check mob modes for special immunities
    immunities = []

    immunities =
      if :plant in (mob_data.modes || []) do
        # Plant-type mobs are immune to many status effects
        [:stun, :freeze, :stone, :sleep | immunities]
      else
        immunities
      end

    immunities =
      if :undead in (mob_data.modes || []) do
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
    mob_matk = MobCombatCalc.calculate_magic_attack(mob_data)
    modifiers = Interpreter.get_all_modifiers(:mob, mob_state.instance_id)

    Combatant.new!(%{
      unit_id: mob_state.instance_id,
      unit_type: :mob,
      base_stats: %{
        str: mob_data.stats.str + modifier(modifiers, :str),
        agi: mob_data.stats.agi + modifier(modifiers, :agi),
        vit: mob_data.stats.vit + modifier(modifiers, :vit),
        int: mob_data.stats.int + modifier(modifiers, :int),
        dex: mob_data.stats.dex + modifier(modifiers, :dex),
        luk: mob_data.stats.luk + modifier(modifiers, :luk)
      },
      combat_stats: %{
        hit: MobCombatCalc.calculate_hit(mob_data) + modifier(modifiers, :hit),
        flee: MobCombatCalc.calculate_flee(mob_data) + modifier(modifiers, :flee),
        perfect_dodge: MobCombatCalc.calculate_perfect_dodge(mob_data),
        def: MobCombatCalc.calculate_defense(mob_data) + modifier(modifiers, :def),
        atk: MobCombatCalc.calculate_base_attack(mob_data) + modifier(modifiers, :atk),
        matk: mob_matk + modifier(modifiers, :matk),
        matk_min: mob_matk + modifier(modifiers, :matk),
        matk_max: mob_matk + modifier(modifiers, :matk),
        mdef: MobCombatCalc.calculate_magic_defense(mob_data) + modifier(modifiers, :mdef),
        soft_mdef: MobCombatCalc.calculate_soft_mdef(mob_data)
      },
      progression: %{
        base_level: mob_data.level,
        job_level: 1
      },
      element: Map.get(modifiers, :element_override, mob_data.element),
      race: mob_data.race,
      size: mob_data.size,
      weapon: %{
        type: :fist,
        element: elem(mob_data.element, 0),
        size: mob_data.size
      },
      attack_range: mob_data.attack_range,
      attack_delay_ms: mob_data.attack_delay,
      position: {mob_state.x, mob_state.y},
      map_name: mob_state.map_name,
      class: if(is_boss?(mob_state), do: :boss, else: :normal),
      equip_modifiers: %{}
    })
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
  Sets the AI state.
  """
  @spec set_ai_state(t(), ai_state()) :: t()
  def set_ai_state(%__MODULE__{} = state, new_ai_state) do
    %{state | ai_state: new_ai_state, last_ai_tick: System.system_time(:second)}
  end

  @doc """
  Sets the combat target.
  """
  @spec set_target(t(), integer() | nil) :: t()
  def set_target(%__MODULE__{} = state, target_id) do
    %{state | target_id: target_id}
  end

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
  Records a rude attack: a hit taken from beyond `chase_range`. Increments the
  cumulative counter and raises the transient per-reaction flag.
  """
  @spec note_rude_attack(t()) :: t()
  def note_rude_attack(%__MODULE__{rude_attack_count: count} = state) do
    %{state | rude_attack_count: count + 1, rude_attacked?: true}
  end

  @doc """
  Clears the transient rude-attack flag, leaving the cumulative count intact.
  """
  @spec clear_rude_attacked(t()) :: t()
  def clear_rude_attacked(%__MODULE__{} = state) do
    %{state | rude_attacked?: false}
  end

  @doc """
  Records the per-skill cooldown gate: stores `expires_at` for `skill_name`.
  `expires_at` is a millisecond timestamp in the same domain the caller uses
  for `skill_ready?/3`, following `Aesir.ZoneServer.Mmo.Skill.Cooldown`'s
  clock-agnostic lazy-comparison model (no time is read here).
  """
  @spec put_skill_cooldown(t(), String.t(), integer()) :: t()
  def put_skill_cooldown(%__MODULE__{skill_cooldowns: cooldowns} = state, skill_name, expires_at) do
    %{state | skill_cooldowns: Map.put(cooldowns, skill_name, expires_at)}
  end

  @doc """
  Returns `true` when `skill_name` has no cooldown entry or `now` has reached
  the recorded `expires_at`. `now` is a millisecond timestamp in the same
  domain as `put_skill_cooldown/3`.
  """
  @spec skill_ready?(t(), String.t(), integer()) :: boolean()
  def skill_ready?(%__MODULE__{skill_cooldowns: cooldowns}, skill_name, now) do
    case Map.fetch(cooldowns, skill_name) do
      :error -> true
      {:ok, expires_at} -> now >= expires_at
    end
  end

  @doc """
  Sets the in-progress cast descriptor (`%{row: row, complete_at: ms,
  timer_ref: ref}`), or `nil` to indicate no cast. `timer_ref` is the pending
  `{:casting, :complete}` timer, kept so a silence/stun interruption can
  cancel it. The target is not captured here; it is re-resolved fresh at
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
  Marks the mob as having been stolen from.
  """
  @spec mark_stolen(t()) :: t()
  def mark_stolen(%__MODULE__{} = state) do
    %{state | stolen_from: true}
  end

  @doc """
  Adds or updates aggro for a target.
  """
  @spec add_aggro(t(), integer(), integer()) :: t()
  def add_aggro(%__MODULE__{aggro_list: aggro_list} = state, target_id, damage) do
    current_aggro = Map.get(aggro_list, target_id, 0)
    updated_aggro = Map.put(aggro_list, target_id, current_aggro + damage)
    %{state | aggro_list: updated_aggro}
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
    %{state | aggro_list: %{}}
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
        target_id: nil,
        aggro_list: %{},
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
  Gets the mob's current map.
  """
  @spec get_map(t()) :: String.t()
  def get_map(%__MODULE__{map_name: map_name}), do: map_name

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

  @doc """
  Gets the mob's attack delay in milliseconds.
  """
  @spec get_attack_delay(t()) :: integer()
  def get_attack_delay(%__MODULE__{mob_data: mob_data}) do
    mob_data.attack_delay
  end

  # Private Helper Functions

  defp calculate_hit(mob_data) do
    # Basic hit calculation based on level and DEX
    mob_data.level + mob_data.stats.dex
  end

  defp calculate_flee(mob_data) do
    # Basic flee calculation based on level and AGI
    mob_data.level + mob_data.stats.agi
  end

  defp calculate_crit(mob_data) do
    # Basic crit calculation based on LUK
    div(mob_data.stats.luk, 3)
  end

  defp calculate_aspd(mob_data) do
    # Convert attack delay to ASPD format
    # Lower attack_delay means faster attack speed
    max(100, 200 - div(mob_data.attack_delay, 10))
  end

  defp calculate_view_range(mob_data) do
    # Base view range, bosses have larger range
    if :boss in (mob_data.modes || []) do
      20
    else
      12
    end
  end

  defp modifier(modifiers, key), do: Map.get(modifiers, key, 0)
end

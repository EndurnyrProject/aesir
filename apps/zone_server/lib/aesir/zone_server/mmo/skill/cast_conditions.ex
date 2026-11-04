defmodule Aesir.ZoneServer.Mmo.Skill.CastConditions do
  @moduledoc """
  The individual conditions a skill cast is checked against: the catalog
  guards (definition, level, behavior), the target it may aim at and whether
  it is reached, the unit placement, the caster's state (weapon, learned rank,
  chat room, support-blocking statuses) and the cast-end refusals.

  Each check is a pure gate returning `:ok` or `{:error, reason}`; the
  orchestration that strings them into a cast begin or cast end lives in
  `Skill.CastValidation` and `Skill.Interpreter`.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SkillRange
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.PlacementCheck
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  # Vulture's Eye: the passive whose learned level widens a `vulture_range` skill.
  @vulture_skill_id 44
  @fire_wall_skill_id 18
  @sight_cells 14

  @typedoc "The phase a check runs in."
  @type phase :: :cast_begin | :cast_end

  @doc "The caster's `{unit_type, id}` through its adapter."
  @spec caster_ref(Active.caster()) :: {atom(), integer()}
  def caster_ref(caster) do
    adapter = Caster.for(caster)
    {adapter.unit_type(caster), adapter.id(caster)}
  end

  @doc "The catalog definition for a skill id or name."
  @spec fetch_definition(term()) :: {:ok, Definition.t()} | {:error, :unknown_skill}
  def fetch_definition(skill_id) when is_integer(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :unknown_skill}
    end
  end

  def fetch_definition(skill_name) when is_atom(skill_name) do
    case Catalog.by_name(skill_name) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :unknown_skill}
    end
  end

  def fetch_definition(_skill), do: {:error, :unknown_skill}

  @doc "The skill's active behavior module."
  @spec fetch_active_module(Definition.t()) :: {:ok, module()} | {:error, :no_behavior}
  def fetch_active_module(definition) do
    case Catalog.active_module_for(definition.name) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :no_behavior}
    end
  end

  @doc "Caps a level at the skill's maximum."
  @spec clamp_level(pos_integer(), Definition.t()) :: pos_integer()
  def clamp_level(level, definition), do: min(level, definition.max_level)

  @doc "An item cast's level is authorized by its item; any other use is capped."
  @spec check_use_level(Definition.t(), pos_integer(), map() | nil) :: :ok | {:error, atom()}
  def check_use_level(definition, level, %{skill_id: id, level: item_level})
      when id == definition.id and item_level == level,
      do: check_item_level(level)

  def check_use_level(definition, level, _item), do: check_max_level(definition, level)

  @doc "An item cast's level only needs to be positive."
  @spec check_item_level(term()) :: :ok | {:error, :invalid_level}
  def check_item_level(level) when is_integer(level) and level > 0, do: :ok
  def check_item_level(_level), do: {:error, :invalid_level}

  @doc "The level may not exceed the skill's maximum."
  @spec check_max_level(Definition.t(), pos_integer()) :: :ok | {:error, :invalid_level}
  def check_max_level(definition, level) when level <= definition.max_level, do: :ok
  def check_max_level(_definition, _level), do: {:error, :invalid_level}

  @doc "A passive skill cannot be cast."
  @spec check_castable(Definition.t()) :: :ok | {:error, :passive_skill}
  def check_castable(%{target_type: :passive}), do: {:error, :passive_skill}
  def check_castable(_definition), do: :ok

  @doc "An NPC may only cast a support skill."
  @spec check_support_target(Definition.t()) :: :ok | {:error, :unsupported_skill}
  def check_support_target(%{target_type: type}) when type in [:target_ally, :target_any],
    do: :ok

  def check_support_target(_definition), do: {:error, :unsupported_skill}

  @doc "An NPC caster must have the skill's required facilities."
  @spec check_npc_facilities(Definition.t()) :: :ok | {:error, :missing_caster_facilities}
  def check_npc_facilities(definition) do
    case Castability.check(definition, :npc) do
      :ok -> :ok
      {:error, {:missing, _requirements}} -> {:error, :missing_caster_facilities}
    end
  end

  @doc "The caster's weapon suits the skill."
  @spec check_weapon(Active.caster(), Definition.t()) :: :ok | {:error, atom()}
  def check_weapon(game_state, definition),
    do: Caster.Player.check_weapon(game_state, definition)

  @doc "The caster knows the skill at `level`; a plagiarized skill counts at its begin."
  @spec check_learned(Active.caster(), module(), Definition.t(), pos_integer(), atom()) ::
          :ok | {:error, atom()}
  def check_learned(
        %PlayerState{plagiarized: %{skill_id: skill_id, level: learned_level}},
        _adapter,
        %{id: skill_id},
        level,
        :begin
      )
      when learned_level >= level,
      do: :ok

  def check_learned(caster, adapter, definition, level, phase),
    do: :erlang.apply(adapter, :knows?, [caster, definition, level, phase])

  @doc "A player in a chat room casts nothing."
  @spec check_chat_room(PlayerState.t()) :: :ok | {:error, :in_chat_room}
  def check_chat_room(%PlayerState{waiting_room: nil}), do: :ok
  def check_chat_room(_caster), do: {:error, :in_chat_room}

  @doc "A support cast is refused while a status blocks the caster's support skills."
  @spec check_support_status(Active.caster(), Definition.t()) :: :ok | {:error, :status_blocked}
  def check_support_status(caster, %{target_type: target_type})
      when target_type in [:target_ally, :target_any] do
    {type, id} = caster_ref(caster)
    if StatusInterpreter.support_blocked?(type, id), do: {:error, :status_blocked}, else: :ok
  end

  def check_support_status(_caster, _definition), do: :ok

  @doc "The skill is off cooldown for a player caster."
  @spec check_cooldown(PlayerState.t(), integer(), integer()) :: :ok | {:error, :on_cooldown}
  def check_cooldown(game_state, skill_id, now) do
    if Cooldown.ready?(game_state.skill_cooldowns, skill_id, now) do
      :ok
    else
      {:error, :on_cooldown}
    end
  end

  @doc "The caster holds at least `cost` SP."
  @spec check_sp(module(), Active.caster(), non_neg_integer()) :: :ok | {:error, :insufficient_sp}
  def check_sp(adapter, game_state, cost) do
    if adapter.sp(game_state) >= cost, do: :ok, else: {:error, :insufficient_sp}
  end

  @doc "The target suits the skill, through the caster's adapter and then the default rules."
  @spec check_target(Active.caster(), Active.target(), Definition.t()) :: :ok | {:error, atom()}
  def check_target(caster, target, definition) do
    adapter = Caster.for(caster)

    case :erlang.apply(adapter, :validate_target, [caster, target, definition]) do
      :continue -> check_default_target(caster, target, definition)
      result -> result
    end
  end

  # A target that cannot be resolved falls through so `check_range` reports it
  # as `:target_not_found`. A skill-unit cell (Ice Wall, etc.) is accepted
  # without a `Targeting.validate_enemy` call: `unit_type_of/1` only reports
  # `:skill_unit` for a cell the registry already confirmed is targetable, so
  # it is a valid enemy target by construction.
  defp check_default_target(game_state, {:unit, target_id}, %{target_type: :target_enemy}) do
    with :ok <- ensure_targetable_unit(target_id) do
      case unit_type_of(target_id) do
        :mob -> :ok
        :skill_unit -> :ok
        :player -> validate_enemy_player(game_state, target_id)
        :not_found -> :ok
      end
    end
  end

  defp check_default_target(_game_state, {:unit, target_id}, %{target_type: target_type})
       when target_type in [:target_ally, :target_any],
       do: ensure_targetable_unit(target_id)

  defp check_default_target(_game_state, {:unit, target_id}, %{target_type: :target_corpse}),
    do: ensure_corpse_target(target_id)

  defp check_default_target(_game_state, {:unit, target_id}, %{target_type: :target_resurrection}),
       do: ensure_resurrection_target(target_id)

  defp check_default_target(_game_state, {:ground, _x, _y}, %{target_type: :ground}), do: :ok

  defp check_default_target(_game_state, :self, %{target_type: :ground}),
    do: {:error, :invalid_target}

  defp check_default_target(_game_state, {:unit, _id}, %{target_type: :ground}),
    do: {:error, :invalid_target}

  defp check_default_target(_game_state, :self, _definition), do: :ok
  defp check_default_target(%{character_id: caster_id}, {:unit, caster_id}, _definition), do: :ok
  defp check_default_target(_game_state, _target, _definition), do: {:error, :invalid_target}

  # A dead player is a legal cast target: the reference pays the requirement and
  # its cast end returns before the effect (see `dead_target_skip?/2`). A dead
  # monster or homunculus is removed from the map, so it stays refused here.
  defp ensure_targetable_unit(unit_id) do
    case TargetResolver.resolve(unit_id) do
      {:ok, _pid, _target_state, :player} ->
        :ok

      {:ok, _pid, target_state, unit_type} ->
        TargetResolver.ensure_targetable(target_state, unit_type)

      {:error, _reason} ->
        :ok
    end
  end

  # A target that vanishes between position resolution and the typed re-resolution
  # rejects like a non-enemy instead of crashing.
  defp validate_enemy_player(game_state, target_id) do
    case TargetResolver.resolve(:player, target_id) do
      {:ok, _pid, target_state, :player} ->
        Targeting.validate_enemy_relation_allow_dead(game_state, target_state)

      _ ->
        {:error, :invalid_target}
    end
  end

  defp ensure_corpse_target(unit_id) do
    result =
      case TargetResolver.resolve(unit_id) do
        {:ok, _pid, target_state, :player} ->
          if Unit.corpse?(target_state),
            do: :ok,
            else: {:error, :invalid_target}

        {:ok, _pid, _target_state, _unit_type} ->
          {:error, :invalid_target}

        {:error, _reason} ->
          {:error, :target_not_found}
      end

    result
  catch
    :exit, _reason -> {:error, :target_not_found}
  end

  defp ensure_resurrection_target(unit_id) do
    case TargetResolver.resolve(unit_id) do
      {:ok, _pid, target_state, :player} ->
        if Unit.corpse?(target_state),
          do: :ok,
          else: TargetResolver.ensure_targetable(target_state, :player)

      {:ok, _pid, target_state, unit_type} ->
        TargetResolver.ensure_targetable(target_state, unit_type)

      {:error, _reason} ->
        {:error, :target_not_found}
    end
  catch
    :exit, _reason -> {:error, :target_not_found}
  end

  @doc """
  A unit target concealed from the caster fails the attempt at its cast
  phase. Only monsters are bosses or detectors, so a player or homunculus
  caster is checked by identity alone. An unresolvable target falls through
  so `check_range/4` reports it.
  """
  @spec check_concealment(Active.caster(), Active.target(), Definition.t(), atom()) ::
          :ok | {:error, atom()}
  def check_concealment(caster, {:unit, target_ref}, definition, phase) do
    case unit_type_of(target_ref) do
      :not_found ->
        :ok

      target_type ->
        {caster_type, caster_id} = caster_ref(caster)

        Targeting.validate_skill_use(
          %{unit_type: caster_type, unit_id: caster_id},
          %{unit_type: target_type, unit_id: target_unit_id(target_ref)},
          definition,
          phase
        )
    end
  end

  def check_concealment(_caster, _target, _definition, _phase), do: :ok

  @doc "A timed cast's completion checks its caster's state, then its target."
  @spec check_cast_end(Active.caster(), Active.target(), Definition.t(), boolean()) ::
          :ok | {:error, atom()}
  def check_cast_end(caster, target, definition, item?) do
    with :ok <- check_completion_caster(caster, definition, item?),
         do: check_concealment(caster, target, definition, :cast_end)
  end

  @doc "The caster's own state lets the cast complete."
  @spec check_completion_caster(Active.caster(), Definition.t(), boolean()) ::
          :ok | {:error, atom()}
  def check_completion_caster(caster, definition, item?) do
    {type, id} = caster_ref(caster)
    Targeting.validate_cast_completion(%{unit_type: type, unit_id: id}, definition, item?)
  end

  defp target_unit_id({_unit_type, unit_id}), do: unit_id
  defp target_unit_id(unit_id), do: unit_id

  @doc """
  Blinding Mist: attack-type skills aimed at a fog holder fail at cast end
  three times in four, before any requirement is spent. A skill completing on
  an invincible player it may not reach fails before the fog roll and before
  any cost is spent.
  """
  @spec check_castend_target(Active.caster(), Active.target(), Definition.t()) ::
          :ok | {:error, :target_invincible | :fogged_out}
  def check_castend_target(caster, target, definition) do
    cond do
      Targeting.castend_refused?(caster_ref(caster), target, definition) ->
        {:error, :target_invincible}

      Targeting.fogged_out?(target, definition) ->
        {:error, :fogged_out}

      true ->
        :ok
    end
  end

  @doc """
  A support skill reaches a homunculus only from its owner: anyone else's is
  refused silently, when the use starts and again when a timed cast ends. A
  unit that cannot be resolved is left to the presence checks.
  """
  @spec check_homunculus_support(Active.caster(), Active.target(), Definition.t()) ::
          :ok | {:error, :target_restricted}
  def check_homunculus_support(
        %PlayerState{} = caster,
        {:unit, {:homunculus, _gid} = ref},
        definition
      ) do
    if Definition.support?(definition) and foreign_homunculus?(caster, ref),
      do: {:error, :target_restricted},
      else: :ok
  end

  def check_homunculus_support(_caster, _target, _definition), do: :ok

  defp foreign_homunculus?(%PlayerState{character_id: caster_id}, ref) do
    with {:ok, caster} <- Combat.resolve_combatant(:player, caster_id),
         {:ok, homunculus} <- Combat.resolve_combatant(ref) do
      not Targeting.direct_support?(caster, homunculus)
    else
      _unresolved -> false
    end
  end

  @doc """
  The unit a player aims at must still be on the caster's map, and a skill
  that may not target its user refuses the player themselves; all silently.
  """
  @spec check_use_target(PlayerState.t(), Active.target(), Definition.t()) ::
          :ok | {:error, atom()}
  def check_use_target(caster, {:unit, target_id} = target, definition) do
    if self_target?(caster, target),
      do: check_self_target(caster, target, definition),
      else: check_unit_target(caster, target_id, definition)
  end

  def check_use_target(caster, target, definition),
    do: check_self_target(caster, target, definition)

  defp check_unit_target(caster, target_id, definition) do
    with :ok <- check_unit_target_map(caster, target_id),
         do: check_self_target(caster, {:unit, target_id}, definition)
  end

  defp check_self_target(caster, target, %{no_target_self: true}) do
    if self_target?(caster, target), do: {:error, :no_target_self}, else: :ok
  end

  defp check_self_target(_caster, _target, _definition), do: :ok

  @doc "Whether a player aims the skill at themselves."
  @spec self_target?(Active.caster(), Active.target()) :: boolean()
  def self_target?(_caster, :self), do: true
  def self_target?(%PlayerState{character_id: id}, {:unit, id}), do: true
  def self_target?(%PlayerState{character_id: id}, {:unit, {:player, id}}), do: true
  def self_target?(_caster, _target), do: false

  @doc """
  A player's cast end does not check the range again; a unit target gone
  from the caster's map fails it silently.
  """
  @spec check_castend_presence(PlayerState.t(), Active.target()) :: :ok | {:error, atom()}
  def check_castend_presence(caster, {:unit, target_id} = target) do
    if self_target?(caster, target), do: :ok, else: check_unit_target_map(caster, target_id)
  end

  def check_castend_presence(_caster, _target), do: :ok

  @doc "The unit target is on the caster's map."
  @spec check_unit_target_map(Active.caster(), term()) ::
          :ok | {:error, :different_map | :target_not_found}
  def check_unit_target_map(caster, target_id) do
    case resolve_unit_position(target_id) do
      {:ok, {_x, _y, map_name}} when map_name != caster.map_name -> {:error, :different_map}
      {:ok, _position} -> :ok
      {:error, _reason} -> {:error, :target_not_found}
    end
  end

  @doc """
  A player reaches a target when the client's circular distance is within the
  skill's range and, beyond the adjacent cells, within sight (14 cells) with
  no wall between them. While the player walks, a target not reached at one
  cell less is remembered instead (`:step_action`), to be tried again as the
  walk goes on; a use that cannot retry that way (`walk_action: false`, an
  item cast whose item was already claimed) simply fails. A ground cell must
  also hold a unit placement. A combo used while swinging at its target
  (`attack_reach: true`) has the attack's reach: only the walking step rule
  applies.
  """
  @spec check_use_range(
          PlayerState.t(),
          Active.target(),
          Definition.t(),
          pos_integer(),
          keyword()
        ) ::
          :ok | {:error, atom()}
  def check_use_range(_caster, :self, _definition, _level, _opts), do: :ok

  def check_use_range(caster, target, definition, level, opts) do
    if self_target?(caster, target) do
      :ok
    else
      range = effective_range(definition, caster, level)

      check_reach(
        caster,
        target,
        range,
        Keyword.get(opts, :attack_reach, false),
        Keyword.get(opts, :walk_action, true)
      )
    end
  end

  defp check_reach(caster, target, range, attack_reach?, walk_action?) do
    with {:ok, cell} <- use_target_cell(target) do
      cond do
        walking?(caster) and not reaches?(caster, cell, range - 1) ->
          out_of_reach(walk_action?)

        attack_reach? ->
          :ok

        not reaches?(caster, cell, range) ->
          {:error, :out_of_range}

        true ->
          check_use_cell(caster, target)
      end
    end
  end

  defp out_of_reach(true), do: {:error, :step_action}
  defp out_of_reach(_walk_action?), do: {:error, :out_of_range}

  defp use_target_cell({:ground, x, y}), do: {:ok, {x, y}}

  defp use_target_cell({:unit, target_id}) do
    case resolve_unit_position(target_id) do
      {:ok, {x, y, _map}} -> {:ok, {x, y}}
      {:error, _reason} -> {:error, :target_not_found}
    end
  end

  defp check_use_cell(caster, {:ground, x, y}), do: check_ground_walkable(caster.map_name, x, y)
  defp check_use_cell(_caster, _target), do: :ok

  defp walking?(%PlayerState{movement_state: :moving}), do: true
  defp walking?(_caster), do: false

  defp reaches?(%PlayerState{map_name: map_name, x: x, y: y}, {tx, ty}, range) do
    distance = Geometry.chebyshev_distance(x, y, tx, ty)

    Geometry.client_distance(x, y, tx, ty) <= max(range, 0) and
      (distance < 2 or
         (distance <= @sight_cells and LineOfSight.clear?(map_name, {x, y}, {tx, ty})))
  end

  @doc "The target is within the skill's Chebyshev range on the caster's map."
  @spec check_range(Active.caster(), Active.target(), Definition.t(), pos_integer()) ::
          :ok | {:error, atom()}
  def check_range(_game_state, :self, _definition, _level), do: :ok

  def check_range(game_state, {:unit, target_id}, definition, level) do
    range = effective_range(definition, game_state, level)

    case resolve_unit_position(target_id) do
      {:ok, {tx, ty, target_map}} ->
        cond do
          target_map != game_state.map_name ->
            {:error, :different_map}

          Geometry.chebyshev_distance(game_state.x, game_state.y, tx, ty) <= range ->
            :ok

          true ->
            {:error, :out_of_range}
        end

      {:error, _} ->
        {:error, :target_not_found}
    end
  end

  def check_range(game_state, {:ground, x, y}, definition, level) do
    with :ok <- check_ground_range(game_state, x, y, definition, level) do
      check_ground_walkable(game_state.map_name, x, y)
    end
  end

  defp check_ground_range(game_state, x, y, definition, level) do
    range = effective_range(definition, game_state, level)

    if Geometry.chebyshev_distance(game_state.x, game_state.y, x, y) <= range,
      do: :ok,
      else: {:error, :out_of_range}
  end

  defp check_ground_walkable(map_name, x, y) do
    if Cell.placeable?(map_name, x, y) do
      :ok
    else
      {:error, :invalid_target}
    end
  end

  @doc """
  The cast-range of a skill for a given caster and level, in cells (Chebyshev).

  Resolves the definition's declared range at `level` as the server counts it
  (`SkillRange.database_range/2`: its absolute value, so a negative range does not
  take the weapon's reach, capped at 14 cells). A skill declaring
  `vulture_range: true` (the bow skills whose reach trains with Vulture's Eye) then
  adds a player caster's learned Vulture's Eye level; no other caster kind gains
  anything. Exposed so the session handler can size the move-to-range approach for
  an out-of-range cast.
  """
  @spec effective_range(Definition.t(), Active.caster(), non_neg_integer()) :: non_neg_integer()
  def effective_range(definition, game_state, level) do
    base_range = base_range(definition, game_state, level)

    case Catalog.active_module_for(definition.name) do
      {:ok, module} -> skill_effective_range(module, game_state, level, definition, base_range)
      :error -> base_range
    end
  end

  defp base_range(definition, game_state, level),
    do: SkillRange.database_range(definition, level) + vulture_range_bonus(definition, game_state)

  defp vulture_range_bonus(%{vulture_range: true}, %PlayerState{} = game_state) do
    PlayerStats.skill_level(game_state.stats, @vulture_skill_id)
  end

  defp vulture_range_bonus(_definition, _game_state), do: 0

  defp skill_effective_range(module, game_state, level, definition, base_range) do
    if function_exported?(module, :effective_range, 4) do
      case module.effective_range(game_state, level, definition, base_range) do
        range when is_integer(range) and range >= 0 -> range
        invalid -> raise ArgumentError, "invalid effective skill range: #{inspect(invalid)}"
      end
    else
      base_range
    end
  end

  @doc """
  Resolves player, mob, and skill-unit (Ice Wall, etc.) target ids alike
  through `Combat.resolve_target_position/1`, the single source of truth for
  target-position resolution shared with basic-attack targeting.
  """
  @spec resolve_unit_position(term()) ::
          {:ok, {integer(), integer(), String.t()}} | {:error, atom()}
  def resolve_unit_position(unit_id) do
    case Combat.resolve_target_position(unit_id) do
      {:ok, _type, position} -> {:ok, position}
      {:error, _reason} = error -> error
    end
  end

  defp unit_type_of(unit_id) do
    case Combat.resolve_target_position(unit_id) do
      {:ok, type, _position} -> type
      {:error, :target_not_found} -> :not_found
    end
  end

  @doc """
  A cast reaching the ground cast end checks its unit placement as its own
  kind before anything else there.
  """
  @spec check_end_placement(Active.caster(), Definition.t(), Active.target(), phase()) ::
          :ok | {:error, atom()}
  def check_end_placement(caster, definition, target, :cast_end),
    do: check_placement(caster, definition, target)

  def check_end_placement(_caster, _definition, _target, _phase), do: :ok

  @doc """
  Fire Wall alone also checks its placement, as a player, when a player's
  cast starts, once its starting requirements pass.
  """
  @spec check_start_placement(Active.caster(), Definition.t(), Active.target(), phase()) ::
          :ok | {:error, atom()}
  def check_start_placement(caster, definition, target, :cast_begin),
    do: check_begin_placement(caster, definition, target)

  def check_start_placement(_caster, _definition, _target, _phase), do: :ok

  defp check_begin_placement(
         %PlayerState{} = caster,
         %{id: @fire_wall_skill_id} = definition,
         target
       ),
       do: check_placement(caster, definition, target, :player)

  defp check_begin_placement(_caster, _definition, _target), do: :ok

  @doc "The skill's unit may be placed at the target, checked as the caster's own kind."
  @spec check_placement(Active.caster(), Definition.t(), Active.target()) ::
          :ok | {:error, atom()}
  def check_placement(caster, definition, target),
    do: check_placement(caster, definition, target, elem(caster_ref(caster), 0))

  @doc "The skill's unit may be placed at the target, checked as unit kind `as`."
  @spec check_placement(Active.caster(), Definition.t(), Active.target(), atom()) ::
          :ok | {:error, atom()}
  def check_placement(caster, definition, target, as) do
    with true <- placement_checked?(definition),
         {:ok, cell} <- placement_cell(caster, target) do
      PlacementCheck.check(definition, caster_ref(caster), caster.map_name, cell, as)
    else
      _unchecked -> :ok
    end
  end

  defp placement_checked?(definition),
    do: definition.active_instance > 0 or definition.no_reiteration or definition.no_footset

  defp placement_cell(_caster, {:ground, x, y}), do: {:ok, {x, y}}
  defp placement_cell(%{x: x, y: y}, :self), do: {:ok, {x, y}}

  defp placement_cell(_caster, {:unit, target_id}) do
    with {:ok, {x, y, _map}} <- resolve_unit_position(target_id), do: {:ok, {x, y}}
  end

  defp placement_cell(_caster, _target), do: :error

  # The reference refuses a dead target at the top of its damage and no-damage
  # cast ends, after the requirement is paid: the use ends without its effect,
  # without its items, its cast-end tail or a failure message. Five skills may
  # run on the dead; only the two implemented here are listed.
  @cast_on_dead_skills [:all_resurrection, :pr_redemptio]

  @doc "Whether the cast end ends without its effect because the target is a dead player."
  @spec dead_target_skip?(Definition.t(), Active.target()) :: boolean()
  def dead_target_skip?(%{name: name}, _target) when name in @cast_on_dead_skills, do: false

  def dead_target_skip?(%{target_type: type}, _target)
      when type in [:target_corpse, :target_resurrection],
      do: false

  def dead_target_skip?(_definition, :self), do: false

  def dead_target_skip?(_definition, target) do
    case player_target_state(target) do
      {:ok, false} -> true
      _alive_other_or_gone -> false
    end
  end

  @doc """
  The reference's OFFICIAL_WALKPATH check runs for every cast whose type is
  not no-damage, whatever the caster's weapon reach.
  """
  @spec walk_path_blocked?(Definition.t(), Active.caster(), Active.target()) :: boolean()
  def walk_path_blocked?(definition, caster, target) do
    Definition.cast_type(definition) == :damage and line_blocked?(caster, target)
  end

  defp line_blocked?(caster, target) do
    with {:ok, target_id} <- unit_target_id(target),
         {:ok, {tx, ty, target_map}} <- resolve_unit_position(target_id),
         true <- target_map == caster.map_name and {caster.x, caster.y} != {tx, ty} do
      not LineOfSight.clear?(caster.map_name, {caster.x, caster.y}, {tx, ty})
    else
      _other -> false
    end
  end

  defp unit_target_id({:unit, {:player, id}}), do: {:ok, id}
  defp unit_target_id({:unit, {:mob, id}}), do: {:ok, id}
  defp unit_target_id({:unit, {:homunculus, id}}), do: {:ok, id}
  defp unit_target_id({:unit, id}) when is_integer(id), do: {:ok, id}
  defp unit_target_id(_target), do: :error

  @doc "Whether the target is a player, dead or alive."
  @spec player_target?(Active.target()) :: boolean()
  def player_target?(target), do: match?({:ok, _living}, player_target_state(target))

  defp player_target_state({:unit, {:player, id}}), do: player_liveness(id)
  defp player_target_state({:unit, :player, id}), do: player_liveness(id)

  defp player_target_state({:unit, id}) do
    case TargetResolver.resolve(id) do
      {:ok, _pid, state, :player} -> {:ok, Unit.living?(state)}
      _other -> :error
    end
  end

  defp player_target_state(_target), do: :error

  defp player_liveness(id) do
    case TargetResolver.resolve(:player, id) do
      {:ok, _pid, state, :player} -> {:ok, Unit.living?(state)}
      _other -> :error
    end
  end

  # The reference's own cast-time override list (`unit.cpp`): these skills set
  # its `combo` flag after it was cleared, so pre-renewal treats them as an
  # immediate cast even without a cast time. Asura Strike and Spell Breaker
  # always; Resurrection only against an undead target (its level 4 has no
  # cast time at all). The reference's Gate of Hell and Tiger Cannon are the
  # other two and are not implemented here.
  @forced_cast_skills [:mo_extremityfist, :sa_spellbreaker]

  @doc "Whether pre-renewal treats the cast as immediate even without a cast time."
  @spec forced_cast?(Definition.t(), Active.target()) :: boolean()
  def forced_cast?(%{name: name}, _target) when name in @forced_cast_skills, do: true
  def forced_cast?(%{name: :all_resurrection}, target), do: undead_target?(target)
  def forced_cast?(_definition, _target), do: false

  @spec undead_target?(Active.target()) :: boolean()
  defp undead_target?({:unit, target}), do: undead_combatant?(target)
  defp undead_target?({:unit, type, id}), do: undead_combatant?({type, id})
  defp undead_target?(target) when is_integer(target), do: undead_combatant?(target)

  defp undead_target?({type, _id} = ref) when type in [:player, :mob, :homunculus],
    do: undead_combatant?(ref)

  defp undead_target?(_target), do: false

  defp undead_combatant?(target) do
    case TargetResolver.resolve_combatant(target) do
      {:ok, combatant} -> RaceModifiers.undead_target?(combatant)
      {:error, _reason} -> false
    end
  end
end

defmodule Aesir.ZoneServer.Mmo.Skill.CastValidation do
  @moduledoc """
  Strings the cast conditions (`Skill.CastConditions`) into the validation
  chains a cast runs: a player's cast begin in the reference's order (use
  stages, cast-begin conditions, placement, range, the skill's own checks), a
  non-player caster's begin through its adapter, the cast end of a timed
  cast, the item branch of a cast begin, and an Encore replay. Each chain
  yields a `Skill.CastContext` with the cost prepared on the caster that
  reaches the behavior.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.CastConditions
  alias Aesir.ZoneServer.Mmo.Skill.CastContext
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.UseRestrictions
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "A validated Encore memory: the remembered skill, its module and level."
  @type encore_replay :: %{
          definition: Definition.t(),
          module: module(),
          skill_id: integer(),
          level: pos_integer()
        }

  @doc """
  Validates a cast attempt for any caster, at `phase`, into a prepared
  context. A struct caster is validated through its adapter directly; a bare
  map first passes the catalog guards.
  """
  @spec validate_cast(
          Active.caster(),
          integer(),
          pos_integer(),
          Active.target(),
          integer(),
          CastConditions.phase(),
          keyword()
        ) :: {:ok, CastContext.t()} | {:error, term()}
  def validate_cast(caster, skill_id, level, target, now, phase \\ :cast_begin, opts \\ [])

  def validate_cast(caster, skill_id, level, target, now, phase, opts) when is_struct(caster),
    do: validate_owned_cast(caster, skill_id, level, target, now, phase, opts)

  def validate_cast(caster, skill_id, level, target, now, phase, opts) do
    with {:ok, definition} <- CastConditions.fetch_definition(skill_id),
         :ok <- CastConditions.check_max_level(definition, level),
         :ok <- CastConditions.check_castable(definition) do
      validate_owned_cast(caster, skill_id, level, target, now, phase, opts)
    end
  end

  defp validate_owned_cast(%PlayerState{} = caster, skill_id, level, target, _now, phase, opts),
    do: validate_player_cast(caster, skill_id, level, target, phase, opts)

  defp validate_owned_cast(caster, skill_id, level, target, now, phase, _opts) do
    with {:ok, adapter} <- lifecycle_adapter(caster),
         :ok <- :erlang.apply(adapter, :castable_state, [caster, skill_id, :begin]),
         {:ok, definition} <- CastConditions.fetch_definition(skill_id),
         :ok <- CastConditions.check_support_status(caster, definition),
         :ok <- CastConditions.check_max_level(definition, level),
         :ok <- CastConditions.check_castable(definition),
         :ok <- CastConditions.check_weapon(caster, definition),
         :ok <- CastConditions.check_learned(caster, adapter, definition, level, :begin),
         :ok <- CastConditions.check_target(caster, target, definition),
         :ok <- CastConditions.check_concealment(caster, target, definition, phase),
         :ok <- CastConditions.check_end_placement(caster, definition, target, phase),
         :ok <- CastConditions.check_range(caster, target, definition, level),
         {:ok, _module} <- CastConditions.fetch_active_module(definition),
         :ok <- :erlang.apply(adapter, :castable_status, [caster, skill_id]),
         context = CastContext.build(caster, definition, level, target, :begin),
         :ok <- check_context_cooldown(context, now),
         :ok <- check_context_act_delay(context, now),
         {:ok, prepared} <- validate_and_prepare(context, phase == :cast_begin),
         :ok <- CastConditions.check_start_placement(prepared.caster, definition, target, phase) do
      {:ok, record_spheres_old(prepared, phase)}
    end
  end

  @doc """
  A player's skill use, in the order the reference checks it: the map and
  cooldown restrictions again, the target (gone or on another map, or the
  player themselves for a skill that may not target its user, refused
  silently), the statuses that forbid this use (silent), the skill's own use
  checks, the cast-begin conditions, then the range and the skill's checks
  on a target in range. A ground cast checks the placement of its unit after
  its cast-begin conditions. The catalog guards (level, learned rank,
  behavior) never fail a request the client stage let through. Whether the
  target suits the skill and the skill's own `validate/4` are cast-end
  checks (`check_player_castend/4`); a staged input cast, validated as it
  ends, runs them last.
  """
  @spec validate_player_cast(
          PlayerState.t(),
          integer(),
          pos_integer(),
          Active.target(),
          CastConditions.phase(),
          keyword()
        ) :: {:ok, CastContext.t()} | {:error, term()}
  def validate_player_cast(caster, skill_id, level, target, phase, opts) do
    with {:ok, context} <- check_player_use(caster, skill_id, level, target, phase, opts),
         {:ok, context} <- castbegin(context, phase == :cast_begin) do
      check_player_after_begin(caster, context, phase, opts)
    end
  end

  @doc """
  The stages before the cast-begin conditions. An item cast has no learned
  rank and passes the map and cooldown restrictions with its pending item.
  """
  @spec check_player_use(
          PlayerState.t(),
          integer(),
          pos_integer(),
          Active.target(),
          CastConditions.phase(),
          keyword()
        ) :: {:ok, CastContext.t()} | {:error, term()}
  def check_player_use(caster, skill_id, level, target, phase, opts) do
    adapter = Caster.Player
    item = Keyword.get(opts, :item_skill)

    with :ok <- check_player_restrictions(caster, adapter, skill_id, item),
         {:ok, definition} <- CastConditions.fetch_definition(skill_id),
         :ok <- CastConditions.check_use_level(definition, level, item),
         :ok <- CastConditions.check_castable(definition),
         :ok <- check_player_learned(caster, adapter, definition, level, opts),
         {:ok, _module} <- CastConditions.fetch_active_module(definition),
         :ok <- CastConditions.check_use_target(caster, target, definition),
         :ok <- CastConditions.check_support_status(caster, definition),
         :ok <- CastConditions.check_concealment(caster, target, definition, phase),
         :ok <- CastConditions.check_homunculus_support(caster, target, definition),
         context = CastContext.build(caster, definition, level, target, :begin),
         :ok <- optional_check(context, :skilluse_check) do
      {:ok, context}
    end
  end

  # A script cast and an item cast may use a skill the player never learned;
  # every other cast still checks the learned rank.
  defp check_player_learned(caster, adapter, definition, level, opts) do
    if Keyword.get(opts, :learned?, true),
      do: CastConditions.check_learned(caster, adapter, definition, level, :begin),
      else: :ok
  end

  defp check_player_restrictions(caster, adapter, skill_id, nil),
    do: :erlang.apply(adapter, :castable_state, [caster, skill_id, :begin])

  defp check_player_restrictions(caster, _adapter, skill_id, item) do
    case UseRestrictions.check(caster, skill_id, item, System.monotonic_time(:millisecond)) do
      :ok -> :ok
      {:refuse, reply} -> {:error, {:not_ok, reply}}
    end
  end

  @doc """
  The stages after the cast-begin conditions: the placement a player's cast
  checks as it starts, the one a ground cast checks as it ends, the range,
  the skill's own check on a target in range, and the cast end a staged
  input cast validates last.
  """
  @spec check_player_after_begin(
          PlayerState.t(),
          CastContext.t(),
          CastConditions.phase(),
          keyword()
        ) :: {:ok, CastContext.t()} | {:error, term()}
  def check_player_after_begin(caster, context, phase, opts) do
    definition = context.definition

    with :ok <-
           CastConditions.check_start_placement(
             context.caster,
             definition,
             context.target,
             phase
           ),
         :ok <- CastConditions.check_end_placement(caster, definition, context.target, phase),
         :ok <-
           CastConditions.check_use_range(caster, context.target, definition, context.level, opts),
         :ok <- optional_check(context, :after_range_check),
         :ok <- check_input_castend(context, phase) do
      {:ok, record_spheres_old(context, phase)}
    end
  end

  defp check_input_castend(context, :cast_end),
    do: check_player_castend(context.caster, context.target, context.definition, context)

  defp check_input_castend(_context, _phase), do: :ok

  @doc """
  The cast-end checks of a player's cast that its cast begin leaves out:
  whether the target suits the skill, then the skill's own `validate/4`.
  """
  @spec check_player_castend(PlayerState.t(), Active.target(), Definition.t(), CastContext.t()) ::
          :ok | {:error, term()}
  def check_player_castend(caster, target, definition, context) do
    with :ok <- CastConditions.check_target(caster, target, definition),
         do: validate_module(context)
  end

  defp optional_check(%CastContext{module: module} = context, callback) do
    if function_exported?(module, callback, 4),
      do:
        apply(module, callback, [
          context.caster,
          context.target,
          context.level,
          context.definition
        ]),
      else: :ok
  end

  @doc """
  The cast-begin conditions of a player's cast: a chat room refuses silently,
  then the weight limit; a toggle skill whose status is active only ends it
  and checks nothing more; otherwise the skill's own rows (`begin_attempt/5`),
  the recovered-weight state, the weapon, then SP, zeny and spheres.
  """
  @spec castbegin(CastContext.t(), boolean()) :: {:ok, CastContext.t()} | {:error, term()}
  def castbegin(%CastContext{caster: caster} = context, begin?) do
    with :ok <- CastConditions.check_chat_room(caster),
         do: castbegin_requirements(context, begin?)
  end

  defp castbegin_requirements(
         %CastContext{caster: caster, definition: definition} = context,
         begin?
       ) do
    with :ok <- Caster.Player.check_weight(caster) do
      if Caster.Player.toggle_off?(caster, definition),
        do: prepare_cast(context),
        else: castbegin_conditions(context, begin?)
    end
  end

  @doc """
  The source's cast-begin item branch: the item is claimed after the
  chat-room refusal and before the weight limit. A cast whose item can no
  longer be claimed (already spent, or the wrong item in its slot) fails
  silently; a plain item cast then passes every later condition, while
  `keep_requirement` runs them on the claimed caster.
  """
  @spec item_castbegin(
          CastContext.t(),
          (PlayerState.t() -> {:ok, PlayerState.t()} | {:error, atom()}),
          boolean()
        ) :: {:ok, CastContext.t()} | {:error, atom()} | {:error, atom(), PlayerState.t()}
  def item_castbegin(%CastContext{caster: caster} = context, on_ready, keep?) do
    with :ok <- CastConditions.check_chat_room(caster),
         {:ok, claimed} <- on_ready.(caster) do
      if keep?,
        do: item_keep_requirements(%{context | caster: claimed}),
        else: {:ok, %{context | caster: claimed}}
    end
  end

  defp item_keep_requirements(%CastContext{caster: caster} = context) do
    case castbegin_requirements(context, true) do
      {:ok, prepared} -> {:ok, prepared}
      {:error, reason} -> {:error, reason, caster}
    end
  end

  defp castbegin_conditions(%CastContext{definition: definition} = context, begin?) do
    with {:ok, context} <- begin_context(context, begin?),
         :ok <- Caster.Player.check_recovered_weight(context.caster, definition),
         :ok <- CastConditions.check_weapon(context.caster, definition) do
      prepare_cast(context)
    end
  end

  # The cast-begin requirement check records the sphere count a skill reads for
  # its own damage; the cast end does not record it again.
  defp record_spheres_old(
         %CastContext{caster: %PlayerState{} = caster, cost: %{cost: %Cost{spheres_old: old}}} =
           context,
         :cast_begin
       )
       when is_integer(old),
       do: %{context | caster: %{caster | spirit_spheres_old: old}}

  defp record_spheres_old(context, _phase), do: context

  @doc """
  Validates the completion of a timed cast: the caster's state through its
  adapter, then the cast-end checks, either re-validating the definition (an
  adapter that asks for it) or as a player's cast end.
  """
  @spec validate_completion(Active.caster(), integer(), pos_integer(), Active.target(), keyword()) ::
          {:ok, CastContext.t()} | {:error, term()}
  def validate_completion(caster, skill_id, level, target, opts) do
    now = System.monotonic_time(:millisecond)

    with {:ok, adapter} <- lifecycle_adapter(caster),
         :ok <- :erlang.apply(adapter, :castable_state, [caster, skill_id, :completion]),
         {:ok, definition} <- CastConditions.fetch_definition(skill_id),
         :ok <- CastConditions.check_support_status(caster, definition) do
      if :erlang.apply(adapter, :completion_revalidates_definition?, []) do
        validate_revalidated_completion(caster, level, target, now, adapter, definition, opts)
      else
        validate_player_completion(caster, level, target, now, adapter, definition, opts)
      end
    end
  end

  defp validate_revalidated_completion(caster, level, target, now, adapter, definition, opts) do
    with :ok <- CastConditions.check_max_level(definition, level),
         :ok <- CastConditions.check_castable(definition),
         :ok <- check_completion_learned(caster, adapter, definition, level, opts),
         :ok <- CastConditions.check_target(caster, target, definition),
         :ok <- CastConditions.check_placement(caster, definition, target),
         :ok <- CastConditions.check_cast_end(caster, target, definition, false),
         :ok <- CastConditions.check_range(caster, target, definition, level),
         :ok <- CastConditions.check_castend_target(caster, target, definition),
         {:ok, _module} <- CastConditions.fetch_active_module(definition),
         context = CastContext.build(caster, definition, level, target, :completion),
         :ok <- check_context_cooldown(context, now) do
      validate_and_prepare(context, false)
    end
  end

  defp validate_player_completion(caster, level, target, now, adapter, definition, opts) do
    with {:ok, _module} <- CastConditions.fetch_active_module(definition),
         context = CastContext.build(caster, definition, level, target, :completion),
         :ok <- check_completion_learned(caster, adapter, definition, level, opts),
         :ok <- CastConditions.check_castend_presence(caster, target),
         :ok <- CastConditions.check_target(caster, target, definition),
         :ok <- CastConditions.check_placement(caster, definition, target),
         :ok <- CastConditions.check_cast_end(caster, target, definition, false),
         :ok <- CastConditions.check_homunculus_support(caster, target, definition),
         :ok <- CastConditions.check_castend_target(caster, target, definition),
         :ok <- check_context_cooldown(context, now) do
      validate_and_prepare(context, false)
    end
  end

  # A cast a script started skips the learned-rank re-check; no other cast does.
  defp check_completion_learned(caster, adapter, definition, level, opts) do
    if Keyword.get(opts, :learned?, true),
      do: :erlang.apply(adapter, :knows?, [caster, definition, level, :completion]),
      else: :ok
  end

  @doc "The caster's adapter, when it supports the cast lifecycle."
  @spec lifecycle_adapter(Active.caster()) :: {:ok, module()} | {:error, :unsupported_caster}
  def lifecycle_adapter(caster) do
    adapter = Caster.for(caster)

    if function_exported?(adapter, :castable_state, 3),
      do: {:ok, adapter},
      else: {:error, :unsupported_caster}
  end

  @doc """
  Validates an Encore-remembered skill without mutating the caster: the
  remembered skill's current catalog, level, learned, weapon, target,
  module-validation and cooldown checks.
  """
  @spec validate_encore_replay(PlayerState.t(), map(), Active.target(), integer()) ::
          {:ok, encore_replay()} | {:error, atom()}
  def validate_encore_replay(game_state, %{skill_id: skill_id} = memory, target, now) do
    level = Map.get(memory, :level)

    cond do
      not Catalog.replayable?(skill_id) ->
        {:error, :skill_not_replayable}

      not (is_integer(level) and level > 0) ->
        {:error, :invalid_replay_memory}

      true ->
        with {:ok, definition} <- CastConditions.fetch_definition(skill_id),
             :ok <- CastConditions.check_max_level(definition, level),
             :ok <- CastConditions.check_castable(definition),
             :ok <- CastConditions.check_weapon(game_state, definition),
             :ok <- Caster.Player.knows?(game_state, definition, 1, :begin),
             :ok <- CastConditions.check_target(game_state, target, definition),
             :ok <- CastConditions.check_range(game_state, target, definition, level),
             {:ok, module} <- CastConditions.fetch_active_module(definition),
             :ok <- CastConditions.check_cooldown(game_state, skill_id, now),
             :ok <- module.validate(game_state, target, level, definition) do
          {:ok, %{definition: definition, module: module, skill_id: skill_id, level: level}}
        end
    end
  end

  def validate_encore_replay(_game_state, _memory, _target, _now),
    do: {:error, :invalid_replay_memory}

  # `begin?` runs the skill's cast-begin condition after `validate/4`; its
  # caster replaces the context's so the attempt's completion can read it.
  defp validate_and_prepare(%CastContext{} = context, begin?) do
    if context.adapter.cost_before_validation?() do
      with {:ok, context} <- prepare_cast(context),
           :ok <- validate_module(context) do
        begin_context(context, begin?)
      end
    else
      with :ok <- validate_module(context),
           {:ok, context} <- begin_context(context, begin?) do
        prepare_cast(context)
      end
    end
  end

  # The module's `validate/4` carries the reference's pre-payment gates (its
  # target-type and party checks and the skill's own cast-end conditions),
  # which run before the requirement is paid whatever the target's state. The
  # dead-target early return sits below them, inside the implementation, so it
  # settles the cast (`CastConditions.dead_target_skip?/2`) rather than
  # skipping the gates.
  defp validate_module(%CastContext{} = context) do
    context.module.validate(context.caster, context.target, context.level, context.definition)
  end

  defp begin_context(context, false), do: {:ok, context}

  defp begin_context(%CastContext{} = context, true) do
    with {:ok, caster} <-
           begin_attempt(
             context.module,
             context.caster,
             context.target,
             context.level,
             context.definition
           ),
         do: {:ok, %{context | caster: caster}}
  end

  @doc "Runs the skill's optional `begin_attempt/4` on the caster."
  @spec begin_attempt(module(), Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, term()}
  def begin_attempt(module, caster, target, level, definition) do
    if function_exported?(module, :begin_attempt, 4),
      do: module.begin_attempt(caster, target, level, definition),
      else: {:ok, caster}
  end

  defp prepare_cast(%CastContext{adapter: adapter} = context) do
    args = [context.caster, context.module, context.target, context.definition, context.level]

    case :erlang.apply(adapter, cost_callback(adapter, context.phase), args) do
      {:ok, prepared} -> {:ok, %{context | cost: prepared}}
      {:error, _reason} = error -> error
    end
  end

  defp cost_callback(adapter, :completion) do
    if function_exported?(adapter, :castend_cost, 5), do: :castend_cost, else: :cost
  end

  defp cost_callback(_adapter, :begin), do: :cost

  @doc """
  The cast end prepares its cost again on the caster that reaches it; an
  adapter without cast-end requirements keeps the cast-begin cost.
  """
  @spec prepare_castend(CastContext.t(), Active.caster()) ::
          {:ok, CastContext.t()} | {:error, term()}
  def prepare_castend(%CastContext{adapter: adapter} = context, caster) do
    if function_exported?(adapter, :castend_cost, 5),
      do: prepare_cast(%{context | caster: caster, phase: :completion}),
      else: {:ok, context}
  end

  defp check_context_cooldown(%CastContext{} = context, now) do
    adapter = context.adapter

    if adapter.cooldown_ready?(
         context.caster,
         context.definition.id,
         now,
         context.phase
       ),
       do: :ok,
       else: {:error, :on_cooldown}
  end

  defp check_context_act_delay(%CastContext{} = context, now) do
    adapter = context.adapter

    if adapter.act_ready?(context.caster, now),
      do: :ok,
      else: {:error, :act_delayed}
  end
end

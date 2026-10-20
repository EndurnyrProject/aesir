defmodule Aesir.ZoneServer.Mmo.Skill.Unit.UnitTimer do
  @moduledoc """
  The per-cell pass of interval ground fields, run by `Skill.Unit.Manager` on
  every tick.

  A group with a `unit_range` acts as one unit per footprint cell. A pass walks
  every live cell of every such group in skill-unit table order (`order/1`).
  A cell under Land Protector does nothing unless its group ignores Land
  Protector. Otherwise the cell offers its group the combat units within
  `unit_range` cells of it (Chebyshev square, line of sight from the cell when
  the group path-checks) whose strike interval has run out, never an
  invincible player, in the map's block order (`SpatialIndex.units_in_area/5`:
  a trap springs on, and a budget is spent on, the first of them); the group
  keeps the
  ones it may affect (`unit_targets/3`) and strikes each once
  (`on_unit_hit/4`), and that unit's next strike moves to `now + interval`.

  The strike interval is tracked per unit and keyed by skill for a `no_overlap`
  group, so overlapping groups of one skill strike a unit once per interval
  between them, and by group otherwise. A unit first reached mid-interval is
  struck on the next pass. A unit the group does not keep does not spend its
  interval. A group that replaces its unit in place (Fire Pillar's waiting unit
  by its active one) bumps `state.unit_generation`: the replaced unit strikes
  nobody else in that cell, and the replacement starts with fresh intervals, as
  a new group would.

  An `on_unit_hit/4` returning `{:expire, group}` still strikes the rest of
  that cell's units; the group's later cells do nothing and the manager ends
  it after the pass.

  A strike may also return manager commands (`{:ok | :expire, group,
  commands}`) that change other groups (a Claymore Trap spending the traps in
  its blast) or remove the striking group's own cells (a Fire Wall cell whose
  budget ran out). They run at once, so a group they change acts on the rest
  of the pass in its changed state, and a removed cell strikes nobody more. The
  striking group keeps its in-pass state and takes only its remaining cells.
  A command wrapped as `{:after_cell, command}` waits until the cell has struck
  every unit it reaches this pass.

  A group whose module exports `cell_profile/2` may make one cell act as
  another skill for its pass (rAthena `skill_dance_switch`: a song cell
  overlapping another song strikes as Dissonance): the cell's strike skill,
  interval and NoOverlap key its strike intervals and are what the group's
  callbacks see for that cell; `:none` makes the cell do nothing this pass. The
  group keeps its own skill, interval and NoOverlap afterwards.
  """

  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.MobSkill.Event, as: MobSkillEvent
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @table_buckets 283

  @typedoc "One unit's strike interval for one skill (NoOverlap) or one group's unit."
  @type tickset_key ::
          {Ref.t(), {:skill, integer()} | {:group, integer(), non_neg_integer()}}

  @typedoc "The earliest time each unit may be struck again."
  @type ticksets :: %{tickset_key() => integer()}

  @typedoc "Invokes a group callback the way the manager does."
  @type invoke :: (module(), atom(), list() -> {:ok, term()} | {:error, term()})

  @typedoc "How a group left the pass."
  @type outcome :: :ok | :expire | {:failed, atom(), term()}

  @typedoc "Runs a manager command now and returns the groups it changed, as stored."
  @type run_command :: (Ground.command() -> [Group.t()])

  @typedoc "Prepares a cell's current group before it acts, or removes it."
  @type prepare_cell :: (Cell.t(), Group.t(), integer() -> Group.t() | nil)

  @doc """
  Orders cells as the skill-unit table iterates them: by id remainder over its
  283 buckets, then by id.
  """
  @spec order([Cell.t()]) :: [Cell.t()]
  def order(cells), do: Enum.sort_by(cells, &{rem(&1.cell_id, @table_buckets), &1.cell_id})

  @doc """
  Runs one pass over `fields` (`{group, module}` pairs) at `now`.

  Returns every group as it left the pass with its outcome, and the updated
  strike intervals. The optional pre-cell callback settles durability before
  that cell acts, in the same table order as its other timer work.
  """
  @spec run([{Group.t(), module()}], ticksets(), integer(), invoke(), run_command()) ::
          {[{Group.t(), module(), outcome()}], ticksets()}
  @spec run(
          [{Group.t(), module()}],
          ticksets(),
          integer(),
          invoke(),
          run_command(),
          prepare_cell()
        ) ::
          {[{Group.t(), module(), outcome()}], ticksets()}
  def run(
        fields,
        ticksets,
        now,
        invoke,
        run_command \\ fn _command -> [] end,
        prepare_cell \\ fn _cell, group, _now -> group end
      ) do
    ticksets = Map.reject(ticksets, fn {_key, next} -> next <= now end)
    by_id = Map.new(fields, fn {group, module} -> {group.group_id, {group, module, :ok}} end)
    env = %{now: now, invoke: invoke, run_command: run_command, prepare_cell: prepare_cell}

    {by_id, ticksets} =
      fields
      |> Enum.flat_map(fn {group, _module} -> Storage.get_cells_by_group(group.group_id) end)
      |> order()
      |> Enum.reduce({by_id, ticksets}, fn cell, acc -> run_cell(cell, acc, env) end)

    {Map.values(by_id), ticksets}
  end

  defp run_cell(%Cell{group_id: group_id} = cell, {by_id, _ticksets} = acc, env) do
    case Map.fetch(by_id, group_id) do
      {:ok, {group, module, :ok}} ->
        prepare_cell(cell, group, module, acc, env)

      _ended ->
        acc
    end
  end

  defp prepare_cell(cell, group, module, {by_id, ticksets}, env) do
    case env.prepare_cell.(cell, group, env.now) do
      nil ->
        {Map.delete(by_id, group.group_id), ticksets}

      %Group{} = prepared ->
        acc = {Map.put(by_id, group.group_id, {prepared, module, :ok}), ticksets}

        if {cell.x, cell.y} in prepared.cells and not protected?(prepared, cell),
          do: profiled_cell(prepared, module, {cell.x, cell.y}, acc, env),
          else: acc
    end
  end

  defp protected?(group, %Cell{x: x, y: y}) do
    not Group.ignores_land_protector?(group) and Storage.land_protected?(group.map_name, x, y)
  end

  defp profiled_cell(group, module, cell, {by_id, ticksets} = acc, env) do
    if function_exported?(module, :cell_profile, 2) do
      case env.invoke.(module, :cell_profile, [group, cell]) do
        {:ok, :none} ->
          acc

        {:ok, %{skill_id: _, interval: _, no_overlap: _} = profile} ->
          strike_cell(group, module, cell, acc, Map.put(env, :profile, profile))

        {:ok, other} ->
          failed = {group, module, {:failed, :cell_profile, {:invalid_return, other}}}
          {Map.put(by_id, group.group_id, failed), ticksets}

        {:error, reason} ->
          {Map.put(by_id, group.group_id, {group, module, {:failed, :cell_profile, reason}}),
           ticksets}
      end
    else
      strike_cell(group, module, cell, acc, env)
    end
  end

  defp profiled(group, %{profile: profile}), do: Map.merge(group, profile)
  defp profiled(group, _env), do: group

  defp restore(%Group{} = struck, %Group{} = own),
    do: %{struck | skill_id: own.skill_id, interval: own.interval, no_overlap: own.no_overlap}

  defp strike_cell(own, module, cell, {by_id, ticksets} = acc, %{now: now} = env) do
    group = profiled(own, env)

    due =
      Enum.filter(
        reached(group, cell),
        &(Map.get(ticksets, key(group, &1), now) <= now and not Invincibility.active?(&1))
      )

    case due do
      [] ->
        acc

      refs ->
        case env.invoke.(module, :unit_targets, [group, cell, refs]) do
          {:ok, kept} when is_list(kept) ->
            {by_id, ticksets, deferred} =
              strike_targets(group, module, cell, Enum.filter(refs, &(&1 in kept)), acc, env)

            {run_commands(Enum.uniq(deferred), by_id, group.group_id, env), ticksets}

          {:ok, other} ->
            failed = {own, module, {:failed, :unit_targets, {:invalid_return, other}}}
            {Map.put(by_id, group.group_id, failed), ticksets}

          {:error, reason} ->
            failed = {own, module, {:failed, :unit_targets, reason}}
            {Map.put(by_id, group.group_id, failed), ticksets}
        end
    end
  end

  defp strike_targets(group, module, cell, refs, {by_id, ticksets}, %{now: now} = env) do
    Enum.reduce_while(refs, {by_id, ticksets, []}, fn ref, {by_id, ticksets, deferred} ->
      {own, _module, outcome} = Map.fetch!(by_id, group.group_id)
      group = profiled(own, env)
      ticksets = Map.put(ticksets, key(group, ref), now + group.interval)

      case strike(env, module, [group, cell, ref, now], group.group_id) do
        {:failed, reason} ->
          failed = {own, module, {:failed, :on_unit_hit, reason}}
          {:halt, {Map.put(by_id, group.group_id, failed), ticksets, deferred}}

        {tag, struck, commands} ->
          struck = restore(struck, own)
          {later, now_commands} = Enum.split_with(commands, &match?({:after_cell, _}, &1))
          by_id = Map.put(by_id, group.group_id, {struck, module, outcome(tag, outcome)})
          by_id = run_commands(now_commands, by_id, group.group_id, env)
          notify_skill_used(group, ref, now)
          continue_cell(group, cell, by_id, ticksets, deferred ++ unwrap(later))
      end
    end)
  end

  defp outcome(:expire, _outcome), do: :expire
  defp outcome(:ok, outcome), do: outcome

  defp unwrap(after_cell), do: Enum.map(after_cell, fn {:after_cell, command} -> command end)

  # The source's ground-unit tail, the last thing its per-target interval pass
  # does: a struck monster is told the field's skill was used on it, unless
  # that monster is the field's own source.
  defp notify_skill_used(%Group{skill_id: skill_id, caster_type: type, caster_id: id}, ref, now) do
    if {type, id} == ref,
      do: :ok,
      else: MobSkillEvent.deliver({type, id}, {:skillused, skill_id}, ref, now)
  end

  # A replaced or removed unit strikes nobody else in the cell.
  defp continue_cell(group, cell, by_id, ticksets, deferred) do
    {struck, _module, _outcome} = Map.fetch!(by_id, group.group_id)

    if generation(struck) == generation(group) and cell in struck.cells,
      do: {:cont, {by_id, ticksets, deferred}},
      else: {:halt, {by_id, ticksets, deferred}}
  end

  defp strike(env, module, args, group_id) do
    case env.invoke.(module, :on_unit_hit, args) do
      {:ok, {tag, %Group{group_id: ^group_id} = struck}} when tag in [:ok, :expire] ->
        {tag, struck, []}

      {:ok, {tag, %Group{group_id: ^group_id} = struck, commands}}
      when tag in [:ok, :expire] and is_list(commands) ->
        {tag, struck, commands}

      {:ok, other} ->
        {:failed, {:invalid_return, other}}

      {:error, reason} ->
        {:failed, reason}
    end
  end

  defp run_commands(commands, by_id, striking_id, env) do
    commands
    |> Enum.flat_map(env.run_command)
    |> Enum.reduce(by_id, fn %Group{group_id: id} = changed, by_id ->
      case Map.fetch(by_id, id) do
        {:ok, {group, module, outcome}} when id == striking_id ->
          Map.put(by_id, id, {%{group | cells: changed.cells}, module, outcome})

        {:ok, {_group, module, outcome}} ->
          Map.put(by_id, id, {changed, module, outcome})

        :error ->
          by_id
      end
    end)
  end

  defp reached(%Group{map_name: map_name, unit_range: range} = group, {x, y} = cell) do
    map_name
    |> SpatialIndex.units_in_area(x - range, y - range, x + range, y + range)
    |> Enum.filter(fn {unit_type, unit_id} = ref ->
      CombatTarget.combat_unit?(ref) and
        (not group.path_check or sighted?(map_name, cell, unit_type, unit_id))
    end)
  end

  defp sighted?(map_name, cell, unit_type, unit_id) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {tx, ty, ^map_name}} -> LineOfSight.clear?(map_name, cell, {tx, ty})
      _elsewhere -> false
    end
  end

  defp key(%Group{no_overlap: true, skill_id: skill_id}, ref), do: {ref, {:skill, skill_id}}

  defp key(%Group{group_id: group_id} = group, ref),
    do: {ref, {:group, group_id, generation(group)}}

  defp generation(%Group{state: state}), do: Map.get(state, :unit_generation, 0)
end

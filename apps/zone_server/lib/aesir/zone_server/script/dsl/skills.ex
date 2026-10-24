defmodule Aesir.ZoneServer.Script.Dsl.Skills do
  @moduledoc """
  Skill buildins for the script DSL: NPC-sourced supportive casts, skill
  visual effects, item-granted casts, permanent skill grants, skill resets,
  and the Basic Skill enforcement flag.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal,
    only: [apply_op: 2, resolve_skill_id: 1]

  require Logger

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Npc.SkillCaster
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Broadcast

  @npcskill_min_stat 1
  @npcskill_max_stat 255

  @doc """
  Casts a supportive skill from the running NPC on the attached player.

  `skill` accepts a catalog name, numeric id, or string name; `level` is
  clamped to the skill's maximum (a non-positive level warns and no-ops). `stat_point` and `npc_level` supply the
  synthetic caster stats, each clamped to `1..255`. A successful cast sends a
  skill-effect visual sourced from the NPC. Unknown or unsupported skills, cast
  failures, and a missing NPC leave the context unchanged; a detached ctx halts
  `:no_player`.
  """
  @spec npcskill(Ctx.t(), atom() | integer() | String.t(), integer(), integer(), integer()) ::
          Ctx.t()
  def npcskill(%Ctx{status: {:error, _}} = ctx, _skill, _level, _stat_point, _npc_level), do: ctx

  def npcskill(%Ctx{game_state: nil} = ctx, _skill, _level, _stat_point, _npc_level),
    do: Ctx.halt(ctx, :no_player)

  def npcskill(%Ctx{npc_gid: nil} = ctx, skill, _level, _stat_point, _npc_level) do
    Logger.warning("npcskill called without an NPC for #{inspect(skill)}")
    ctx
  end

  def npcskill(%Ctx{} = ctx, skill, level, stat_point, npc_level) do
    with {:ok, definition} <- resolve_npcskill_definition(skill),
         caster <-
           SkillCaster.new(
             ctx.npc_gid,
             clamp_npcskill_stat(stat_point),
             clamp_npcskill_stat(npc_level),
             {ctx.game_state.x, ctx.game_state.y},
             ctx.game_state.map_name
           ),
         {:ok, _} <- SkillInterpreter.npc_cast(caster, definition.id, level, {:unit, ctx.char_id}) do
      Broadcast.to_in_range(
        ctx.game_state.map_name,
        ctx.game_state.x,
        ctx.game_state.y,
        Config.view_range(),
        %SkillEffect{
          skill_id: definition.id,
          level: min(level, definition.max_level),
          src_id: ctx.npc_gid,
          target_id: ctx.char_id,
          result: 1
        }
      )
    else
      :error ->
        Logger.warning(
          "npcskill failed for #{inspect(skill)} from NPC #{ctx.npc_gid}: unknown skill"
        )

      {:error, reason} ->
        Logger.warning("npcskill failed for #{inspect(skill)} from NPC #{ctx.npc_gid}: #{reason}")
    end

    ctx
  end

  @doc """
  Plays a skill's visual effect on the attached player, shown to every player
  in view range (rAthena `skilleffect`). `skill` accepts a numeric id (sent
  verbatim, matching an un-cataloged skill's client-side animation) or a
  catalog name atom/string; `level` is passed through. The optional rAthena
  target argument is dropped — the effect always plays on the invoking
  player. Purely cosmetic, so a detached ctx or an unresolvable name is a
  silent no-op rather than a halt.
  """
  @spec skilleffect(Ctx.t(), atom() | integer() | String.t(), integer()) :: Ctx.t()
  def skilleffect(%Ctx{status: {:error, _}} = ctx, _skill, _level), do: ctx
  def skilleffect(%Ctx{game_state: nil} = ctx, _skill, _level), do: ctx

  def skilleffect(%Ctx{} = ctx, skill, level) do
    case skilleffect_id(skill) do
      {:ok, skill_id} ->
        Broadcast.to_in_range(
          ctx.game_state.map_name,
          ctx.game_state.x,
          ctx.game_state.y,
          Config.view_range(),
          %SkillEffect{
            skill_id: skill_id,
            level: max(level, 0),
            src_id: ctx.char_id,
            target_id: ctx.char_id,
            result: 1
          }
        )

      :error ->
        Logger.warning("skilleffect: unknown skill #{inspect(skill)}, skipping")
    end

    ctx
  end

  # Numeric ids pass through so a skill the server has not implemented still
  # shows its client-side animation; names resolve via the skill catalog.
  defp skilleffect_id(skill) when is_integer(skill), do: {:ok, skill}
  defp skilleffect_id(skill) when is_atom(skill), do: catalog_skill_id(skill)

  defp skilleffect_id(skill) when is_binary(skill) do
    skill
    |> String.downcase()
    |> String.to_existing_atom()
    |> catalog_skill_id()
  rescue
    ArgumentError -> :error
  end

  defp skilleffect_id(_skill), do: :error

  defp catalog_skill_id(name) do
    case Catalog.by_name(name) do
      {:ok, definition} -> {:ok, definition.id}
      :error -> :error
    end
  end

  defp resolve_npcskill_definition(skill) when is_atom(skill), do: Catalog.by_name(skill)
  defp resolve_npcskill_definition(skill) when is_integer(skill), do: Catalog.by_id(skill)

  defp resolve_npcskill_definition(skill) when is_binary(skill) do
    skill
    |> String.downcase()
    |> String.to_existing_atom()
    |> Catalog.by_name()
  rescue
    ArgumentError -> :error
  end

  defp resolve_npcskill_definition(_skill), do: :error

  defp clamp_npcskill_stat(value), do: value |> max(@npcskill_min_stat) |> min(@npcskill_max_stat)

  @doc """
  Stages one item-granted skill in the owning player session. The client chooses
  its target using the ordinary skill intent; no cast or skill requirement is
  consumed while the script runs. `skill_id_or_name` is a catalog id or name;
  `:level` defaults to 1. An unknown skill fails the command and the script goes
  on; a detached ctx halts `:no_player`.
  """
  @spec itemskill(Ctx.t(), integer() | atom(), keyword()) :: Ctx.t()
  def itemskill(%Ctx{status: {:error, _}} = ctx, _skill, _opts), do: ctx
  def itemskill(%Ctx{game_state: nil} = ctx, _skill, _opts), do: Ctx.halt(ctx, :no_player)

  def itemskill(%Ctx{} = ctx, skill_id_or_name, opts) do
    level = Keyword.get(opts, :level, 1)
    keep_requirement? = Keyword.get(opts, :keep_requirement, false)

    case resolve_skill_id(skill_id_or_name) do
      {:ok, skill_id} -> stage_item_skill(ctx, skill_id, level, keep_requirement?)
      {:error, reason} -> Ctx.fail(ctx, :itemskill, reason)
    end
  end

  defp stage_item_skill(%Ctx{session_pid: nil, source: {:item, _}} = ctx, skill_id, level, keep?) do
    %{ctx | session_effects: ctx.session_effects ++ [{:item_skill, skill_id, level, keep?}]}
  end

  defp stage_item_skill(ctx, skill_id, level, keep?),
    do: apply_op(ctx, {:stage_item_skill, skill_id, level, keep?})

  @doc """
  Opens the production list for `trigger` (rAthena `produce`), the list a hammer
  or furnace shows: see
  `Aesir.ZoneServer.Mmo.ItemManagement.Production.Produce`. Only an item script can open it;
  any other source fails the command and the script goes on.
  """
  @spec produce(Ctx.t(), integer()) :: Ctx.t()
  def produce(%Ctx{status: {:error, _}} = ctx, _trigger), do: ctx

  def produce(%Ctx{session_pid: nil, source: {:item, _}} = ctx, trigger) when is_integer(trigger),
    do: %{ctx | session_effects: ctx.session_effects ++ [{:produce, trigger}]}

  def produce(%Ctx{} = ctx, _trigger), do: Ctx.fail(ctx, :produce, :unsupported_source)

  @doc """
  Casts a skill from the player's own unit (rAthena `unitskilluseid`), the cast
  an Emergency Scroll or rune item starts from its script. The skill needs no
  learned rank; every other cast-begin and cast-end condition applies (SP, HP,
  zeny, weight, weapon, items), and the cast starts at once - a timed cast
  opens the ordinary cast bar. `skill_id_or_name` is a catalog id or name;
  `:level` defaults to 1. An unknown skill, or a detached ctx with no unit to cast
  from, fails the command and the script goes on.
  """
  @spec unitskilluseid(Ctx.t(), integer() | atom(), keyword()) :: Ctx.t()
  def unitskilluseid(%Ctx{status: {:error, _}} = ctx, _skill, _opts), do: ctx

  def unitskilluseid(%Ctx{game_state: nil} = ctx, _skill, _opts),
    do: Ctx.fail(ctx, :unitskilluseid, :no_player)

  def unitskilluseid(%Ctx{} = ctx, skill_id_or_name, opts) do
    level = Keyword.get(opts, :level, 1)

    case resolve_skill_id(skill_id_or_name) do
      {:ok, skill_id} -> stage_unit_skill_use(ctx, skill_id, level)
      {:error, reason} -> Ctx.fail(ctx, :unitskilluseid, reason)
    end
  end

  defp stage_unit_skill_use(%Ctx{session_pid: nil, source: {:item, _}} = ctx, skill_id, level) do
    %{ctx | session_effects: ctx.session_effects ++ [{:unit_skill_use, skill_id, level}]}
  end

  defp stage_unit_skill_use(ctx, skill_id, level),
    do: apply_op(ctx, {:unitskilluseid, skill_id, level})

  @doc """
  Refunds the player's learned skills into skill points through the session seam
  (rAthena `resetskill`), recomputing stats, refreshing the skill window, and
  persisting. `NV_BASIC` is kept (not refunded) unless the player is a Novice.
  An active cart refuses the reset: the command fails and the script goes on.
  """
  @spec reset_skills(Ctx.t()) :: Ctx.t()
  def reset_skills(%Ctx{status: {:error, _}} = ctx), do: ctx
  def reset_skills(%Ctx{} = ctx), do: apply_op(ctx, {:reset_skills})

  @doc """
  Grants a skill permanently through the session seam (rAthena `skill
  <id>,<level>{,<flag>}` - the "platinum skill" style permanent grant outside
  the normal skill tree). Aesir implements only the permanent-grant flag
  (rAthena's `SKILL_PERM`); `flag` is accepted for source compatibility with
  transpiled scripts but is otherwise unused. `skill` is a skill id or its
  catalog name atom.

  The session keeps `max(existing, requested)` as the learned level and never
  spends or refunds a skill point, so a repeat or lower-level grant is a
  no-op. A `level` of `0` removes the skill instead, which job-change scripts
  use to strip a platinum skill; removing an unlearned skill is a no-op.
  An unknown skill, an invalid level, or a definition without quest-grant
  metadata fails the command and the script goes on, without mutation; a
  detached ctx halts `:no_player`.
  """
  @spec skill(Ctx.t(), integer() | atom(), integer(), integer() | atom()) :: Ctx.t()
  def skill(%Ctx{status: {:error, _}} = ctx, _skill, _level, _flag), do: ctx

  def skill(%Ctx{} = ctx, skill_id_or_name, level, _flag),
    do: apply_op(ctx, {:grant_skill, skill_id_or_name, level})

  @doc """
  Whether the server enforces Basic Skill requirements (rAthena
  `basicskillcheck`, the `basic_skill_check` battle flag). Aesir always
  enforces them (the storage gate requires `NV_BASIC`), so this is always
  `1`. Pure read; the ctx is ignored.
  """
  @spec basicskillcheck(Ctx.t()) :: 1
  def basicskillcheck(%Ctx{}), do: 1
end

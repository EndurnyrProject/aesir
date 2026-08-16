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
  Casts a skill programmatically on the player.

  `skill_id_or_name` is a skill id or its catalog name atom. `opts` accepts
  `:level` (default 1) and `:target` (default `:self`). Halts on a cast error or
  an unknown skill name. Halts `:no_player` on a detached ctx.

  The item is the cost, so this runs through `SkillInterpreter.item_cast/4`: the
  player need not have learned the skill and no SP, zeny, catalyst or ammo is
  required or charged.
  """
  @spec itemskill(Ctx.t(), integer() | atom(), keyword()) :: Ctx.t()
  def itemskill(%Ctx{status: {:error, _}} = ctx, _skill, _opts), do: ctx
  def itemskill(%Ctx{game_state: nil} = ctx, _skill, _opts), do: Ctx.halt(ctx, :no_player)

  def itemskill(%Ctx{} = ctx, skill_id_or_name, opts) do
    level = Keyword.get(opts, :level, 1)
    target = Keyword.get(opts, :target, :self)

    with {:ok, skill_id} <- resolve_skill_id(skill_id_or_name),
         {:ok, new_game_state} <-
           SkillInterpreter.item_cast(ctx.game_state, skill_id, level, target) do
      %{ctx | game_state: new_game_state}
    else
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Refunds the player's learned skills into skill points through the session seam
  (rAthena `resetskill`), recomputing stats, refreshing the skill window, and
  persisting. `NV_BASIC` is kept (not refunded) unless the player is a Novice.
  Never fails.
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
  no-op. Halts `:unknown_skill`, `:invalid_level`, or `:not_grantable` (a
  definition without quest-grant metadata) without mutation; halts
  `:no_player` on a detached ctx.
  """
  @spec skill(Ctx.t(), integer() | atom(), pos_integer(), integer() | atom()) :: Ctx.t()
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

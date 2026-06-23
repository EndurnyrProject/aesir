defmodule Aesir.ZoneServer.Script.Dsl do
  @moduledoc """
  The item/NPC scripting DSL: the effect and read primitives every script uses.

  Functions are plain and take the script `Ctx` first so they can be `import`ed
  into a generated module or called directly from an NPC module. They split into
  two groups:

  - **Effects** (`(ctx, args) -> ctx`) short-circuit when `ctx.status` is already
    an error, perform their subsystem side effect synchronously inside the player
    session, thread the resulting `PlayerState` back into `ctx.game_state`, and
    halt the context with `Ctx.halt/2` on a subsystem error.
  - **Reads** (`(ctx) -> value`) pull a value out of `ctx.game_state` and ignore
    status.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @typedoc "An HP/SP heal amount: a flat integer or a `lo..hi` range to roll within."
  @type amount :: integer() | Range.t()

  @doc """
  Restores HP and/or SP by the given amounts, clamped to the player's maxima.

  `opts` accepts `:hp` and `:sp`, each a flat integer or a `lo..hi` range from
  which a value is rolled. The new value is pushed to the client and persisted.
  """
  @spec heal(Ctx.t(), keyword()) :: Ctx.t()
  def heal(%Ctx{status: {:error, _}} = ctx, _opts), do: ctx

  def heal(%Ctx{} = ctx, opts) do
    apply_heal(ctx, fn current, _max -> current + roll(Keyword.get(opts, :hp, 0)) end, fn
      current, _max -> current + roll(Keyword.get(opts, :sp, 0))
    end)
  end

  @doc """
  Restores HP and/or SP by a percentage of the player's maxima.

  `opts` accepts `:hp` and `:sp` as integer percents applied to `max_hp`/`max_sp`.
  """
  @spec percent_heal(Ctx.t(), keyword()) :: Ctx.t()
  def percent_heal(%Ctx{status: {:error, _}} = ctx, _opts), do: ctx

  def percent_heal(%Ctx{} = ctx, opts) do
    apply_heal(
      ctx,
      fn current, max -> current + div(max * Keyword.get(opts, :hp, 0), 100) end,
      fn current, max -> current + div(max * Keyword.get(opts, :sp, 0), 100) end
    )
  end

  @doc """
  Applies a status effect to the player for `duration_ms` with strength `val`.

  The status lives in external storage, not in `game_state`, so the context is
  returned unchanged.
  """
  @spec sc_start(Ctx.t(), atom(), non_neg_integer(), integer()) :: Ctx.t()
  def sc_start(%Ctx{status: {:error, _}} = ctx, _status, _duration_ms, _val), do: ctx

  def sc_start(%Ctx{} = ctx, status, duration_ms, val) do
    StatusInterpreter.apply_status(:player, ctx.char_id, status, val1: val, duration: duration_ms)
    ctx
  end

  @doc """
  Removes a status effect from the player. Returns the context unchanged.
  """
  @spec cure(Ctx.t(), atom()) :: Ctx.t()
  def cure(%Ctx{status: {:error, _}} = ctx, _status), do: ctx

  def cure(%Ctx{} = ctx, status) do
    StatusInterpreter.remove_status(:player, ctx.char_id, status)
    ctx
  end

  @doc """
  Relocates the player to `(map, x, y)`. Halts on `:map_not_found`/`:cell_blocked`.
  """
  @spec warp(Ctx.t(), {String.t(), non_neg_integer(), non_neg_integer()}) :: Ctx.t()
  def warp(%Ctx{} = ctx, {map, x, y}), do: warp(ctx, map, x, y)

  @spec warp(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def warp(%Ctx{status: {:error, _}} = ctx, _map, _x, _y), do: ctx

  def warp(%Ctx{} = ctx, map, x, y) do
    session = %{game_state: ctx.game_state, connection_pid: ctx.connection_pid}

    case WarpHandler.warp(session, map, x, y) do
      {:ok, %{game_state: new_game_state}} -> %{ctx | game_state: new_game_state}
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Casts a skill programmatically on the player.

  `skill_id_or_name` is a skill id or its catalog name atom. `opts` accepts
  `:level` (default 1) and `:target` (default `:self`). Halts on a cast error or
  an unknown skill name.
  """
  @spec itemskill(Ctx.t(), integer() | atom(), keyword()) :: Ctx.t()
  def itemskill(%Ctx{status: {:error, _}} = ctx, _skill, _opts), do: ctx

  def itemskill(%Ctx{} = ctx, skill_id_or_name, opts) do
    level = Keyword.get(opts, :level, 1)
    target = Keyword.get(opts, :target, :self)

    with {:ok, skill_id} <- resolve_skill_id(skill_id_or_name),
         {:ok, new_game_state} <- SkillInterpreter.cast(ctx.game_state, skill_id, level, target) do
      %{ctx | game_state: new_game_state}
    else
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Spawns a monster on the player's current map, registered so it is attackable.

  `opts` accepts `:mob_id` or `:mob_name` (one is required; `:mob_name` is the
  AEGIS name, matching `MobManagement.get_mob_by_name/1`), `:at` as a `{x, y}`
  tuple (defaults to the player's current position), and `:aggressive` (accepted
  but deferred in Phase 1, kept for the Dead Branch interface). Halts on an
  unknown mob or a spawn failure; returns the context unchanged on success.
  """
  @spec summon_mob(Ctx.t(), keyword()) :: Ctx.t()
  def summon_mob(%Ctx{status: {:error, _}} = ctx, _opts), do: ctx

  def summon_mob(%Ctx{} = ctx, opts) do
    case resolve_mob(opts) do
      {:ok, mob_data} -> spawn_mob_at(ctx, mob_data.id, opts)
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Spawns a random monster from the catalog, like `summon_mob/2` with a rolled id.

  `opts` accepts `:at` (defaults to the player's position) and `:aggressive`.
  Halts with `:no_mobs` if the catalog is empty.
  """
  @spec summon_random_mob(Ctx.t(), keyword()) :: Ctx.t()
  def summon_random_mob(%Ctx{status: {:error, _}} = ctx, _opts), do: ctx

  def summon_random_mob(%Ctx{} = ctx, opts) do
    case MobManagement.get_all_mobs() do
      [] -> Ctx.halt(ctx, :no_mobs)
      mobs -> spawn_mob_at(ctx, Enum.random(mobs).id, opts)
    end
  end

  @doc "The player's base level."
  @spec base_level(Ctx.t()) :: non_neg_integer()
  def base_level(%Ctx{game_state: gs}), do: gs.stats.progression.base_level

  @doc "The player's job level."
  @spec job_level(Ctx.t()) :: non_neg_integer()
  def job_level(%Ctx{game_state: gs}), do: gs.stats.progression.job_level

  @doc "The player's job as an atom."
  @spec class(Ctx.t()) :: atom()
  def class(%Ctx{game_state: gs}) do
    {:ok, job} = JobManagement.get_job_by_id(gs.stats.progression.job_id)
    job.name
  end

  @doc "The player's sex."
  @spec sex(Ctx.t()) :: String.t()
  def sex(%Ctx{game_state: gs}), do: gs.sex

  @doc "The player's current HP."
  @spec hp(Ctx.t()) :: non_neg_integer()
  def hp(%Ctx{game_state: gs}), do: gs.stats.current_state.hp

  @doc "The player's current SP."
  @spec sp(Ctx.t()) :: non_neg_integer()
  def sp(%Ctx{game_state: gs}), do: gs.stats.current_state.sp

  @doc "The player's maximum HP."
  @spec max_hp(Ctx.t()) :: non_neg_integer()
  def max_hp(%Ctx{game_state: gs}), do: gs.stats.derived_stats.max_hp

  @doc "The player's current carried weight."
  @spec weight(Ctx.t()) :: non_neg_integer()
  def weight(%Ctx{game_state: gs}), do: Weight.current_weight(gs.inventory)

  @doc "The player's position as `{x, y, map_name}`."
  @spec position(Ctx.t()) :: {integer(), integer(), String.t()}
  def position(%Ctx{game_state: gs}), do: {gs.x, gs.y, gs.map_name}

  @doc "Whether the player has an item with `item_id` equipped."
  @spec is_equipped(Ctx.t(), integer()) :: boolean()
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_equipped(%Ctx{game_state: gs}, item_id) do
    gs.inventory
    |> Inventory.equipped_items()
    |> Enum.any?(fn {_index, %InventoryItem{nameid: nameid}} -> nameid == item_id end)
  end

  defp apply_heal(%Ctx{} = ctx, hp_fun, sp_fun) do
    stats = ctx.game_state.stats
    current = stats.current_state
    max_hp = stats.derived_stats.max_hp
    max_sp = stats.derived_stats.max_sp

    new_hp = clamp(hp_fun.(current.hp, max_hp), max_hp)
    new_sp = clamp(sp_fun.(current.sp, max_sp), max_sp)

    new_state = %{current | hp: new_hp, sp: new_sp}
    game_state = %{ctx.game_state | stats: %{stats | current_state: new_state}}

    sync_hp(ctx, current.hp, new_hp)
    sync_sp(ctx, current.sp, new_sp)

    %{ctx | game_state: game_state}
  end

  defp sync_hp(_ctx, same, same), do: :ok

  defp sync_hp(ctx, _old, new_hp) do
    StatusSync.send_param(ctx.connection_pid, StatusParams.hp(), new_hp)
    CharacterPersistence.update_stats(ctx.char_id, %{hp: new_hp}, async: true)
  end

  defp sync_sp(_ctx, same, same), do: :ok

  defp sync_sp(ctx, _old, new_sp) do
    StatusSync.send_param(ctx.connection_pid, StatusParams.sp(), new_sp)
    CharacterPersistence.update_stats(ctx.char_id, %{sp: new_sp}, async: true)
  end

  defp clamp(value, max), do: value |> min(max) |> max(0)

  defp roll(lo..hi//_step), do: lo + :rand.uniform(hi - lo + 1) - 1
  defp roll(amount) when is_integer(amount), do: amount

  defp resolve_skill_id(skill_id) when is_integer(skill_id), do: {:ok, skill_id}

  defp resolve_skill_id(name) when is_atom(name) do
    case Catalog.by_name(name) do
      {:ok, definition} -> {:ok, definition.id}
      :error -> {:error, :unknown_skill}
    end
  end

  defp resolve_mob(opts) do
    case {Keyword.get(opts, :mob_id), Keyword.get(opts, :mob_name)} do
      {id, _} when is_integer(id) -> MobManagement.get_mob_by_id(id)
      {_, name} when is_binary(name) -> MobManagement.get_mob_by_name(name)
      _ -> {:error, :mob_not_found}
    end
  end

  defp spawn_mob_at(%Ctx{game_state: gs} = ctx, mob_id, opts) do
    {x, y} = Keyword.get(opts, :at, {gs.x, gs.y})

    case Coordinator.summon_mob(gs.map_name, mob_id, x, y, aggressive: aggressive?(opts)) do
      {:ok, _instance_id} -> ctx
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  defp aggressive?(opts), do: Keyword.get(opts, :aggressive, false)
end

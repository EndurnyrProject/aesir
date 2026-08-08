defmodule Aesir.ZoneServer.Mmo.Skill.Passives do
  @moduledoc """
  Aggregation surface for passive skills.

  Walks a player's learned skills, keeps the ones that resolve to a passive-capable
  module via `Skill.Catalog`, builds the shared `Passive.ctx`, and folds each
  effect channel (ATK, regen, skill riders). `use Skill` injects no-op defaults
  for the channels a passive does not implement, so the callbacks can be invoked
  directly here; an unimplemented channel contributes its neutral element
  (0 / `%{}` / `:none`).

  Consumers (the stat pipeline, the natural-heal tick, SmBash) call this module
  instead of iterating `learned_skills` directly.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @typedoc "Aggregated regen contribution from all learned passives."
  @type regen :: %{
          skill_hp_regen: integer(),
          skill_sp_regen: integer(),
          allow_while_moving: boolean()
        }

  @typedoc "Aggregated regeneration that only applies while sitting."
  @type sitting_regen :: %{sitting_hp_regen: integer(), sitting_sp_regen: integer()}

  @typedoc "A skill rider produced by a passive."
  @type rider :: {:apply_status, atom(), keyword()}

  @doc """
  Invokes the `after_normal_hit` callback of every learned passive.

  Called by the combat layer once a player's ordinary weapon hit is confirmed;
  each learned passive receives the attacker state and the immutable hit
  context. Player states without computed stats (or non-player callers) are
  no-ops.
  """
  @spec after_normal_hit(PlayerState.t(), Passive.hit_context()) :: :ok
  def after_normal_hit(%PlayerState{stats: %PlayerStats{} = stats} = player_state, hit) do
    stats
    |> learned_passives()
    |> Enum.each(fn {module, _level} -> module.after_normal_hit(player_state, hit) end)
  end

  def after_normal_hit(_player_state, _hit), do: :ok

  @doc """
  Selects the first learned passive that replaces a normal attack.

  Learned skills are checked by skill id so selection stays deterministic.
  Players without such a passive return `:normal` without affecting combat.
  """
  @spec attack_replacement(PlayerState.t()) :: Passive.attack_replacement()
  def attack_replacement(%PlayerState{stats: %PlayerStats{} = stats}) do
    ctx = build_ctx(stats)

    stats.progression.learned_skills
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce_while(:normal, fn {skill_id, level}, :normal ->
      case replacement_for(skill_id, level, ctx) do
        :normal -> {:cont, :normal}
        replacement -> {:halt, replacement}
      end
    end)
  end

  def attack_replacement(_player_state), do: :normal

  defp replacement_for(skill_id, level, ctx) do
    with {:ok, definition} <- Catalog.by_id(skill_id),
         {:ok, module} <- Catalog.passive_module_for(definition.name),
         true <- function_exported?(module, :attack_replacement, 2) do
      module.attack_replacement(level, ctx)
    else
      _other -> :normal
    end
  end

  @doc """
  Sums the ATK bonus contributed by every learned passive for the player.
  """
  @spec atk_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def atk_bonus(%PlayerState{stats: stats}), do: atk_bonus(stats)

  def atk_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.atk_bonus(level, ctx)
    end)
  end

  @doc """
  Returns the right-hand dual-wield damage rate, defaulting to 50% without a mastery.
  """
  @spec right_hand_damage_rate(PlayerState.t() | PlayerStats.t()) :: non_neg_integer()
  def right_hand_damage_rate(%PlayerState{stats: stats}), do: right_hand_damage_rate(stats)

  def right_hand_damage_rate(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(50, fn {module, level}, rate ->
      case module.right_hand_damage_rate(level, ctx) do
        0 -> rate
        replacement -> replacement
      end
    end)
  end

  @doc """
  Returns the left-hand dual-wield damage rate, defaulting to 30% without a mastery.
  """
  @spec left_hand_damage_rate(PlayerState.t() | PlayerStats.t()) :: non_neg_integer()
  def left_hand_damage_rate(%PlayerState{stats: stats}), do: left_hand_damage_rate(stats)

  def left_hand_damage_rate(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(30, fn {module, level}, rate ->
      case module.left_hand_damage_rate(level, ctx) do
        0 -> rate
        replacement -> replacement
      end
    end)
  end

  @doc """
  Returns the Katar secondary damage rate, defaulting to 1% without Double Attack.
  """
  @spec katar_secondary_rate(PlayerState.t() | PlayerStats.t()) :: non_neg_integer()
  def katar_secondary_rate(%PlayerState{stats: stats}), do: katar_secondary_rate(stats)

  def katar_secondary_rate(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(1, fn {module, level}, rate ->
      case module.katar_secondary_rate(level, ctx) do
        0 -> rate
        replacement -> replacement
      end
    end)
  end

  @doc """
  Sums the multiplicative hit-rate bonus percentage contributed by every learned passive.
  """
  @spec hit_rate_bonus_pct(PlayerState.t() | PlayerStats.t()) :: integer()
  def hit_rate_bonus_pct(%PlayerState{stats: nil}), do: 0
  def hit_rate_bonus_pct(%PlayerState{stats: stats}), do: hit_rate_bonus_pct(stats)

  def hit_rate_bonus_pct(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      if function_exported?(module, :hit_rate_bonus_pct, 2) do
        acc + module.hit_rate_bonus_pct(level, ctx)
      else
        acc
      end
    end)
  end

  @doc """
  Sums the rAthena-tenths critical bonus contributed by every learned passive for
  the player.
  """
  @spec critical_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def critical_bonus(%PlayerState{stats: stats}), do: critical_bonus(stats)

  def critical_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.critical_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the FLEE bonus contributed by every learned passive for the player.
  """
  @spec flee_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def flee_bonus(%PlayerState{stats: stats}), do: flee_bonus(stats)

  def flee_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.flee_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the DEX bonus contributed by every learned passive for the player.
  """
  @spec dex_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def dex_bonus(%PlayerState{stats: stats}), do: dex_bonus(stats)

  def dex_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.dex_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the STR bonus contributed by every learned passive for the player.
  """
  @spec str_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def str_bonus(%PlayerState{stats: stats}), do: str_bonus(stats)

  def str_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.str_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the HIT bonus contributed by every learned passive for the player.
  """
  @spec hit_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def hit_bonus(%PlayerState{stats: stats}), do: hit_bonus(stats)

  def hit_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.hit_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the attack-range bonus contributed by every learned passive for the player.
  """
  @spec range_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def range_bonus(%PlayerState{stats: stats}), do: range_bonus(stats)

  def range_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.range_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the max-weight bonus contributed by every learned passive for the player.
  """
  @spec max_weight_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def max_weight_bonus(%PlayerState{stats: stats}), do: max_weight_bonus(stats)

  def max_weight_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.max_weight_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the flat ASPD bonus contributed by every learned passive for the player.
  """
  @spec aspd_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def aspd_bonus(%PlayerState{stats: stats}), do: aspd_bonus(stats)

  def aspd_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.aspd_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the flat INT bonus contributed by every learned passive for the player.
  """
  @spec int_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def int_bonus(%PlayerState{stats: stats}), do: int_bonus(stats)

  def int_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.int_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the flat max-HP bonus contributed by every learned passive for the player.
  """
  @spec max_hp_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def max_hp_bonus(%PlayerState{stats: stats}), do: max_hp_bonus(stats)

  def max_hp_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.max_hp_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the MaxSP rate bonus contributed by every learned passive for the player.
  """
  @spec max_sp_rate_bonus(PlayerState.t() | PlayerStats.t()) :: integer()
  def max_sp_rate_bonus(%PlayerState{stats: stats}), do: max_sp_rate_bonus(stats)

  def max_sp_rate_bonus(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.max_sp_rate_bonus(level, ctx)
    end)
  end

  @doc """
  Sums the zeny cost reduction percentage contributed by every learned passive.
  """
  @spec zeny_cost_reduction(PlayerState.t() | PlayerStats.t()) :: non_neg_integer()
  def zeny_cost_reduction(%PlayerState{stats: stats}), do: zeny_cost_reduction(stats)

  def zeny_cost_reduction(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.zeny_cost_reduction(level, ctx)
    end)
  end

  @doc """
  Returns the highest normal-hit item-steal chance contributed by learned passives.
  """
  @spec steal_proc(PlayerState.t() | PlayerStats.t() | term()) :: non_neg_integer()
  def steal_proc(%PlayerState{stats: stats}), do: steal_proc(stats)

  def steal_proc(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      max(acc, Map.get(module.steal_proc(level, ctx), :chance_permille, 0))
    end)
  end

  # Non-player casters (mobs, test fakes) never contribute a Snatcher proc.
  def steal_proc(_), do: 0

  @doc """
  Returns the highest NPC shop buy discount percentage from learned passives.
  """
  @spec shop_discount_pct(PlayerState.t() | PlayerStats.t() | term()) :: non_neg_integer()
  def shop_discount_pct(%PlayerState{stats: stats}), do: shop_discount_pct(stats)

  def shop_discount_pct(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, discount ->
      max(discount, module.shop_discount_pct(level, ctx))
    end)
  end

  def shop_discount_pct(_), do: 0

  @doc """
  Returns the highest hidden movement speed rate from learned passives.
  """
  @spec hidden_move_speed(PlayerState.t() | PlayerStats.t() | term()) :: non_neg_integer()
  def hidden_move_speed(%PlayerState{stats: stats}), do: hidden_move_speed(stats)

  def hidden_move_speed(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, rate ->
      max(rate, module.hidden_move_speed(level, ctx))
    end)
  end

  def hidden_move_speed(_), do: 0

  @doc """
  Folds the on-normal-attack procs of every learned passive into one map.

  Keeps the proc with the highest `:multi_hit` (carrying its own `:chance` and
  `:hit_bonus` metadata along with it), since only one multi-hit source exists
  at first job. Returns `%{}` when nothing procs.
  """
  @spec attack_procs(PlayerState.t() | PlayerStats.t()) :: %{
          optional(:multi_hit) => pos_integer(),
          optional(:chance) => 1..100,
          optional(:hit_bonus) => non_neg_integer()
        }
  def attack_procs(%PlayerState{stats: stats}), do: attack_procs(stats)

  def attack_procs(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(%{}, fn {module, level}, acc ->
      merge_attack_proc(acc, module.attack_proc(level, ctx))
    end)
  end

  @doc """
  Merges the regen contributions of every learned passive.

  Numeric keys are summed; `allow_while_moving` is OR-ed. Always returns all
  three keys.
  """
  @spec regen(PlayerState.t() | PlayerStats.t()) :: regen()
  def regen(%PlayerState{stats: stats}), do: regen(stats)

  def regen(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(%{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: false}, fn {module,
                                                                                           level},
                                                                                          acc ->
      contribution = module.regen_contribution(level, ctx)

      %{
        skill_hp_regen: acc.skill_hp_regen + Map.get(contribution, :skill_hp_regen, 0),
        skill_sp_regen: acc.skill_sp_regen + Map.get(contribution, :skill_sp_regen, 0),
        allow_while_moving:
          acc.allow_while_moving or Map.get(contribution, :allow_while_moving, false)
      }
    end)
  end

  @doc """
  Merges the sitting-only regeneration contributions of learned passives.
  """
  @spec sitting_regen(PlayerState.t() | PlayerStats.t()) :: sitting_regen()
  def sitting_regen(%PlayerState{stats: stats}), do: sitting_regen(stats)

  def sitting_regen(%PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.reduce(%{sitting_hp_regen: 0, sitting_sp_regen: 0}, fn {module, level}, acc ->
      contribution = module.regen_contribution(level, ctx)

      %{
        sitting_hp_regen: acc.sitting_hp_regen + Map.get(contribution, :sitting_hp_regen, 0),
        sitting_sp_regen: acc.sitting_sp_regen + Map.get(contribution, :sitting_sp_regen, 0)
      }
    end)
  end

  @doc """
  Collects the non-`:none` riders contributed by learned passives for the given
  target skill and level.
  """
  @spec rider_for(atom(), pos_integer(), PlayerState.t() | PlayerStats.t()) :: [rider()]
  def rider_for(target_skill, target_skill_level, %PlayerState{stats: stats}) do
    rider_for(target_skill, target_skill_level, stats)
  end

  def rider_for(target_skill, target_skill_level, %PlayerStats{} = stats) do
    ctx = build_ctx(stats)

    stats
    |> learned_passives()
    |> Enum.flat_map(fn {module, level} ->
      case module.skill_rider(target_skill, target_skill_level, level, ctx) do
        :none -> []
        rider -> [rider]
      end
    end)
  end

  @spec merge_attack_proc(map(), map()) :: map()
  defp merge_attack_proc(acc, proc) do
    if Map.get(proc, :multi_hit, 0) > Map.get(acc, :multi_hit, 0), do: proc, else: acc
  end

  @spec learned_passives(PlayerStats.t()) :: [{module(), pos_integer()}]
  defp learned_passives(%PlayerStats{} = stats) do
    stats.progression.learned_skills
    |> Enum.flat_map(fn {skill_id, level} ->
      with {:ok, definition} <- Catalog.by_id(skill_id),
           {:ok, module} <- Catalog.passive_module_for(definition.name) do
        [{module, level}]
      else
        _ -> []
      end
    end)
  end

  @spec build_ctx(PlayerStats.t()) :: Passive.ctx()
  defp build_ctx(%PlayerStats{} = stats) do
    %{
      weapon_type:
        if(stats.equipment, do: PlayerStats.weapon_type(stats.equipment), else: :bare_hands),
      base_level: stats.progression.base_level,
      job_level: stats.progression.job_level,
      max_hp: derived_stat(stats.derived_stats, :max_hp),
      max_sp: derived_stat(stats.derived_stats, :max_sp),
      vit: stats.base_stats.vit,
      int: stats.base_stats.int,
      riding: stats.riding,
      learned_skills: stats.progression.learned_skills,
      statuses_active?: Map.get(stats.modifiers, :statuses_active?, false)
    }
  end

  # `dex_bonus`/`hit_bonus`/`range_bonus` are aggregated before derived stats
  # are computed (so DEX feeds them), so `derived_stats` may still be nil here.
  @spec derived_stat(map() | nil, atom()) :: non_neg_integer()
  defp derived_stat(nil, _key), do: 0
  defp derived_stat(derived, key), do: Map.get(derived, key, 0)
end

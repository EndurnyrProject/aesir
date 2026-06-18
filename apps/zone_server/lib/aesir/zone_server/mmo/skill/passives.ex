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
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @typedoc "Aggregated regen contribution from all learned passives."
  @type regen :: %{
          skill_hp_regen: integer(),
          skill_sp_regen: integer(),
          allow_while_moving: boolean()
        }

  @typedoc "A skill rider produced by a passive."
  @type rider :: {:apply_status, atom(), keyword()}

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
      weapon_type: WeaponTypes.get_weapon_atom(stats.equipment.weapon),
      base_level: stats.progression.base_level,
      job_level: stats.progression.job_level,
      max_hp: stats.derived_stats.max_hp,
      max_sp: stats.derived_stats.max_sp,
      vit: stats.base_stats.vit,
      int: stats.base_stats.int
    }
  end
end

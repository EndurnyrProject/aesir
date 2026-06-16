defmodule Aesir.ZoneServer.Mmo.Skill.Passives do
  @moduledoc """
  Aggregation surface for passive skills.

  Walks a player's learned skills, keeps only the ones whose definition is a
  `:passive` and resolves to a registered passive module, builds the shared
  `Passive.ctx`, and folds each effect channel (ATK, regen, skill riders).

  Consumers (the stat pipeline, the natural-heal tick, SmBash) call this module
  instead of iterating `learned_skills` directly.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Mmo.Skill.Passives.Registry
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "Aggregated regen contribution from all learned passives."
  @type regen :: %{
          hp_regen: integer(),
          sp_regen: integer(),
          allow_while_moving: boolean()
        }

  @typedoc "A skill rider produced by a passive."
  @type rider :: {:apply_status, atom(), keyword()}

  @doc """
  Sums the ATK bonus contributed by every learned passive for the player.
  """
  @spec atk_bonus(PlayerState.t()) :: integer()
  def atk_bonus(%PlayerState{} = player) do
    ctx = build_ctx(player)

    player
    |> learned_passives()
    |> Enum.reduce(0, fn {module, level}, acc ->
      acc + module.atk_bonus(level, ctx)
    end)
  end

  @doc """
  Merges the regen contributions of every learned passive.

  Numeric keys are summed; `allow_while_moving` is OR-ed. Always returns all
  three keys.
  """
  @spec regen(PlayerState.t()) :: regen()
  def regen(%PlayerState{} = player) do
    ctx = build_ctx(player)

    player
    |> learned_passives()
    |> Enum.reduce(%{hp_regen: 0, sp_regen: 0, allow_while_moving: false}, fn {module, level},
                                                                              acc ->
      contribution = module.regen_contribution(level, ctx)

      %{
        hp_regen: acc.hp_regen + Map.get(contribution, :hp_regen, 0),
        sp_regen: acc.sp_regen + Map.get(contribution, :sp_regen, 0),
        allow_while_moving:
          acc.allow_while_moving or Map.get(contribution, :allow_while_moving, false)
      }
    end)
  end

  @doc """
  Collects the non-`:none` riders contributed by learned passives for the given
  target skill and level.
  """
  @spec rider_for(atom(), pos_integer(), PlayerState.t()) :: [rider()]
  def rider_for(target_skill, target_skill_level, %PlayerState{} = player) do
    ctx = build_ctx(player)

    player
    |> learned_passives()
    |> Enum.flat_map(fn {module, level} ->
      case module.skill_rider(target_skill, target_skill_level, level, ctx) do
        :none -> []
        rider -> [rider]
      end
    end)
  end

  @spec learned_passives(PlayerState.t()) :: [{module(), pos_integer()}]
  defp learned_passives(%PlayerState{stats: stats}) do
    stats.progression.learned_skills
    |> Enum.flat_map(fn {skill_id, level} ->
      with {:ok, definition} <- Catalog.by_id(skill_id),
           :passive <- definition.target_type,
           {:ok, module} <- Registry.module_for(definition.name) do
        [{module, level}]
      else
        _ -> []
      end
    end)
  end

  @spec build_ctx(PlayerState.t()) :: Passive.ctx()
  defp build_ctx(%PlayerState{stats: stats}) do
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

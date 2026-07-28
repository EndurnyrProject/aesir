defmodule Aesir.ZoneServer.Mmo.Skill.Cost do
  @moduledoc """
  Resolves, validates, and applies the owner-local resources for one skill cast.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  defstruct hp: 0, sp_requirement: nil, sp: 0, spheres: 0

  @type t() :: %__MODULE__{
          hp: non_neg_integer(),
          sp_requirement: non_neg_integer() | nil,
          sp: non_neg_integer(),
          spheres: non_neg_integer()
        }

  defmodule Commitment do
    @moduledoc false

    @enforce_keys [:hp, :sp, :spheres, :write_spheres?]
    defstruct [:hp, :sp, :spheres, :write_spheres?]

    @type t() :: %__MODULE__{
            hp: non_neg_integer(),
            sp: non_neg_integer(),
            spheres: SpiritSpheres.t(),
            write_spheres?: boolean()
          }
  end

  @type resource_error ::
          :insufficient_hp | :insufficient_sp | :insufficient_spirit_spheres | :invalid_cost

  @spec from_definition(map(), Definition.t(), pos_integer(), keyword()) :: t()
  def from_definition(game_state, definition, level, opts \\ []) do
    sp =
      Keyword.get(
        opts,
        :sp,
        level_cost(definition.sp_cost, level, game_state.stats.current_state.sp)
      )

    %__MODULE__{
      hp: level_cost(definition.hp_cost, level, 0) + hp_rate_cost(game_state, definition, level),
      sp_requirement: sp,
      sp: sp,
      spheres: level_cost(definition.sphere_cost, level, available_spheres(game_state))
    }
  end

  @doc "Resolves ordinary SP modifiers from the definition's raw base cost."
  @spec resolve_sp(map(), Definition.t(), pos_integer()) :: non_neg_integer()
  def resolve_sp(game_state, definition, level),
    do: resolve_sp(game_state, definition, level, nil)

  @doc "Resolves ordinary SP modifiers from an optional replacement raw base cost."
  @spec resolve_sp(map(), Definition.t(), pos_integer(), non_neg_integer() | nil) ::
          non_neg_integer()
  def resolve_sp(game_state, definition, level, nil) do
    case Enum.at(definition.sp_cost, level - 1, 0) do
      :all -> game_state.stats.current_state.sp
      base -> reduce_sp(game_state, definition.id, base)
    end
  end

  def resolve_sp(game_state, definition, _level, raw_base),
    do: reduce_sp(game_state, definition.id, raw_base)

  @spec validate_resolved(term()) :: {:ok, t()} | {:error, :invalid_cost}
  def validate_resolved(%__MODULE__{sp_requirement: nil, sp: sp} = cost)
      when is_integer(sp) and sp >= 0,
      do: validate_resolved(%{cost | sp_requirement: sp})

  def validate_resolved(
        %__MODULE__{hp: hp, sp_requirement: requirement, sp: sp, spheres: spheres} = cost
      )
      when is_integer(hp) and hp >= 0 and is_integer(requirement) and requirement >= 0 and
             is_integer(sp) and sp >= 0 and is_integer(spheres) and spheres >= 0,
      do: {:ok, cost}

  def validate_resolved(_cost), do: {:error, :invalid_cost}

  @spec validate(map(), t()) :: :ok | {:error, resource_error()}
  def validate(game_state, %__MODULE__{} = cost) do
    with {:ok, cost} <- validate_resolved(cost) do
      validate_resources(game_state, cost)
    end
  end

  defp validate_resources(game_state, cost) do
    current = game_state.stats.current_state

    cond do
      cost.hp > 0 and Map.get(current, :hp, 0) <= cost.hp ->
        {:error, :insufficient_hp}

      Map.get(current, :sp, 0) < max(cost.sp_requirement, cost.sp) ->
        {:error, :insufficient_sp}

      available_spheres(game_state) < cost.spheres ->
        {:error, :insufficient_spirit_spheres}

      true ->
        :ok
    end
  end

  @spec prepare(map(), t()) :: {:ok, Commitment.t()} | {:error, resource_error()}
  def prepare(game_state, cost) do
    with {:ok, cost} <- validate_resolved(cost),
         :ok <- validate(game_state, cost),
         {:ok, spheres} <- consume_spheres(spheres(game_state), cost.spheres) do
      {:ok,
       %Commitment{
         hp: cost.hp,
         sp: cost.sp,
         spheres: spheres,
         write_spheres?: cost.spheres > 0
       }}
    end
  end

  @spec apply_commitment(map(), Commitment.t()) :: map()
  def apply_commitment(game_state, %Commitment{} = commitment) do
    current_state =
      game_state.stats.current_state
      |> deduct(:hp, commitment.hp)
      |> deduct(:sp, commitment.sp)

    stats = %{game_state.stats | current_state: current_state}
    game_state = %{game_state | stats: stats}

    if commitment.write_spheres? do
      Map.put(game_state, :spirit_spheres, commitment.spheres)
    else
      game_state
    end
  end

  defp reduce_sp(game_state, skill_id, base) do
    rate =
      merged_modifier(game_state.character_id, :sp_cost_rate) +
        equipment_modifier(game_state, :sp_cost_rate) +
        equipment_modifier(game_state, {:skill_use_sp_rate, skill_id})

    reduced = div(base * max(0, 100 + rate), 100)
    max(0, reduced - equipment_modifier(game_state, {:skill_use_sp, skill_id}))
  end

  defp merged_modifier(character_id, key) do
    :player
    |> ModifierCalculator.get_all_modifiers(character_id)
    |> Map.get(key, 0)
  end

  defp equipment_modifier(game_state, key) do
    case Map.get(game_state, :stats) do
      nil ->
        0

      stats ->
        stats
        |> Map.get(:modifiers, %{})
        |> Map.get(:equipment, %{})
        |> Map.get(key, 0)
    end
  end

  defp hp_rate_cost(game_state, definition, level) do
    case Enum.at(definition.hp_cost_rate, level - 1, 0) do
      0 -> 0
      rate -> div(game_state.stats.derived_stats.max_hp * rate, 100)
    end
  end

  defp level_cost(costs, level, all) do
    case Enum.at(costs, level - 1, 0) do
      :all -> all
      cost -> cost
    end
  end

  defp available_spheres(game_state) do
    game_state
    |> spheres()
    |> SpiritSpheres.count()
  end

  defp spheres(game_state), do: Map.get(game_state, :spirit_spheres, SpiritSpheres.new())

  defp consume_spheres(spheres, 0), do: {:ok, spheres}

  defp consume_spheres(spheres, count) do
    case SpiritSpheres.consume(spheres, count) do
      {:ok, updated, _entries} -> {:ok, updated}
      {:error, :insufficient} -> {:error, :insufficient_spirit_spheres}
    end
  end

  defp deduct(current, _resource, 0), do: current
  defp deduct(current, resource, cost), do: Map.update!(current, resource, &(&1 - cost))
end

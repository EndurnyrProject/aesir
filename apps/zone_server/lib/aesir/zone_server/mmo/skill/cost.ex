defmodule Aesir.ZoneServer.Mmo.Skill.Cost do
  @moduledoc """
  Resolves, validates, and applies the owner-local resources for one skill cast.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  typedstruct do
    field :hp, non_neg_integer(), default: 0
    field :sp, non_neg_integer(), default: 0
    field :spheres, non_neg_integer(), default: 0
  end

  defmodule Commitment do
    @moduledoc false

    use TypedStruct

    typedstruct do
      field :hp, non_neg_integer(), enforce: true
      field :sp, non_neg_integer(), enforce: true
      field :spheres, SpiritSpheres.t(), enforce: true
      field :write_spheres?, boolean(), enforce: true
    end
  end

  @type resource_error ::
          :insufficient_hp | :insufficient_sp | :insufficient_spirit_spheres | :invalid_cost

  @spec from_definition(map(), Definition.t(), pos_integer(), keyword()) :: t()
  def from_definition(game_state, definition, level, opts \\ []) do
    %__MODULE__{
      hp: level_cost(definition.hp_cost, level, 0) + hp_rate_cost(game_state, definition, level),
      sp:
        Keyword.get(
          opts,
          :sp,
          level_cost(definition.sp_cost, level, game_state.stats.current_state.sp)
        ),
      spheres: level_cost(definition.sphere_cost, level, available_spheres(game_state))
    }
  end

  @spec validate_resolved(term()) :: {:ok, t()} | {:error, :invalid_cost}
  def validate_resolved(%__MODULE__{hp: hp, sp: sp, spheres: spheres} = cost)
      when is_integer(hp) and hp >= 0 and is_integer(sp) and sp >= 0 and is_integer(spheres) and
             spheres >= 0,
      do: {:ok, cost}

  def validate_resolved(_cost), do: {:error, :invalid_cost}

  @spec validate(map(), t()) :: :ok | {:error, resource_error()}
  def validate(game_state, %__MODULE__{} = cost) do
    current = game_state.stats.current_state

    cond do
      cost.hp > 0 and Map.get(current, :hp, 0) <= cost.hp ->
        {:error, :insufficient_hp}

      Map.get(current, :sp, 0) < cost.sp ->
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

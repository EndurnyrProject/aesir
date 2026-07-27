defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Cell do
  @moduledoc "A stable, independently addressable skill-unit map cell."

  import Bitwise

  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget

  @targetable 1
  @blocks_movement 2
  @blocks_projectiles 4
  @consumable_water 8
  @visible 16
  @known_flags @targetable ||| @blocks_movement ||| @blocks_projectiles ||| @consumable_water |||
                 @visible
  @uint32_max 0xFFFF_FFFF
  @uint64_max 0xFFFF_FFFF_FFFF_FFFF

  @enforce_keys [:cell_id, :group_id]
  defstruct cell_id: nil,
            group_id: nil,
            map_name: nil,
            x: nil,
            y: nil,
            hp: 0,
            max_hp: 0,
            flags: 0,
            state: %{}

  @type t() :: %__MODULE__{
          cell_id: non_neg_integer(),
          group_id: non_neg_integer(),
          map_name: String.t() | nil,
          x: integer() | nil,
          y: integer() | nil,
          hp: non_neg_integer(),
          max_hp: non_neg_integer(),
          flags: non_neg_integer(),
          state: map()
        }

  @doc "Builds a cell after validating its flags and optional HP state."
  @spec new(map()) :: {:ok, t()} | {:error, :invalid_cell | :invalid_flags | :invalid_hp}
  def new(attrs) do
    cell = struct(__MODULE__, normalize_flags(attrs))

    with :ok <- validate_identity(cell),
         :ok <- validate_flags(cell),
         :ok <- validate_state(cell),
         :ok <- validate_hp(cell) do
      {:ok, cell}
    end
  end

  @doc "Returns whether the cell has `flag`."
  @spec flag?(t(), atom()) :: boolean()
  def flag?(%__MODULE__{flags: flags}, flag) do
    case flag_value(flag) do
      nil -> false
      value -> (flags &&& value) != 0
    end
  end

  @spec targetable() :: pos_integer()
  def targetable, do: @targetable
  @spec blocks_movement() :: pos_integer()
  def blocks_movement, do: @blocks_movement
  @spec blocks_projectiles() :: pos_integer()
  def blocks_projectiles, do: @blocks_projectiles
  @spec consumable_water() :: pos_integer()
  def consumable_water, do: @consumable_water
  @spec visible() :: pos_integer()
  def visible, do: @visible

  @doc false
  @spec to_combatant(t()) :: map()
  def to_combatant(%__MODULE__{} = cell), do: CombatTarget.to_combatant(cell)

  @doc """
  Ground cells are never living participants nor corpse targets; they only
  satisfy the `Unit.living?/1`/`Unit.corpse?/1` dispatch contract so generic
  code that meets a cell snapshot fails closed instead of raising.
  """
  @spec living?(t()) :: false
  def living?(%__MODULE__{}), do: false

  @spec corpse?(t()) :: false
  def corpse?(%__MODULE__{}), do: false

  defp normalize_flags(%{flags: flags} = attrs) when is_list(flags) do
    Map.put(
      attrs,
      :flags,
      Enum.reduce_while(flags, 0, fn flag, value ->
        case flag_value(flag) do
          nil -> {:halt, :invalid}
          bit -> {:cont, value ||| bit}
        end
      end)
    )
  end

  defp normalize_flags(attrs), do: attrs
  defp flag_value(:targetable), do: @targetable
  defp flag_value(:blocks_movement), do: @blocks_movement
  defp flag_value(:blocks_projectiles), do: @blocks_projectiles
  defp flag_value(:consumable_water), do: @consumable_water
  defp flag_value(:visible), do: @visible
  defp flag_value(_), do: nil

  defp valid_identity?(%__MODULE__{} = cell) do
    cell.cell_id in 1..@uint32_max and is_integer(cell.group_id) and
      cell.group_id in 1..@uint64_max and is_binary(cell.map_name) and
      byte_size(cell.map_name) > 0 and is_integer(cell.x) and cell.x >= 0 and is_integer(cell.y) and
      cell.y >= 0
  end

  defp valid_hp?(%__MODULE__{hp: hp, max_hp: max_hp}) do
    is_integer(hp) and hp >= 0 and is_integer(max_hp) and max_hp >= 0
  end

  defp validate_identity(cell),
    do: if(valid_identity?(cell), do: :ok, else: {:error, :invalid_cell})

  defp validate_flags(%__MODULE__{flags: flags}) when is_integer(flags) do
    if (flags &&& bnot(@known_flags)) == 0, do: :ok, else: {:error, :invalid_flags}
  end

  defp validate_flags(_cell), do: {:error, :invalid_flags}
  defp validate_state(%__MODULE__{state: state}) when is_map(state), do: :ok
  defp validate_state(_cell), do: {:error, :invalid_cell}

  defp validate_hp(cell) do
    if valid_hp?(cell) and
         ((cell.max_hp > 0 and cell.hp <= cell.max_hp) or (cell.max_hp == 0 and cell.hp == 0)) do
      :ok
    else
      {:error, :invalid_hp}
    end
  end
end

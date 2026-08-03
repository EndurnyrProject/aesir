defmodule Aesir.ZoneServer.Unit.Ref do
  @moduledoc """
  Validated typed identity for a unit in the world.
  """

  alias Aesir.ZoneServer.Unit

  @unit_types [:player, :mob, :npc, :pet, :homunculus, :mercenary, :skill_unit]

  @typedoc "A unit type paired with a positive world identifier."
  @type t() :: {Unit.unit_type(), pos_integer()}

  @doc "Builds a validated typed unit reference."
  @spec new(atom(), integer()) :: {:ok, t()} | {:error, :invalid_unit_type | :invalid_unit_id}
  def new(unit_type, unit_id)
      when unit_type in @unit_types and is_integer(unit_id) and unit_id > 0,
      do: {:ok, {unit_type, unit_id}}

  def new(unit_type, _unit_id) when unit_type not in @unit_types, do: {:error, :invalid_unit_type}
  def new(_unit_type, _unit_id), do: {:error, :invalid_unit_id}

  @doc "Builds a validated typed unit reference or raises."
  @spec new!(atom(), integer()) :: t()
  def new!(unit_type, unit_id) do
    case new(unit_type, unit_id) do
      {:ok, ref} -> ref
      {:error, reason} -> raise ArgumentError, "invalid unit reference: #{reason}"
    end
  end

  @doc "Returns whether a term is a validated typed unit reference."
  @spec valid?(term()) :: boolean()
  def valid?({unit_type, unit_id}), do: match?({:ok, _ref}, new(unit_type, unit_id))
  def valid?(_ref), do: false

  @doc "Returns whether two valid typed unit references identify the same unit."
  @spec equal?(term(), term()) :: boolean()
  def equal?(left, right), do: valid?(left) and valid?(right) and left == right
end

defmodule Aesir.ZoneServer.Mmo.Homunculus.ExpTable do
  @moduledoc """
  Runtime Homunculus experience requirements for the active game mode.

  Renewal contains levels 1 through 99; pre-renewal contains levels 1 through
  98. Runtime staging validates against `Source.mode/0`.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalogs

  @doc "Returns the complete level-to-next-level EXP table."
  @spec all() :: %{pos_integer() => pos_integer()}
  def all, do: table()

  @doc "Returns the EXP required to advance from a level."
  @spec exp_for(pos_integer()) :: {:ok, pos_integer()} | :error
  def exp_for(level), do: Map.fetch(table(), level)

  @doc "Reloads and validates all Homunculus runtime catalogs."
  @spec reload() :: :ok
  def reload, do: Catalogs.reload()

  @doc false
  @spec stage() :: map()
  def stage do
    "homunculus/exp.yml"
    |> Source.sources()
    |> Enum.flat_map(&YamlElixir.read_from_file!/1)
    |> DataLoader.merge_by_key(& &1["level"])
    |> stage_rows(Source.mode())
  end

  @doc false
  @spec stage(Path.t()) :: map()
  def stage(path), do: path |> YamlElixir.read_from_file!() |> stage_rows(Source.mode())

  @doc "Validates a decoded EXP corpus for a mode, raising on gaps or malformed values."
  @spec validate!([map()]) :: :ok
  @spec validate!([map()], Aesir.Commons.GameMode.t()) :: :ok
  def validate!(rows, mode \\ Source.mode())

  def validate!(rows, mode) when is_list(rows) and mode in [:renewal, :pre_renewal] do
    max_level = max_level(mode)
    levels = Enum.map(rows, & &1["level"])

    unless levels == Enum.to_list(1..max_level),
      do: raise(ArgumentError, "expected ordered Homunculus EXP levels 1..#{max_level}")

    unless Enum.all?(rows, &(is_integer(&1["exp"]) and &1["exp"] > 0)),
      do: raise(ArgumentError, "Homunculus EXP values must be positive integers")

    :ok
  end

  def validate!(_rows, mode) when mode in [:renewal, :pre_renewal],
    do: raise(ArgumentError, "Homunculus EXP data must be a list")

  def validate!(_rows, mode), do: raise(ArgumentError, "invalid game mode: #{inspect(mode)}")

  defp table, do: Catalogs.state(:exp_table)

  defp stage_rows(rows, mode) do
    validate!(rows, mode)
    Map.new(rows, &{&1["level"], &1["exp"]})
  end

  defp max_level(:renewal), do: 99
  defp max_level(:pre_renewal), do: 98
end

defmodule Aesir.ZoneServer.Mmo.Homunculus.ExpTable do
  @moduledoc """
  Runtime Homunculus experience requirements for levels 1 through 99.
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
    |> stage_rows()
  end

  @doc false
  @spec stage(Path.t()) :: map()
  def stage(path), do: path |> YamlElixir.read_from_file!() |> stage_rows()

  @doc "Validates a decoded EXP corpus, raising on gaps or malformed values."
  @spec validate!([map()]) :: :ok
  def validate!(rows) when is_list(rows) do
    levels = Enum.map(rows, & &1["level"])

    unless levels == Enum.to_list(1..99),
      do: raise(ArgumentError, "expected ordered Homunculus EXP levels 1..99")

    unless Enum.all?(rows, &(is_integer(&1["exp"]) and &1["exp"] > 0)),
      do: raise(ArgumentError, "Homunculus EXP values must be positive integers")

    :ok
  end

  def validate!(_rows), do: raise(ArgumentError, "Homunculus EXP data must be a list")

  defp table, do: Catalogs.state(:exp_table)

  defp stage_rows(rows) do
    validate!(rows)
    Map.new(rows, &{&1["level"], &1["exp"]})
  end
end

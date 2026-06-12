defmodule Aesir.ZoneServer.Mmo.DefinitionValidation do
  @moduledoc """
  Shared compile-time validation for declarative definition macros.

  Definition macros (status effects, mobs, spawns) validate their `use`
  options against a Peri schema at compile time. This module centralizes the
  unknown-key check, the Peri validation call, defaults merging, and error
  formatting so every definition kind fails the same way: an `ArgumentError`
  raised at compile time naming the offending module and fields.
  """

  @doc """
  Validates `options` against `schema` and merges the result over `defaults`.

  Raises `ArgumentError` when `options` contains unknown keys or values that
  fail schema validation, naming the offending module and fields.
  """
  @spec validate!(map(), keyword() | map(), module(), map()) :: map()
  def validate!(schema, options, module, defaults \\ %{}) do
    data = Map.new(options)

    check_unknown_keys!(schema, data, module)

    case Peri.validate(schema, data) do
      {:ok, validated} ->
        Map.merge(defaults, validated)

      {:error, errors} ->
        raise ArgumentError,
              "invalid definition metadata in #{inspect(module)}: #{format_errors(errors)}"
    end
  end

  @doc """
  Raises `ArgumentError` when `data` contains keys not present in `schema`.
  """
  @spec check_unknown_keys!(map(), map(), module()) :: :ok
  def check_unknown_keys!(schema, data, module) do
    unknown = Map.keys(data) -- Map.keys(schema)

    if unknown != [] do
      raise ArgumentError,
            "unknown definition metadata keys in #{inspect(module)}: #{inspect(unknown)}"
    end

    :ok
  end

  defp format_errors(errors) when is_list(errors) do
    Enum.map_join(errors, "; ", &format_error/1)
  end

  defp format_errors(error), do: format_error(error)

  defp format_error(%Peri.Error{path: path, message: message, errors: nested})
       when is_list(nested) do
    prefix = if path in [nil, []], do: "", else: "#{Enum.join(path, ".")}: "
    nested_msg = format_errors(nested)

    case message do
      nil -> "#{prefix}#{nested_msg}"
      _ -> "#{prefix}#{message} (#{nested_msg})"
    end
  end

  defp format_error(%Peri.Error{path: path, message: message}) do
    prefix = if path in [nil, []], do: "", else: "#{Enum.join(path, ".")}: "
    "#{prefix}#{message}"
  end

  defp format_error({field, message}), do: "#{field}: #{message}"
  defp format_error(other), do: inspect(other)
end

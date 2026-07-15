defmodule Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport do
  @moduledoc """
  Tracks statuses granted by individual ground-field groups.

  A support row is owned by exactly one field group. Releasing a row therefore
  cannot remove another field's contribution; the effective status is rebuilt
  from the remaining rows after every change.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @type unit :: {atom(), integer()}
  @type params :: keyword() | map()
  @type aggregator :: ([params()] -> params())

  @doc "Adds or replaces one source contribution and applies its effective status."
  @spec acquire(atom(), integer(), atom(), integer(), params(), keyword()) ::
          :ok | {:error, atom()}
  def acquire(unit_type, unit_id, status_type, source_group_id, params, opts \\ []) do
    key = {unit_type, unit_id, status_type, source_group_id}
    aggregate = Keyword.get(opts, :aggregate)

    case :ets.lookup(table_for(:field_supports), key) do
      [{^key, %{params: ^params, aggregate: ^aggregate}}] ->
        if field_owned?(unit_type, unit_id, status_type) do
          :ok
        else
          reconcile(unit_type, unit_id, status_type, opts)
        end

      _ ->
        :ets.insert(table_for(:field_supports), {key, %{params: params, aggregate: aggregate}})
        reconcile(unit_type, unit_id, status_type, opts)
    end
  end

  @doc "Releases one source contribution and recalculates the effective status."
  @spec release(atom(), integer(), atom(), integer(), keyword()) :: :ok | {:error, atom()}
  def release(unit_type, unit_id, status_type, source_group_id, opts \\ []) do
    :ets.delete(table_for(:field_supports), {unit_type, unit_id, status_type, source_group_id})
    reconcile(unit_type, unit_id, status_type, opts)
  end

  @doc "Releases all contributions owned by a field group."
  @spec release_group(integer(), keyword()) :: :ok
  def release_group(source_group_id, opts \\ []) do
    rows =
      :ets.match_object(table_for(:field_supports), {{:_, :_, :_, source_group_id}, :_})

    Enum.each(rows, fn {{unit_type, unit_id, status_type, ^source_group_id}, _row} ->
      :ets.delete(table_for(:field_supports), {unit_type, unit_id, status_type, source_group_id})
    end)

    rows
    |> Enum.map(fn {{unit_type, unit_id, status_type, _}, _} ->
      {unit_type, unit_id, status_type}
    end)
    |> Enum.uniq()
    |> Enum.each(&reconcile(elem(&1, 0), elem(&1, 1), elem(&1, 2), opts))

    :ok
  end

  @doc "Reconciles the status from all currently stored source contributions."
  @spec reconcile(atom(), integer(), atom(), keyword()) :: :ok | {:error, atom()}
  def reconcile(unit_type, unit_id, status_type, opts \\ []) do
    stored_rows = stored_rows(unit_type, unit_id, status_type)
    rows = Enum.map(stored_rows, & &1.params)

    case rows do
      [] ->
        if field_owned?(unit_type, unit_id, status_type) do
          Interpreter.remove_status(unit_type, unit_id, status_type)
        else
          :ok
        end

      _ ->
        params = effective_params(rows, opts, Enum.map(stored_rows, & &1.aggregate))
        materialize(unit_type, unit_id, status_type, params)
    end
  end

  @doc "Returns source rows for a unit/status pair."
  @spec sources(atom(), integer(), atom()) :: [params()]
  def sources(unit_type, unit_id, status_type) do
    :ets.match_object(table_for(:field_supports), {{unit_type, unit_id, status_type, :_}, :_})
    |> Enum.map(fn {_key, %{params: params}} -> params end)
  end

  @doc "Returns all support keys owned by a field group."
  @spec sources_for_group(integer()) :: [{atom(), integer(), atom(), params()}]
  def sources_for_group(source_group_id) do
    :ets.match_object(table_for(:field_supports), {{:_, :_, :_, source_group_id}, :_})
    |> Enum.map(fn {{unit_type, unit_id, status_type, ^source_group_id}, %{params: params}} ->
      {unit_type, unit_id, status_type, params}
    end)
  end

  @doc "Returns all support keys owned for a unit."
  @spec sources_for_unit(atom(), integer()) :: [{atom(), integer(), atom(), integer(), params()}]
  def sources_for_unit(unit_type, unit_id) do
    :ets.match_object(table_for(:field_supports), {{unit_type, unit_id, :_, :_}, :_})
    |> Enum.map(fn {{^unit_type, ^unit_id, status_type, source_group_id}, %{params: params}} ->
      {unit_type, unit_id, status_type, source_group_id, params}
    end)
  end

  @doc "Returns whether at least one source supports the status."
  @spec supported?(atom(), integer(), atom()) :: boolean()
  def supported?(unit_type, unit_id, status_type) do
    :ets.match_object(table_for(:field_supports), {{unit_type, unit_id, status_type, :_}, :_}) !=
      []
  end

  @doc "Returns whether the materialized status is owned by this registry."
  @spec field_owned?(atom(), integer(), atom()) :: boolean()
  def field_owned?(unit_type, unit_id, status_type) do
    case StatusStorage.get_status(unit_type, unit_id, status_type) do
      %{state: %{field_support: true}} -> true
      _ -> false
    end
  end

  defp effective_params(rows, opts, stored_aggregates) do
    aggregate =
      Keyword.get(opts, :aggregate) || Enum.find(stored_aggregates, &is_function(&1, 1)) ||
        aggregate_from_rows(rows)

    if is_function(aggregate, 1) do
      aggregate.(rows)
    else
      Enum.max_by(rows, &strength/1)
    end
  end

  defp stored_rows(unit_type, unit_id, status_type) do
    :ets.match_object(table_for(:field_supports), {{unit_type, unit_id, status_type, :_}, :_})
    |> Enum.map(fn {_key, row} -> row end)
  end

  defp aggregate_from_rows(rows) do
    rows
    |> Enum.find_value(fn params ->
      case get_param(params, :aggregate) do
        aggregate when is_function(aggregate, 1) -> aggregate
        _ -> nil
      end
    end)
  end

  defp strength(params) do
    {get_param(params, :level, 0), get_param(params, :val1, 0)}
  end

  defp normalize_params(params) when is_list(params), do: params
  defp normalize_params(params) when is_map(params), do: Map.to_list(params)

  defp materialize(unit_type, unit_id, status_type, params) do
    result =
      Interpreter.apply_status(
        unit_type,
        unit_id,
        status_type,
        params |> with_field_marker() |> normalize_params()
      )

    if match?({:error, _}, result) do
      Logger.error(
        "Field support status #{status_type} failed for #{unit_type}:#{unit_id}: #{inspect(result)}"
      )
    end

    result
  end

  defp with_field_marker(params) when is_list(params) do
    Keyword.update(
      params,
      :state,
      %{field_support: true},
      &Map.put(&1 || %{}, :field_support, true)
    )
    |> Keyword.put(:duration, 0)
  end

  defp with_field_marker(params) when is_map(params) do
    params
    |> Map.update(:state, %{field_support: true}, &Map.put(&1 || %{}, :field_support, true))
    |> Map.put(:duration, 0)
  end

  defp get_param(params, key, default \\ nil)

  defp get_param(params, key, default) when is_list(params),
    do: Keyword.get(params, key, default)

  defp get_param(params, key, default) when is_map(params), do: Map.get(params, key, default)
end

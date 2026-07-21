defmodule Aesir.ZoneServer.Unit.Player.SpiritSpheres do
  @moduledoc """
  Ordered, independently expiring spirit spheres owned by one player.
  """

  use TypedStruct

  defmodule Entry do
    @moduledoc false

    use TypedStruct

    typedstruct do
      field :id, pos_integer(), enforce: true
      field :expires_at, integer(), enforce: true
      field :reserved_by, term()
    end
  end

  typedstruct do
    field :entries, [Entry.t()], default: []
    field :next_id, pos_integer(), default: 1
  end

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec entries(t()) :: [Entry.t()]
  def entries(%__MODULE__{entries: entries}), do: entries

  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{entries: entries}), do: length(entries)

  @spec reserved(t(), term()) :: [Entry.t()]
  def reserved(%__MODULE__{entries: entries}, operation_id) do
    Enum.filter(entries, &(&1.reserved_by == operation_id))
  end

  @spec summon(t(), integer(), pos_integer()) :: {t(), Entry.t()} | {:error, :all_reserved}
  def summon(%__MODULE__{} = spheres, expires_at, cap)
      when is_integer(expires_at) and cap > 0 do
    with {:ok, entries} <- make_room(spheres, cap) do
      entry = %Entry{id: spheres.next_id, expires_at: expires_at}
      {%{spheres | entries: entries ++ [entry], next_id: spheres.next_id + 1}, entry}
    end
  end

  defp make_room(%__MODULE__{} = spheres, cap) do
    if count(spheres) < cap do
      {:ok, spheres.entries}
    else
      drop_oldest_unreserved(spheres.entries)
    end
  end

  defp drop_oldest_unreserved(entries) do
    case Enum.find(entries, &is_nil(&1.reserved_by)) do
      nil -> {:error, :all_reserved}
      oldest -> {:ok, Enum.reject(entries, &(&1.id == oldest.id))}
    end
  end

  @spec reserve(t(), term(), pos_integer()) :: {:ok, t(), [Entry.t()]} | {:error, :insufficient}
  def reserve(%__MODULE__{} = spheres, operation_id, count)
      when not is_nil(operation_id) and count > 0 do
    already_reserved = Enum.filter(spheres.entries, &(&1.reserved_by == operation_id))
    needed = count - length(already_reserved)

    with true <- needed >= 0,
         selected <- Enum.take(Enum.filter(spheres.entries, &is_nil(&1.reserved_by)), needed),
         true <- length(selected) == needed do
      {:ok, reserve_entries(spheres, selected, operation_id), already_reserved ++ selected}
    else
      _ -> {:error, :insufficient}
    end
  end

  @spec release(t(), term()) :: {t(), [Entry.t()]}
  def release(%__MODULE__{} = spheres, operation_id) do
    {released, entries} =
      Enum.map_reduce(spheres.entries, [], fn entry, released ->
        if entry.reserved_by == operation_id do
          {%{entry | reserved_by: nil}, [entry | released]}
        else
          {entry, released}
        end
      end)

    {%{spheres | entries: released}, Enum.reverse(entries)}
  end

  @spec release_all(t()) :: {t(), [Entry.t()]}
  def release_all(%__MODULE__{} = spheres) do
    {released, entries} =
      Enum.map_reduce(spheres.entries, [], fn entry, released ->
        if is_nil(entry.reserved_by) do
          {entry, released}
        else
          {%{entry | reserved_by: nil}, [entry | released]}
        end
      end)

    {%{spheres | entries: released}, Enum.reverse(entries)}
  end

  @spec consume(t(), pos_integer()) :: {:ok, t(), [Entry.t()]} | {:error, :insufficient}
  def consume(%__MODULE__{} = spheres, count) when count > 0 do
    selected = select_unreserved(spheres, count)

    if length(selected) == count do
      {:ok, delete_entries(spheres, selected), selected}
    else
      {:error, :insufficient}
    end
  end

  @spec consume_reserved(t(), term(), [pos_integer()]) ::
          {:ok, t(), [Entry.t()]} | {:error, :not_reserved | :reservation_changed}
  def consume_reserved(%__MODULE__{} = spheres, operation_id, expected_entry_ids) do
    selected = reserved(spheres, operation_id)

    case Enum.map(selected, & &1.id) do
      [] -> {:error, :not_reserved}
      ^expected_entry_ids -> {:ok, delete_entries(spheres, selected), selected}
      _changed -> {:error, :reservation_changed}
    end
  end

  @spec transfer_selection(t(), pos_integer()) :: {:ok, [Entry.t()]} | {:error, :insufficient}
  def transfer_selection(%__MODULE__{} = spheres, count) when count > 0 do
    selected = select_unreserved(spheres, count)
    if length(selected) == count, do: {:ok, selected}, else: {:error, :insufficient}
  end

  @spec expire_due(t(), integer()) :: {t(), [Entry.t()]}
  def expire_due(%__MODULE__{} = spheres, now) when is_integer(now) do
    {expired, retained} = Enum.split_with(spheres.entries, &(&1.expires_at <= now))
    {%{spheres | entries: retained}, expired}
  end

  @spec clear(t()) :: {t(), [Entry.t()]}
  def clear(%__MODULE__{} = spheres), do: {%{spheres | entries: []}, spheres.entries}

  @spec next_expiry(t()) :: integer() | nil
  def next_expiry(%__MODULE__{entries: []}), do: nil

  def next_expiry(%__MODULE__{entries: entries}),
    do: entries |> Enum.map(& &1.expires_at) |> Enum.min()

  defp select_unreserved(spheres, count) do
    spheres.entries
    |> Enum.filter(&is_nil(&1.reserved_by))
    |> Enum.take(count)
  end

  defp reserve_entries(spheres, selected, operation_id) do
    selected_ids = MapSet.new(selected, & &1.id)

    entries =
      Enum.map(spheres.entries, fn entry ->
        if MapSet.member?(selected_ids, entry.id),
          do: %{entry | reserved_by: operation_id},
          else: entry
      end)

    %{spheres | entries: entries}
  end

  defp delete_entries(spheres, selected) do
    selected_ids = MapSet.new(selected, & &1.id)
    %{spheres | entries: Enum.reject(spheres.entries, &MapSet.member?(selected_ids, &1.id))}
  end
end

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

  @spec summon(t(), integer(), pos_integer()) :: {t(), Entry.t()}
  def summon(%__MODULE__{} = spheres, expires_at, cap)
      when is_integer(expires_at) and cap > 0 do
    entries = if count(spheres) < cap, do: spheres.entries, else: tl(spheres.entries)
    append(spheres, entries, expires_at)
  end

  @spec add_if_below_cap(t(), integer(), pos_integer()) ::
          {:ok, t(), Entry.t()} | {:error, :full}
  def add_if_below_cap(%__MODULE__{} = spheres, expires_at, cap)
      when is_integer(expires_at) and cap > 0 do
    if count(spheres) < cap do
      {spheres, entry} = append(spheres, spheres.entries, expires_at)
      {:ok, spheres, entry}
    else
      {:error, :full}
    end
  end

  @spec consume(t(), pos_integer()) :: {:ok, t(), [Entry.t()]} | {:error, :insufficient}
  def consume(%__MODULE__{} = spheres, count) when count > 0 do
    {selected, retained} = Enum.split(spheres.entries, count)

    if length(selected) == count do
      {:ok, %{spheres | entries: retained}, selected}
    else
      {:error, :insufficient}
    end
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

  defp append(spheres, entries, expires_at) do
    entry = %Entry{id: spheres.next_id, expires_at: expires_at}
    {%{spheres | entries: entries ++ [entry], next_id: spheres.next_id + 1}, entry}
  end
end

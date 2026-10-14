defmodule Aesir.ZoneServer.Mmo.Skill.Unit.TrapState do
  @moduledoc """
  Typed lifecycle metadata embedded at `Skill.Unit.Group.state.trap`.
  """

  @typedoc """
  A trap lifecycle phase. Only an armed trap acts. `:spent` is a trap that
  went off without effect (an Ankle Snare that failed to catch): inert, but
  it still returns its trap item when its time runs out, as an armed one does.
  """
  @type phase :: :armed | :used | :sprung | :captured | :spent

  @typedoc "The action taken when an armed trap reaches its natural deadline."
  @type natural_expiry :: :drop_item | :become_used

  defstruct phase: :armed,
            reclaim_item_id: nil,
            claymore_spendable?: false,
            natural_expiry: :drop_item,
            return_item_on_expiry?: false

  @type t() :: %__MODULE__{
          phase: phase(),
          reclaim_item_id: pos_integer() | nil,
          claymore_spendable?: boolean(),
          natural_expiry: natural_expiry(),
          return_item_on_expiry?: boolean()
        }

  @fields [
    :phase,
    :reclaim_item_id,
    :claymore_spendable?,
    :natural_expiry,
    :return_item_on_expiry?
  ]

  @doc "Builds validated trap lifecycle metadata."
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, :invalid_trap_state}
  def new(attrs \\ %{}) when is_list(attrs) or is_map(attrs) do
    attrs = Map.new(attrs)

    if Enum.all?(Map.keys(attrs), &(&1 in @fields)) do
      state = struct(__MODULE__, attrs)
      if valid?(state), do: {:ok, state}, else: {:error, :invalid_trap_state}
    else
      {:error, :invalid_trap_state}
    end
  end

  defp valid?(%__MODULE__{} = state) do
    valid_phase?(state.phase) and valid_natural_expiry?(state.natural_expiry) and
      valid_reclaim_item?(state.reclaim_item_id) and valid_flags?(state)
  end

  defp valid_phase?(phase), do: phase in [:armed, :used, :sprung, :captured, :spent]
  defp valid_natural_expiry?(expiry), do: expiry in [:drop_item, :become_used]
  defp valid_reclaim_item?(nil), do: true
  defp valid_reclaim_item?(id), do: is_integer(id) and id > 0

  defp valid_flags?(state),
    do: is_boolean(state.claymore_spendable?) and is_boolean(state.return_item_on_expiry?)
end

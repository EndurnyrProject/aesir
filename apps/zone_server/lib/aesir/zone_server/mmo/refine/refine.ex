defmodule Aesir.ZoneServer.Mmo.Refine.Refine do
  @moduledoc """
  Pure renewal refine outcome engine (rAthena `clif.cpp:22753-22791`).

  `outcome/6` decides success/break/downgrade/fail from an already-resolved
  `RefineDatabase.level_info/3` node, a cost type, a blessing flag, and two
  injected rolls. It performs no RNG and no offset math itself - the caller
  resolves `level_info` at `refine + 1` (see `RefineDatabase`'s moduledoc,
  "Off-by-one") and passes in the rolls, keeping this module fully
  deterministic and side-effect-free.
  """

  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase

  @typedoc "The result of a single refine attempt."
  @type result ::
          {:success, non_neg_integer()}
          | {:break}
          | {:downgrade, non_neg_integer()}
          | {:fail}
          | {:error, :not_refinable}

  @max_refine 20

  @doc """
  Resolves a single refine attempt.

  `refine` is the item's current refine level; `level_info` is the process
  node for the attempt (rates out of `10_000`); `success_roll` and
  `break_roll` are `0..9999`, injected for determinism.
  """
  @spec outcome(
          non_neg_integer(),
          RefineDatabase.level_info() | nil,
          RefineDatabase.cost_type(),
          boolean(),
          0..9999,
          0..9999
        ) :: result()
  def outcome(refine, level_info, cost_type, use_blessing?, success_roll, break_roll)

  def outcome(_refine, nil, _cost_type, _use_blessing?, _success_roll, _break_roll) do
    {:error, :not_refinable}
  end

  def outcome(refine, %{chances: chances}, cost_type, use_blessing?, success_roll, break_roll) do
    case Map.fetch(chances, cost_type) do
      {:ok, chance} -> resolve(refine, chance, use_blessing?, success_roll, break_roll)
      :error -> {:error, :not_refinable}
    end
  end

  @spec resolve(non_neg_integer(), RefineDatabase.chance(), boolean(), 0..9999, 0..9999) ::
          result()
  defp resolve(refine, chance, use_blessing?, success_roll, break_roll) do
    cond do
      success_roll < chance.rate ->
        {:success, min(refine + 1, @max_refine)}

      use_blessing? ->
        {:fail}

      chance.breaking_rate > 0 and break_roll < chance.breaking_rate ->
        {:break}

      chance.downgrade > 0 ->
        {:downgrade, max(0, refine - chance.downgrade)}

      true ->
        {:fail}
    end
  end
end

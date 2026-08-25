defmodule Aesir.ZoneServer.Mmo.Mechanics.Defense.PreRenewal do
  @moduledoc """
  Pre-renewal physical and magic defense mitigation.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.Defense

  alias Aesir.ZoneServer.Mmo.Mechanics.Defense

  @impl true
  @spec apply_def(number(), Defense.physical_context()) :: integer()
  def apply_def(damage, %{
        hard_def: hard_def,
        soft_def: soft_def,
        ignore_soft_def?: ignore_soft_def?
      }) do
    effective_hard_def = min(hard_def, 100)

    # NOTE: Phase 2 must move target-specific player/mob per-hit VIT variance into
    # preprocessing before this leaf.
    effective_soft_def = if ignore_soft_def?, do: 0, else: max(soft_def, 1)

    div(trunc(damage) * (100 - effective_hard_def), 100) - effective_soft_def
  end

  @impl true
  @spec apply_mdef(number(), Defense.magic_context()) :: integer()
  def apply_mdef(damage, %{hard_mdef: hard_mdef, soft_mdef: soft_mdef}) do
    div(trunc(damage) * (100 - hard_mdef), 100) - soft_mdef
  end
end

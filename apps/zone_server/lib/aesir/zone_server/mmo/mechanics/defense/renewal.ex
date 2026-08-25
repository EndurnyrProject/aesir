defmodule Aesir.ZoneServer.Mmo.Mechanics.Defense.Renewal do
  @moduledoc """
  Renewal physical and magic defense mitigation.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.Defense

  alias Aesir.ZoneServer.Mmo.Mechanics.Defense

  @impl true
  @spec apply_def(number(), Defense.physical_context()) :: number()
  def apply_def(damage, %{hard_def: hard_def, soft_def: soft_def}) do
    effective_hard_def = if hard_def == -400, do: -399, else: hard_def

    damage * (4000 + effective_hard_def) / (4000 + 10 * effective_hard_def) - soft_def
  end

  @impl true
  @spec apply_mdef(number(), Defense.magic_context()) :: number()
  def apply_mdef(damage, %{hard_mdef: hard_mdef, soft_mdef: soft_mdef}) do
    effective_hard_mdef = if hard_mdef == -100, do: -99, else: hard_mdef

    damage * (1000 + effective_hard_mdef) / (1000 + 10 * effective_hard_mdef) - soft_mdef
  end
end

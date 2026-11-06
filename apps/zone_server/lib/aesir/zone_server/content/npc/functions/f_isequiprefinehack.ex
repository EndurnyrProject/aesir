defmodule Aesir.ZoneServer.Content.Npc.Functions.FIsequiprefinehack do
  @moduledoc """
  Checks that the refine level of the item worn in a slot is the expected one.

  ## Behavior

  Returns `1` and logs the mismatch when the refine level differs from the expected one, `0` when
  they match.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @doc """
  Callable rAthena global function `F_IsEquipRefineHack(slot, refine)`; returns `1` on a mismatch.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), 0 | 1}
  def call(ctx, args) do
    expected = Enum.at(args, 1, 0)
    worn = getequiprefinerycnt(ctx, Enum.at(args, 0, 0))

    if expected == worn do
      {ctx, 0}
    else
      ctx = logmes(ctx, "Hack: Tried to swap equip with refine +#{expected} for +#{worn}.")
      {ctx, 1}
    end
  end
end

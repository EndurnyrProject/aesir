defmodule Aesir.ZoneServer.Content.Npc.Functions.FIsequipidhack do
  @moduledoc """
  Checks that the item worn in a slot is the item the script expects.

  ## Behavior

  Returns `1` and logs the mismatch when the equipped item id differs from the expected one, `0`
  when they match.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @doc """
  Callable rAthena global function `F_IsEquipIDHack(slot, item_id)`; returns `1` on a mismatch.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), 0 | 1}
  def call(ctx, args) do
    expected = Enum.at(args, 1, 0)
    equipped = getequipid(ctx, Enum.at(args, 0, 0))

    if expected == equipped do
      {ctx, 0}
    else
      ctx =
        logmes(
          ctx,
          "Hack: Tried to swap equip #{Rathena.getitemname(expected)} for #{Rathena.getitemname(equipped)}."
        )

      {ctx, 1}
    end
  end
end

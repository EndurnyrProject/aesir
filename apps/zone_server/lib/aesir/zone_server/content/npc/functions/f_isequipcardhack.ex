defmodule Aesir.ZoneServer.Content.Npc.Functions.FIsequipcardhack do
  @moduledoc """
  Checks the four cards slotted in the item worn in a slot.

  ## Behavior

  Compares each card slot against the expected card and returns `1` on the first mismatch, logging
  the expected and the worn card. Returns `0` when all four match.

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

  @card_slots [0, 1, 2, 3]

  @doc """
  Callable rAthena global function `F_IsEquipCardHack(slot, card0, card1, card2, card3)`; returns
  `1` on a mismatch.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), 0 | 1}
  def call(ctx, args) do
    position = Enum.at(args, 0, 0)

    {ctx, mismatch} =
      Enum.reduce_while(@card_slots, {ctx, nil}, fn card_slot, {ctx, nil} ->
        expected = Enum.at(args, card_slot + 1, 0)
        worn = getequipcardid(ctx, position, card_slot)

        if expected == worn,
          do: {:cont, {ctx, nil}},
          else: {:halt, {ctx, {expected, worn}}}
      end)

    case mismatch do
      nil ->
        {ctx, 0}

      {expected, worn} ->
        ctx =
          logmes(
            ctx,
            "Hack: Tried to swap card #{Rathena.getitemname(expected)} for #{Rathena.getitemname(worn)}."
          )

        {ctx, 1}
    end
  end
end

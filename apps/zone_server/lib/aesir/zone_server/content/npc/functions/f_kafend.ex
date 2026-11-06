defmodule Aesir.ZoneServer.Content.Npc.Functions.FKafend do
  @moduledoc """
  Closes the Kafra conversation with the farewell that matches the service used.

  ## Behavior

  A save at the Kafra reports the respawn point that was stored. Otherwise the farewell depends on
  the Kafra variant: the generic one, the Niflheim one that also drains the player's SP, or the
  Rock Ridge acknowledgement.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/functions_kafras.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @doc """
  Callable rAthena global function `F_KafEnd(type, saved, area_name)`; throws `{:script_end, ctx}`
  after the farewell dialog.
  """
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, args) do
    ctx = ctx |> mes("[Kafra Employee]") |> farewell(Enum.at(args, 0, 0), args)
    ctx = ctx |> close() |> cutin("", 255)
    throw({:script_end, ctx})
  end

  defp farewell(ctx, _type, [_, saved | rest]) when saved == 1 do
    ctx
    |> mes("Your Respawn Point")
    |> mes("has been saved here")
    |> mes("#{Enum.at(rest, 0, 0)}.")
    |> mes("Thank you for using")
    |> mes("the Kafra Services.")
  end

  defp farewell(ctx, type, _args) when type in [0, 5] do
    ctx
    |> mes("We, here at Kafra Corporation,")
    |> mes(
      "are always endeavoring to provide you with the best services. We hope that we meet your adventuring needs and standards of excellence."
    )
  end

  defp farewell(ctx, 1, _args) do
    ctx
    |> percent_heal(hp: 0, sp: -25)
    |> mes("^666666Kaffffra n-never")
    |> mes("diiiiiiiiiiiiiies. On...")
    |> mes("On y-yooour siiiiide~^000000")
  end

  defp farewell(ctx, 2, _args) do
    ctx
    |> mes("Saved.")
    |> mes("Thank you for your patronage.")
  end

  defp farewell(ctx, _type, _args), do: ctx
end

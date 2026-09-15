defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Mariner do
  @moduledoc """
  Offers return passage from Jawaii to Izlude.

  ## Behavior

  - Transfers consenting passengers to the mode-appropriate Izlude arrival point.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii",
        x: 239,
        y: 112,
        dir: 7,
        sprite: 100,
        name: "Mariner",
        scope: :shared,
        unique_name: "Mariner#toizu"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mariner]")
      |> mes("This ship")
      |> mes("is heading")
      |> mes("towards ^666699Izlude^000000.")
      |> mes("Have you enjoyed your time in Jawaii? You should check to see")
      |> mes("if you forgot anything before we go.")
      |> next()
      |> mes("[Mariner]")
      |> mes("Well, then.")
      |> mes("Would you like")
      |> mes("to go back to Izlude?")
      |> next()
      |> select(["Go back.", "Cancel."])

    case choice do
      1 -> return_to_izlude(ctx)
      _ -> stay_in_jawaii(ctx)
    end
  end

  defp return_to_izlude(ctx) do
    ctx =
      ctx
      |> mes("[Mariner]")
      |> mes("Now, let me")
      |> mes("guide you to")
      |> mes("Izlude.")
      |> close()

    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "izlude", 195, 212)
    else
      warp(ctx, "izlude", 176, 182)
    end
  end

  defp stay_in_jawaii(ctx) do
    ctx
    |> mes("[Mariner]")
    |> mes("Take your time")
    |> mes("and look around as")
    |> mes("much as you like.")
    |> mes("Somehow,  this is not")
    |> mes("a place that you can")
    |> mes("visit often, you know?")
    |> close()
  end
end

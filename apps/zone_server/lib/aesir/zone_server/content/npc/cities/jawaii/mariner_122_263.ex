defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Mariner122263 do
  @moduledoc """
  Offers return passage from Jawaii to Alberta.

  ## Behavior

  - Transfers consenting passengers to Alberta after closing the dialogue.

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
        x: 122,
        y: 263,
        dir: 5,
        sprite: 100,
        name: "Mariner",
        scope: :shared,
        unique_name: "Mariner#toalbe"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mariner]")
      |> mes("This ship")
      |> mes("is headed back")
      |> mes("towards ^003399Alberta^000000.")
      |> mes("Have you enjoyed your time in Jawaii? You should check to see")
      |> mes("if you forgot anything before we go.")
      |> next()
      |> mes("[Mariner]")
      |> mes("Now, are you")
      |> mes("ready to go back")
      |> mes("to Alberta?")
      |> next()
      |> select(["Go back.", "Cancel."])

    case choice do
      1 ->
        ctx
        |> mes("[Mariner]")
        |> mes("Now, let me")
        |> mes("take you back")
        |> mes("to Alberta.")
        |> close()
        |> warp("alberta", 192, 157)

      _ ->
        ctx
        |> mes("[Mariner]")
        |> mes("Yeah...")
        |> mes("Try to enjoy your")
        |> mes("vacation as much")
        |> mes("as you can. We'll be")
        |> mes("ready to leave when")
        |> mes("you are.")
        |> close()
    end
  end
end

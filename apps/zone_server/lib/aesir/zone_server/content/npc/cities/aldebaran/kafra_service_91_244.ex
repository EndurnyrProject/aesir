defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.KafraService91244 do
  @moduledoc """
  Introduces Curly Sue and responds to teasing about her age.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 91,
        y: 244,
        dir: 4,
        sprite: 112,
        name: "Kafra Service",
        scope: :shared,
        unique_name: "Kafra Service#4alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("kafra_06", 2)
      |> mes("[Kafra Curly Sue]")
      |> mes("Hello, hello!!")
      |> mes("I'm Curly Sue,")
      |> mes("the newest member")
      |> mes("of the Kafra Staff!")
      |> next()
      |> mes("[Kafra Curly Sue]")
      |> mes(
        "I may still need to learn more about serving our customers, but I'm always doing my best!"
      )
      |> next()
      |> select(["Where's your mommy, kid?", "End conversation."])

    if choice == 1 do
      ctx
      |> mes("[Kafra Curly Sue]")
      |> mes("Waaaaaaah~!")
      |> mes("I'm not a kid!")
      |> close()
      |> cutin("", 255)
    else
      ctx
      |> mes("[Kafra Curly Sue]")
      |> mes(
        "Here at Kafra Corporation, we are all doing our very best to give you the excellent service that you expect from us."
      )
      |> close()
      |> cutin("", 255)
    end
  end
end

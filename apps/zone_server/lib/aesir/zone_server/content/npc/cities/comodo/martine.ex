defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Martine do
  @moduledoc """
  Shares Martine's unwavering optimism about gambling at the Comodo Casino.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in02",
        x: 73,
        y: 81,
        dir: 4,
        sprite: 48,
        name: "Martine",
        scope: :shared,
        unique_name: "Martine#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Martine]")
    |> mes("Gambling...? The games")
    |> mes("provided here in the Comodo")
    |> mes("Casino are a higher form of")
    |> mes("entertainment than gambling.")
    |> mes("Do you know what I mean?")
    |> next()
    |> mes("[Martine]")
    |> mes("Granted, I did lose")
    |> mes("all of my zeny playing")
    |> mes("in this Casino, but I have")
    |> mes("no regrets. I'll simply earn")
    |> mes("more money, then blow it all")
    |> mes("again. Or I just might win big!")
    |> next()
    |> mes("[Martine]")
    |> mes("Bwahahahaahah~!")
    |> mes("Yes, I can only lose so")
    |> mes("many times until I hit the")
    |> mes("jackpot! You see, you see?")
    |> mes("I'm playing the freakin' odds.")
    |> close()
  end
end

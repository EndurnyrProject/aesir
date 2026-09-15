defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.Adventurer do
  @moduledoc """
  Comments on Rachel's donation lottery and its priestesses.

  ## Behavior

  - Changes dialogue after temple donations reach 10,000 zeny.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "airplane", x: 238, y: 54, dir: 7, sprite: 88, name: "Adventurer", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_server_var(ctx, "rachel_donate", 0) < 10_000 do
      describe_lottery(ctx)
    else
      mention_priestess(ctx)
    end
  end

  defp describe_lottery(ctx) do
    ctx
    |> mes("[Adventurer]")
    |> mes("You know that the temple")
    |> mes("in Rachel is accepting")
    |> mes("donations? They're asking")
    |> mes("for a lot of zeny, but my buddies")
    |> mes("and I donated anyway. Heck, we")
    |> mes("wanted to see what we could win~")
    |> next()
    |> mes("[Adventurer]")
    |> mes("One of my buddies was")
    |> mes("real freakin' lucky. He")
    |> mes("got some kind of album,")
    |> mes("opened it up and found")
    |> mes("some kinda card inside.")
    |> mes("Really pretty stuff.")
    |> next()
    |> mes("[Adventurer]")
    |> mes("Another buddy of mine?")
    |> mes("Not so lucky. He got a")
    |> mes("Condensed White Potion...")
    |> mes("Yeah, I don't blame him for")
    |> mes("feeling a little gypped, but he")
    |> mes("donated for a good cause, right?")
    |> next()
    |> mes("[Adventurer]")
    |> mes("Me? I got some yellow")
    |> mes("bell shaped fruit. I didn't")
    |> mes("really feel like eating it,")
    |> mes("but after I took a bite,")
    |> mes("it was like... whoa.")
    |> mes("So refreshing!")
    |> next()
    |> mes("[Adventurer]")
    |> mes("Anyway, all the donations")
    |> mes("will be used to fund some")
    |> mes("kinda festival. Sooo, I don't")
    |> mes("think they'll be holding this")
    |> mes("special lottery anymore once")
    |> mes("they get enough money, you know?")
    |> close()
  end

  defp mention_priestess(ctx) do
    ctx
    |> mes("[Adventurer]")
    |> mes("You know, one of the")
    |> mes("priestesses at the temple")
    |> mes("in Rachel looked troubled")
    |> mes("for some reason. I should've")
    |> mes("asked what was bothering her,")
    |> mes("and offered my help. Mm, nah.")
    |> close()
  end
end

defmodule Aesir.ZoneServer.Content.Npc.Cities.Lutie.LittleBoy do
  @moduledoc """
  Shares Charu Charu's opinion of Snowysnow and Hashokii.

  ## Behavior

  - At story stage 9, directs visitors to ask Marcell about Snowysnow.
  - Otherwise jokes with Marcell about Hashokii's show.

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
      %{map: "xmas", x: 206, y: 168, dir: 4, sprite: 706, name: "Little Boy", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :xmas_npc, 0) == 9 do
      direct_to_marcell(ctx)
    else
      discuss_hashokii(ctx)
    end
  end

  defp direct_to_marcell(ctx) do
    ctx
    |> mes("[Charu Charu]")
    |> mes("Errrm?")
    |> mes("Snowysnow?")
    |> next()
    |> mes("[Charu Charu]")
    |> mes("Hmmm, well...")
    |> mes("He's a nice snowman!")
    |> mes("You want to know more about Snowysnow? Ummm, I'm not that smart! Ask Marcell!")
    |> close()
  end

  defp discuss_hashokii(ctx) do
    ctx
    |> mes("[Charu Charu]")
    |> mes("Merry Merry Christmas!")
    |> mes("Heheheheheh~!")
    |> next()
    |> mes("[Charu Charu]")
    |> mes("Did you talk to that clown guy over there? Isn't he soooooo booooring? (-.-)")
    |> next()
    |> mes("[Charu Charu]")
    |> mes("When Marcell and I watch his show, we feel like we're getting dumber and dumber~")
    |> next()
    |> mes("[Marcell]")
    |> mes(
      "Charu Charu!! Watch your mouth! How dare you say that about poor Hashokii?! He's always trying hard to make us happy!"
    )
    |> next()
    |> mes("[Charu Charu]")
    |> mes("Yeah, yeah.")
    |> mes("Whatever~")
    |> mes("I already know that!")
    |> mes("But he's not funny at all!")
    |> mes("I'd rather stay with ^3355FFSnowysnow^000000~")
    |> next()
    |> mes("[Charu Charu]")
    |> mes(
      "Oh well, if you didn't visit Snowysnow yet, you should see him at least once. He's funny!"
    )
    |> next()
    |> mes("[Charu Charu]")
    |> mes("Merry Christmas!")
    |> mes("Enjoy your Holiday in Lutie~!")
    |> close()
  end
end

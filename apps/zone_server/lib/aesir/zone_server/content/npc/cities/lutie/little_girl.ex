defmodule Aesir.ZoneServer.Content.Npc.Cities.Lutie.LittleGirl do
  @moduledoc """
  Shares Marcell's connection to Snowysnow and Lutie's orphans.

  ## Behavior

  - At story stage 9, reveals the matching burns and advances the story to stage 10.
  - At stage 10, directs visitors back to Snowysnow.
  - Otherwise describes Snowysnow's magical gift bag.

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
      %{map: "xmas", x: 208, y: 168, dir: 4, sprite: 703, name: "Little Girl", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :xmas_npc, 0) do
      9 -> reveal_shared_past(ctx)
      10 -> direct_to_snowysnow(ctx)
      _ -> discuss_gift_bag(ctx)
    end
  end

  defp reveal_shared_past(ctx) do
    ctx
    |> mes("[Marcell]")
    |> mes("You mean Snowysnow?")
    |> mes("Of course I know him!")
    |> next()
    |> mes("[Marcell]")
    |> mes("He's a nice and funny guy!")
    |> mes(
      "And as Charu Charu always insists, he's funnier than Hashokii~ (But please don't let Hashokii know!)"
    )
    |> next()
    |> mes("[Marcell]")
    |> mes(
      "Well, Charu Charu and I are orphans, and don't remember our parents at all. We've been brought up by the people here in Lutie."
    )
    |> next()
    |> mes("[Marcell]")
    |> mes(
      "Uncle Cantata and Auntie Thachentze treated us like their own children, and Poze and Duffle have been like a brother and sister to us!"
    )
    |> next()
    |> mes("[Marcell]")
    |> mes(
      "They're all nice and generous, and we always appreciate what they've done to take care of us."
    )
    |> next()
    |> mes("[Marcell]")
    |> mes(
      "I also heard Snowysnow doesn't have a mommy or daddy too. And I also heard Snowysnow and us weren't born here, but somewhere else."
    )
    |> next()
    |> mes("[Marcell]")
    |> mes(
      "I've heard that Snowysnow and us actually come from the same place, although I'm not sure yet. But I know that Snowysnow and me have the same kind of burns on our body."
    )
    |> next()
    |> mes("[Marcell]")
    |> mes(
      "Charu Charu and I have these old burns on our backs, and Snowysnow has a dark smudge on his tummy. So I think we got burned all at the same time..."
    )
    |> next()
    |> mes("[Marcell]")
    |> mes("Oh, now I see . . . . .")
    |> mes(
      "You wanna learn all about Snowysnow because you want to become his friend! He'll be so happy to know that! Ooh! Maybe he'll give you a present! Good luck!"
    )
    |> set_char_var(:xmas_npc, 10)
    |> close()
  end

  defp direct_to_snowysnow(ctx) do
    ctx
    |> mes("[Marcell]")
    |> mes(
      "More than anybody else, you know the most about Snowysnow! Please talk to Mr.Snowysnow, he'll be happy to know you care about him. Merry Christmas!"
    )
    |> close()
  end

  defp discuss_gift_bag(ctx) do
    ctx
    |> mes("[Marcell]")
    |> mes("Merry Christmas~!")
    |> next()
    |> mes("[Marcell]")
    |> mes(
      "It's freezing out here...! And Charu Charu makes me colder with his unbearable jokes. And the wind's blowing so hard!"
    )
    |> next()
    |> mes("[Marcell]")
    |> mes(
      "You know what? Snowysnow has a special power. He can make as many presents as Santa Claus! Isn't that great?"
    )
    |> next()
    |> mes("[Marcell]")
    |> mes(
      "Huh? What's that look on your face for? Snowysnow has a big gift bag inside of his body, and gives gifts whenever he feels like it. What's so hard to believe about that?"
    )
    |> close()
  end
end

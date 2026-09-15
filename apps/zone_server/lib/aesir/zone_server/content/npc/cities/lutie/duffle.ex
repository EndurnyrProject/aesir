defmodule Aesir.ZoneServer.Content.Npc.Cities.Lutie.Duffle do
  @moduledoc """
  Introduces visitors to Snowysnow and Lutie.

  ## Behavior

  - Advances the Snowysnow story from stage 1 to 2 after the Santa visit.
  - Shares Snowysnow rumors with visitors who have progressed further.

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
      %{map: "xmas_in", x: 167, y: 173, dir: 4, sprite: 711, name: "Duffle", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :xmas_npc, 0) do
      1 -> introduce_snowysnow(ctx)
      stage when stage > 1 -> discuss_snowysnow(ctx)
      _ -> recommend_santa(ctx)
    end
  end

  defp introduce_snowysnow(ctx) do
    ctx
    |> mes("[Duffle]")
    |> mes("Merry Christmas!")
    |> mes("Welcome to Lutie!")
    |> next()
    |> mes("[Duffle]")
    |> mes("You got a present")
    |> mes("from Santa Claus?!")
    |> mes("Ha ha, you must")
    |> mes("be really excited!")
    |> next()
    |> mes("[Duffle]")
    |> mes(
      "Hey, have you heard that here in Lutie, we have an attraction that's equally as famous as Santa himself?"
    )
    |> next()
    |> mes("[Duffle]")
    |> mes("It's ^3355FFSnowysnow^000000,")
    |> mes("the magical")
    |> mes("talking snowman!")
    |> next()
    |> mes("[Duffle]")
    |> mes(
      "Before you leave, you really should meet and talk to Snowysnow, even if it's only once. He's really a nice guy and fun to talk to."
    )
    |> next()
    |> mes("[Duffle]")
    |> mes("Well then...")
    |> mes("Merry Christmas!!")
    |> set_char_var(:xmas_npc, 2)
    |> close()
  end

  defp discuss_snowysnow(ctx) do
    ctx
    |> mes("[Duffle]")
    |> mes(
      "Have you ever talked to the snowman in front of this town? The lonely snowman who stands in solitude..."
    )
    |> next()
    |> mes("[Duffle]")
    |> mes(
      "But he's so warm hearted~! Sometimes, I talk to Snowysnow the snowman. For some weird reason, he can talk just like us!"
    )
    |> next()
    |> mes("[Duffle]")
    |> mes(
      "When I talk to Snowysnow, I get to wondering how he came to be. I guess if you talk to him too, you'll feel the same way."
    )
    |> next()
    |> mes("[Duffle]")
    |> mes("How he was created, and how he thinks and talks like a human is such a mystery...")
    |> next()
    |> mes("[Duffle]")
    |> mes(
      "Where did he come from and what kind of place was it? And how did he come to Lutie without any legs...?"
    )
    |> next()
    |> mes("[Duffle]")
    |> mes("Lately, it seems more and more people are coming to this town to see Snowysnow.")
    |> next()
    |> mes("[Duffle]")
    |> mes(
      "I guess you should talk to the other people living in Lutie if you want to learn more about the mystery of Snowysnow..."
    )
    |> close()
  end

  defp recommend_santa(ctx) do
    ctx
    |> mes("[Duffle]")
    |> mes("Oh...!")
    |> mes("While you're here, don't forget to visit the original Santa Claus here in Lutie.")
    |> close()
  end
end

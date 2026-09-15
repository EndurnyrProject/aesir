defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.Drunkard do
  @moduledoc """
  Begs visitors for a drink and rambles about his past.

  ## Behavior

  - Greets Archers more warmly than other jobs.
  - Attempts to take 100 zeny for a drink, but sets zeny to zero when the visitor has less.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 210,
        y: 110,
        dir: 1,
        sprite: 120,
        name: "Drunkard",
        scope: :shared,
        unique_name: "Drunkard#payon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = greet_visitor(ctx)

    {ctx, choice} =
      ctx
      |> next()
      |> select(["Alright, but only one drink.", "No thanks, pal.", "Oh my God! Hell no!"])

    ctx
    |> answer_offer(choice)
    |> close()
  end

  defp greet_visitor(ctx) do
    if class(ctx) != :archer do
      ctx
      |> mes("[Drunkard]")
      |> mes("Hey...")
      |> mes("H-Hey...!")
      |> next()
      |> mes("[Drunkard]")
      |> mes("I wonder why those")
      |> mes("stupid Archers even")
      |> mes("bother trying to aim!")
      |> mes("You're all weak!")
      |> mes("Weeeeak!")
      |> next()
      |> mes("[Drunkard]")
      |> mes("Bwahahahaha!")
      |> mes("Buy me a drink?!")
    else
      ctx
      |> mes("[Drunkard]")
      |> mes("An Archer!")
      |> mes("Oh man, you guys!")
      |> mes("You guys are the best!")
      |> next()
      |> mes("[Drunkard]")
      |> mes("Bwahahahaha!")
      |> mes("Buy me a drink?!")
    end
  end

  defp answer_offer(ctx, 1) do
    ctx
    |> todo(:set_param, ["Zeny", if(zeny(ctx) < 100, do: 0, else: zeny(ctx) - 100)])
    |> mes("[Drunkard]")
    |> mes("Thanks...!")
    |> mes("..Brother!")
    |> next()
    |> mes("[Drunkard]")
    |> mes("Most people don't even wanna")
    |> mes(
      "buy me drinks! Maybe cuz I used to fool around too much with the ladies back in my day!"
    )
    |> next()
    |> mes("[Drunkard]")
    |> mes(
      "Though, the women I used to play with are grannies now! Hahahaha! One of them still primps herself with makeup and stuff! Can you believe that?!"
    )
    |> next()
    |> mes("[Drunkard]")
    |> mes("I'm like...")
    |> mes("Come on...!")
    |> mes("Some faces are")
    |> mes("beyond fixing!")
    |> mes("Oh? I made a funny!")
    |> mes("Bwahahahahahah!")
    |> next()
    |> mes("[Drunkard]")
    |> mes("^666666*Gulp~ Gulp~*^000000")
    |> mes("Man, this is great!")
    |> mes("You the maaaaaaan~!")
    |> mes("Muhahahahaha!")
  end

  defp answer_offer(ctx, 2) do
    ctx
    |> mes("[Drunkard]")
    |> mes("Bah!")
    |> mes("Kids nowadays!")
    |> mes("Now respect for")
    |> mes("their elders! Fine!")
    |> mes("I'm not gonna beg you!")
  end

  defp answer_offer(ctx, 3) do
    ctx
    |> mes("[Drunkard]")
    |> mes("Fine...!")
    |> mes("Fine by me!")
  end

  defp answer_offer(ctx, _choice), do: ctx
end

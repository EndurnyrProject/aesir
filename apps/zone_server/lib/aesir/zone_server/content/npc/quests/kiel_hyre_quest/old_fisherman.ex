defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.OldFisherman do
  @moduledoc """
  The old fisherman recalls the woman and ring connected to Kiel Hyre’s past.

  ## Behavior

  - Trades his account and the location of the old hut for ten Raw Fish during the investigation.
  - Reminds the player where to find the hut after advancing the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_fild12",
        x: 232,
        y: 222,
        dir: 0,
        sprite: 709,
        name: "Old Fisherman",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest < 60 ->
        ctx
        |> mes("[Fisherman]")
        |> mes("These days, it's much")
        |> mes("harder to catch and fish.")
        |> mes("Ever since they built")
        |> mes("this factory, the fish")
        |> mes("have started to change,")
        |> mes("and they look different too...")
        |> close()

      quest == 60 ->
        ask_for_fish(ctx)

      quest >= 62 ->
        ctx
        |> mes("[Fisherman]")
        |> mes("Don't you remember")
        |> mes("what I told you? That")
        |> mes("guy lived in a hut near")
        |> mes("the northeast forest")
        |> mes("guard camp! Why don't")
        |> mes("you check that place out?")
        |> close()

      true ->
        ctx
    end
  end

  defp ask_for_fish(ctx) do
    ctx =
      ctx
      |> mes("[Fisherman]")
      |> mes("Eh? You want something?")
      |> mes("Heh, youngsters! I know")
      |> mes("how much you love handouts,")
      |> mes("but you're not getting any.")
      |> mes("Now, if you bring me some")
      |> mes("Raw Fish, I'd be more friendly~")

    if count_item(ctx, 544) >= 10 do
      recount_history(ctx)
    else
      close(ctx)
    end
  end

  defp recount_history(ctx) do
    {ctx, _} =
      ctx
      |> next()
      |> mes("[Fisherman]")
      |> mes("Oh, is all this fish")
      |> mes("for me? Heh, how very")
      |> mes("generous of you. If you're")
      |> mes("going to be so kind, then")
      |> mes("I suppose I have to repay")
      |> mes("the favor. Ask me anything~")
      |> next()
      |> select(["30 years ago, a woman killed herself..."])

    {ctx, _} =
      ctx
      |> mes("[Fisherman]")
      |> mes("Oh? Ohh. Oh yeah.")
      |> mes("I remember that. Yeah.")
      |> mes("it was August 20th, my")
      |> mes("wife's birthday. That day,")
      |> mes("instead of catching fish,")
      |> mes("I caught a dead woman.")
      |> next()
      |> mes("[Fisherman]")
      |> mes("Of course, I reported it")
      |> mes("to the Juno Police!  They told")
      |> mes("me she killed herself since")
      |> mes("she was betrayed by her lover,")
      |> mes("who also happened to be her")
      |> mes("employer. Really tragic stuff.")
      |> next()
      |> mes("[Fisherman]")
      |> mes("Anyway, when they were")
      |> mes("moving her body out of the")
      |> mes("river, her hand dropped")
      |> mes("some ring. I picked it up,")
      |> mes("hoping to sell it later for")
      |> mes("some zeny. I know, I know...")
      |> next()
      |> mes("[Fisherman]")
      |> mes("I was pretty lucky the")
      |> mes("police didn't see me take")
      |> mes("it. Later that day, some guy")
      |> mes("came up to me and offered")
      |> mes("me a lot of money for it.")
      |> mes("I guess it was my lucky day!")
      |> next()
      |> mes("[Fisherman]")
      |> mes("I found out later that he was")
      |> mes("some mechanical repairman--")
      |> mes("something. He sold everything")
      |> mes("to buy that ring, so I guess")
      |> mes("he wanted it desperately.")
      |> mes("Then he just dissapeared.")
      |> next()
      |> select(["Do you remember his name?"])

    ctx
    |> mes("[Fisherman]")
    |> mes("His name...?")
    |> mes("It was something like...")
    |> mes("Heil? Hyre? Anyway, it")
    |> mes("was a long time ago. Oh,")
    |> mes("his old house is still around.")
    |> next()
    |> mes("[Fisherman]")
    |> mes("If you're going to be")
    |> mes("that curious, you might")
    |> mes("as well check it out.")
    |> mes("Let's see, he lived in")
    |> mes("a hut near the northeast")
    |> mes("forest guard camp.")
    |> delitem(544, 10)
    |> set_char_var(:KielHyreQuest, 62)
    |> close()
  end
end

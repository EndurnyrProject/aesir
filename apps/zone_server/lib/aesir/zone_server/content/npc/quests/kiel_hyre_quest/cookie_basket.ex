defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.CookieBasket do
  @moduledoc """
  Elly’s cookie basket holds letters that advance her story.

  ## Behavior

  - Reveals her plea for help and advances the search for her room.
  - Offers her final letter, accepts a farewell, and returns the visitor outside.

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
        map: "kh_school",
        x: 175,
        y: 176,
        dir: 0,
        sprite: 111,
        name: "Cookie Basket",
        scope: :shared,
        unique_name: "Cookie Basket#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage < 30 ->
        ctx
        |> mes("^3355FFIt's a cookie")
        |> mes("basket filled with")
        |> mes("delicious cookies.^000000")
        |> close()

      quest_stage == 30 ->
        read_plea(ctx)

      quest_stage < 108 ->
        ctx
        |> mes("^3355FFThese cookies aren't")
        |> mes("stale yet, but they're no")
        |> mes("longer warm. If they're")
        |> mes("not at room temperature,")
        |> mes("then they're a little cold.^000000")
        |> close()

      quest_stage == 108 ->
        read_farewell(ctx)

      true ->
        ctx
        |> mes("^3355FFAll the cookies")
        |> mes("in this basket are")
        |> mes("stale! Well, it shouldn't")
        |> mes("come as a surprise.")
        |> mes("It's been a long time")
        |> mes("since they were baked.^000000")
        |> close()
    end
  end

  defp read_plea(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis must be")
      |> mes("Elly's cookie basket.")
      |> mes("There appears to be")
      |> mes("a folded note wedged")
      |> mes("between the cookies.^000000")
      |> next()
      |> select(["Read Note", "Ignore"])

    case choice do
      1 ->
        ctx
        |> mes("#{char_name(ctx, 0)}, help!")
        |> mes("There's this guy dressed in")
        |> mes("black who's walking around,")
        |> mes("and casting this weird spell!")
        |> mes("He's the one that's been making")
        |> mes("people cold and lifeless as")
        |> mes("puppets! I'm getting scared!")
        |> mes("^FFFFFF_^000000")
        |> mes("I hope you get this note...")
        |> mes("He ran after me, but I locked")
        |> mes("myself in my room. I'm going")
        |> mes("to leave my window open so that")
        |> mes("you can still find me. I hope he")
        |> mes("doesn't cast his curse on me!")
        |> set_char_var(:KielHyreQuest, 32)
        |> close()

      2 ->
        ctx
        |> mes("^3355FFThat note probably")
        |> mes("wasn't written just")
        |> mes("for you, anyway.^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp read_farewell(ctx) do
    ctx =
      ctx
      |> mes("^3355FFAs you stare at the")
      |> mes("cookie basket, the wind")
      |> mes("from the window jostles")
      |> mes("it, revealing a letter that")
      |> mes("was placed underneath.")
      |> mes("It was probably written")
      |> mes("by Elly for you to read.^000000")
      |> next()

    {ctx, farewell} =
      ctx
      |> mes("^333333Dearest #{char_name(ctx, 0)},")
      |> mes(" ")
      |> mes("My teachers usually yell at me")
      |> mes("since I make so many mistakes,")
      |> mes("but today Mrs. Lecollane gave me")
      |> mes("praise for my yummy cookies!")
      |> mes("It's all thanks to you, my friend.")
      |> mes("I'm very happy we've met:")
      |> mes("you've taught me that there")
      |> mes("are good people in the world.")
      |> mes("And I know Grandpa will like")
      |> mes("you, though, I don't know")
      |> mes("where he could be...")
      |> mes(" ")
      |> mes("Someday, I hope to become")
      |> mes("as nice a person as you are.")
      |> mes("Let's keep in touch and be")
      |> mes("really good friends, okay?")
      |> mes(" ")
      |> mes("Yours, Elly^000000")
      |> next()
      |> mes("^3355FFIt feels like you can")
      |> mes("still sense Elly's warmth")
      |> mes("and kindness from her")
      |> mes("cookie basket. You picked")
      |> mes("out a cookie, and put it")
      |> mes("in your mouth. It was")
      |> mes("deliciously bittersweet.")
      |> set_char_var(:KielHyreQuest, 109)
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", farewell)

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("#{get_local(ctx, :"input$", "")}")
    |> mes("It's time to go back. I can't")
    |> mes("stay here much longer.")
    |> close()
    |> warp("yuno_fild08", 69, 183)
  end
end

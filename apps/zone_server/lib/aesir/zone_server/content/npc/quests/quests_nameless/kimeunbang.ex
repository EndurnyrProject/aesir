defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Kimeunbang do
  @moduledoc """
  A jeweler discusses the Diamond of Destruction and a cursed emerald.

  ## Behavior

  - Responds to quest progress and rewards the player for listening.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "payon", x: 69, y: 65, dir: 5, sprite: 89, name: "Kimeunbang", scope: :shared}]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :diamond_edq, 0) == 15 ->
        {ctx, choice} =
          ctx
          |> mes("[Kimeunbang]")
          |> mes("Zzzz... Huh?")
          |> mes("Why'd you wake me?")
          |> mes("Such a good dream too.")
          |> mes("Go to another jewelry shop,")
          |> mes("I don't feel like opening up.")
          |> next()
          |> select(["What's wrong?", "Diamond of Destruction?"])

        case choice do
          1 ->
            ctx
            |> mes("[Kimeunbang]")
            |> mes("I'm just disappointed.")
            |> mes("I was so close to getting")
            |> mes("that Diamond of Destruction.")
            |> mes("So close! Belder, my business")
            |> mes("partner, actually snatched")
            |> mes("it up from some poor sap.")
            |> next()
            |> mes("[Kimeunbang]")
            |> mes("Somehow, Belder ended up")
            |> mes("returning the jewel. I was")
            |> mes("going to buy the jewel from")
            |> mes("the original owner, but then")
            |> mes("this upstart jeweler got to")
            |> mes("it before I could. Damn it!")
            |> next()
            |> mes("[Kimeunbang]")
            |> mes("This was a monumental")
            |> mes("failure. I haven't been")
            |> mes("able to sleep, I don't want")
            |> mes("to work. Ugh. Well, thanks")
            |> mes("for letting me get that off")
            |> mes("my chest. I feel a bit better.")
            |> next()
            |> mes("[Kimeunbang]")
            |> mes("Here, take this as")
            |> mes("a little gift. Not all of us")
            |> mes("jewelers are as greedy")
            |> mes("as you think we are. Heh.")
            |> give_item(722, 1)
            |> set_char_var(:diamond_edq, 16)
            |> close()

          2 ->
            ctx
            |> mes("[Kimeunbang]")
            |> mes("Oh! That diamond is the")
            |> mes("very reason for my agony!")
            |> mes("I was so close to getting it...")
            |> mes("But then someone got to the")
            |> mes("diamond before I did. Argh!")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :diamond_edq, 0) != 26 or get_char_var(ctx, :jewel_nd, 0) == 0 ->
        ctx
        |> mes("[Kimeunbang]")
        |> mes("I don't feel like opening")
        |> mes("my shop any time soon, but")
        |> mes("you can always come back later.")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 1 ->
        {ctx, choice} =
          ctx
          |> mes("[Kimeunbang]")
          |> mes("Oh, hello. Looks like")
          |> mes("I'm back in business~")
          |> next()
          |> select(["I have a jewel to sell.", "How are you?"])

        case choice do
          1 ->
            ctx =
              ctx
              |> mes("[Kimeunbang]")
              |> mes("Really? Alright, just")
              |> mes("give me a minute to")
              |> mes("appraise your gem.")
              |> next()

            if count_item(ctx, 7725) > 0 do
              ctx
              |> mes("[Kimeunbang]")
              |> mes("...........")
              |> mes("...........")
              |> next()
              |> mes("[Kimeunbang]")
              |> mes("I'm sorry, but I just")
              |> mes("can't buy this emerald.")
              |> mes("It's... It's too big of")
              |> mes("a risk. The rumors I keep")
              |> mes("hearing, they're just horrible.")
              |> set_char_var(:jewel_nd, 2)
              |> close()
            else
              ctx
              |> mes("[Kimeunbang]")
              |> mes("Hm? Where's this")
              |> mes("jewel you were talking")
              |> mes("about? Did you forget")
              |> mes("to bring it with you?")
              |> close()
            end

          2 ->
            ctx
            |> mes("[Kimeunbang]")
            |> mes("I don't even feel like")
            |> mes("talking about my business.")
            |> mes("I've been considering closing")
            |> mes("up shop for good, actually.")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :jewel_nd, 0) == 2 ->
        ctx
        |> mes("[Kimeunbang]")
        |> mes("No jeweler around will")
        |> mes("buy that cursed emerald.")
        |> mes("I'm really sorry. You can")
        |> mes("try talking to Ibrahim, though.")
        |> mes("He's the one that got that")
        |> mes("Diamond of Destruction.")
        |> close()

      true ->
        ctx
        |> mes("[Kimeunbang]")
        |> mes("Ugh... The stress")
        |> mes("of the jewel business")
        |> mes("is finally getting to me.")
        |> mes("Oh well, I've had a good run...")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end

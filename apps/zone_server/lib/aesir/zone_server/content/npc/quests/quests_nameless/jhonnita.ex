defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Jhonnita do
  @moduledoc """
  A jewel merchant discusses the Diamond of Destruction and a suspicious emerald.

  ## Behavior

  - Offers different dialogue as the jewel investigation progresses.

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
    spawn: [
      %{map: "alberta", x: 102, y: 80, dir: 3, sprite: 86, name: "Jhonnita", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :diamond_edq, 0) == 15 or get_char_var(ctx, :diamond_edq, 0) == 16 ->
        {ctx, choice} =
          ctx
          |> mes("[Jhonnita]")
          |> mes("Oh, it's always nice")
          |> mes("to see a new face~")
          |> mes("So were you interested")
          |> mes("in selling or buying")
          |> mes("a jewel? We only carry")
          |> mes("the best. Hahahaha!")
          |> next()
          |> select(["What's the most popular jewel?", "Do you know Diamond of Destruction?"])

        case choice do
          1 ->
            ctx
            |> mes("[Jhonnita]")
            |> mes("Ah, take a look at this")
            |> mes("lustrous ruby. Isn't it")
            |> mes("just breathtaking? It can")
            |> mes("be yours for the specially")
            |> mes("discounted price of just")
            |> mes("1,000,000 zeny!")
            |> next()
            |> mes("[Jhonnita]")
            |> mes("Wait, where are you--?")
            |> mes("Damn, I shouldn't have")
            |> mes("marked it up so much.")
            |> mes("Rookie mistake, rookie")
            |> mes("mistake! I'm a professional!")
            |> close()

          2 ->
            ctx
            |> mes("[Jhonnita]")
            |> mes("Diamond of Destruction?")
            |> mes("Heh heh! A rookie like you")
            |> mes("wouldn't appreciate its true")
            |> mes("value. I wanted it so badly,")
            |> mes("but that Ibrahim was much")
            |> mes("luckier that I was...")
            |> next()
            |> mes("[Jhonnita]")
            |> mes("It makes me so upset to")
            |> mes("think about how I lost to")
            |> mes("him. All the big jewelers")
            |> mes("are trying to snatch up")
            |> mes("the Four Cursed Jewels...")
            |> mes("But only one showed up so far.")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :diamond_edq, 0) == 26 ->
        cond do
          get_char_var(ctx, :jewel_nd, 0) == 0 ->
            ctx
            |> mes("[Jhonnita]")
            |> mes("Hey. You look familiar.")
            |> mes("You're not one of my")
            |> mes("regulars, are you?")
            |> mes("No, couldn't be.")
            |> mes("You're not dressed")
            |> mes("richly enough. No offense.")
            |> close()

          get_char_var(ctx, :jewel_nd, 0) == 1 ->
            {ctx, choice} =
              ctx
              |> mes("[Jhonnita]")
              |> mes("So you here to sell")
              |> mes("any Garlets, or did you")
              |> mes("come to spend your life")
              |> mes("savings on my jewels?")
              |> next()
              |> select(["Show me some jewels...", "I have a rare emerald to sell..."])

            case choice do
              1 ->
                ctx =
                  ctx
                  |> mes("[Jhonnita]")
                  |> mes("It couldn't hurt to")
                  |> mes("show you my wares, but...")
                  |> mes("I doubt you can afford them.")
                  |> mes("Jewels aren't cheap, you know?")
                  |> next()

                if sex(ctx) == 1 do
                  ctx
                  |> mes("[Jhonnita]")
                  |> mes("Oh, I get it now. You want")
                  |> mes("to give one as a present to")
                  |> mes("some woman. Isn't that typical?")
                  |> mes("Can't you come up with a more")
                  |> mes("creative way to buy some")
                  |> mes("woman's love? Huh?")
                  |> close()
                else
                  ctx
                  |> mes("[Jhonnita]")
                  |> mes("Sorry, sweetheart, but")
                  |> mes("I have a strict ''no window")
                  |> mes("shopping'' policy. ")
                  |> close()
                end

              2 ->
                if count_item(ctx, 7725) > 0 do
                  ctx =
                    ctx
                    |> mes("[Jhonnita]")
                    |> mes("Rare emerald, eh?")
                    |> mes("It better not be something")
                    |> mes("like a Garlet or a Zargon!")
                    |> mes("Sometimes you guys make")
                    |> mes("that kind of mistake.")
                    |> mes("Okay, let's see...")
                    |> next()
                    |> mes("[Jhonnita]")
                    |> mes("......")
                    |> mes("Umm...")
                    |> next()
                    |> mes("[Jhonnita]")
                    |> mes("...........................Um.")
                    |> mes("It's an incredibly nice")
                    |> mes("emerald, but I can't take")
                    |> mes("this off your hands. Er,")
                    |> mes("would you be on your way?")
                    |> next()

                  ctx
                  |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                  |> mes("Huh? But why?")
                  |> next()
                  |> mes("[Jhonnita]")
                  |> mes("J-just get out of my")
                  |> mes("shop! Go... Go to Payon")
                  |> mes("and talk to Kimeunbang!")
                  |> mes("Y-yeah, and don't come back!")
                  |> set_char_var(:jewel_nd, 2)
                  |> close()
                else
                  ctx
                  |> mes("[Jhonnita]")
                  |> mes("What'd I tell you, huh?")
                  |> mes("I don't want you here")
                  |> mes("in my shop anymore!")
                  |> close()
                end

              _ ->
                ctx
            end

          get_char_var(ctx, :jewel_nd, 0) == 2 ->
            ctx
            |> mes("[Jhonnita]")
            |> mes("Look, I'll level with you.")
            |> mes("Rumors spread fast amongst")
            |> mes("us jewelers. Nobody will get")
            |> mes("near you if they know you")
            |> mes("have that jewel. You get it")
            |> mes("now? Please... Stay back...")
            |> close()

          true ->
            ctx
            |> mes("[Jhonnita]")
            |> mes("I don't want anything")
            |> mes("to do with your weird")
            |> mes("emerald or with you.")
            |> mes("Aren't you leaving")
            |> mes("already? Go away!")
            |> close()
        end

      true ->
        ctx
        |> mes("[Jhonnita]")
        |> mes("Are you here to buy or")
        |> mes("sell any jewels? I always")
        |> mes("buy high and sell low.")
        |> mes("Come to me for all of")
        |> mes("your gem related needs~")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end

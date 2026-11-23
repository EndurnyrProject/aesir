defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.HighLaphine do
  @moduledoc """
  Grenouille coordinates the Alfheim perfume quest.

  ## Behavior

  - Sends players to obtain a flower and prepares perfume for exhausted soldiers.
  - Rewards the completed delivery and controls the repeat cooldown.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_in01",
        x: 30,
        y: 324,
        dir: 3,
        sprite: 446,
        name: "High Laphine",
        scope: :shared,
        unique_name: "High Laphine#grenouille"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      if checkweight(ctx, [{1201, 1}]) == 0 do
        ctx
        |> mes("[Grenouille]")
        |> mes("It looks like you're carrying too many things.")
        |> mes("Why not put some of your items in storage and come back?")
        |> close()
      else
        perfume_quest(ctx)
      end
    else
      ctx
      |> mes("[High Laphine]")
      |> mes("BurYurDath Ee NeKoIyaz er ModRuAlah Yee VeldDuDur Yee SeYurOsa U ReNudNud Ra ")
      |> next()
      |> mes("[High Laphine]")
      |> mes(
        "DiebVrumDana er TingNothDim No RasVilHir Yu YurAdorShar Yu DanaVeldDur Ha VilModMe O SharThus"
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp perfume_quest(ctx) do
    ctx = set_local(ctx, :dayq_chk, checkquest(ctx, 2186, :playtime))

    if get_local(ctx, :dayq_chk, 0) == -1 or get_local(ctx, :dayq_chk, 0) == 2 do
      if get_char_var(ctx, :ep13_2_tre1, 0) < 1 or get_char_var(ctx, :ep13_2_tre1, 0) == 6 do
        ctx =
          if get_local(ctx, :dayq_chk, 0) == 2 do
            erasequest(ctx, 2186)
          else
            ctx
          end

        ctx
        |> set_char_var(:ep13_2_tre1, 0)
        |> mes("[Grenouille]")
        |> mes("I've heard that some strangers from Midgard are around here, it must be you.")
        |> mes("I'm Grenouille, a scientist.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("It's been a long time since")
        |> mes("the Laphine built the Splendide camp here")
        |> mes("and confronted each other.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("A number of soldiers who")
        |> mes("left their hometown Alfheim are")
        |> mes("restraining them with fighting against")
        |> mes("the harsh cold of Jotunheim")
        |> mes("for the holy duty and the faith to")
        |> mes("stop the evil attempts to")
        |> mes("sickening Yggdrasil.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("They're well trained soldiers,")
        |> mes("and their captains hold them in high esteem,")
        |> mes("so they're enjoying a")
        |> mes("comfortable life there.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("But there's a saying that")
        |> mes("constant dripping water")
        |> mes("wears away the stone.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("Continuous small battles without big progression")
        |> mes("makes the soldiers in Splendide exhausted.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("One day, someone began to sing")
        |> mes("a song of Alfheim, that spread rapidly...")
        |> mes("Now they strongly")
        |> mes("miss their hometown.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("I was so worried about them and")
        |> mes("I finally found a way to")
        |> mes("save them from the deep sadness.")
        |> mes("I hope you to help me to do that.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("There's a Laphine General")
        |> mes("who is called Flowery,")
        |> mes("in Splendide.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("She is a collecting maniac,")
        |> mes("so her house is always")
        |> mes("in a mess with miscellaneous")
        |> mes("things. Flowery must have")
        |> mes("seeds from the flowers")
        |> mes("of Alfheim.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("I'll make the flower of")
        |> mes("Alfheim open with the seed.")
        |> mes("The flower of their hometown.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("There are some devices that purify")
        |> mes("the environment and have a function")
        |> mes("that can hasten the growth of plants.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("Please bring me the flower of Alfheim that bloomed by the device.")
        |> next()
        |> mes("[Grenouille]")
        |> mes("The flower of Alfheim is not")
        |> mes("strong enough to keep it's life by")
        |> mes("depending on the Splendide device,")
        |> mes("but ^FF0000the way^000000 can fill")
        |> mes("Splendide by it's scent like it never falls!")
        |> set_char_var(:ep13_2_tre1, 1)
        |> setquest(2183)
        |> close()
      else
        if get_char_var(ctx, :ep13_2_tre1, 0) == 1 or get_char_var(ctx, :ep13_2_tre1, 0) == 2 do
          ctx
          |> mes("[Grenouille]")
          |> mes("Get a seed from Flowery,")
          |> mes("and then use a Purifier")
          |> mes("to make the seed blossom.")
          |> close()
        else
          if get_char_var(ctx, :ep13_2_tre1, 0) == 3 do
            if count_item(ctx, 6079) == 1 do
              ctx = emotion(ctx, :sweat)

              ctx
              |> emotion(:sweat, playerattached(ctx))
              |> mes("[Grenouille]")
              |> mes("Hoo, this is one of the")
              |> mes("most common kinds of flowers.")
              |> next()
              |> emotion(:smile)
              |> mes("[Grenouille]")
              |> mes("Haha, Don't worry.")
              |> mes(
                "Common flowers like this can bring the familiarity of home back to the soldiers."
              )
              |> next()
              |> mes("[Grenouille]")
              |> mes("For now, I'll extract a liquid that")
              |> mes("includes the scent of this flower by using a distiller.")
              |> mes("Making a ^3131FFPerfume^000000.")
              |> next()
              |> mes("[Grenouille]")
              |> mes("Would you please wait a while?")
              |> changequest(2183, 2184)
              |> set_char_var(:ep13_2_tre1, 4)
              |> delitem(6079, 1)
              |> close()
            else
              ctx |> mes("[Grenouille]") |> mes("Where is the flower?") |> close()
            end
          else
            if get_char_var(ctx, :ep13_2_tre1, 0) == 4 do
              ctx = set_local(ctx, :ttalk, Enum.random(1..10))

              waiting = get_local(ctx, :ttalk, 0) < 8

              ctx =
                ctx
                |> mes("- clitter-clatter -")
                |> next()
                |> mes("- clitter-clatter -")
                |> mes("- clitter-clatter -")
                |> next()
                |> mes("- clitter-clatter -")
                |> mes("- clitter-clatter -")
                |> mes("- Spraying something -")
                |> next()

              if waiting do
                ctx
                |> mes("[Grenouille]")
                |> mes("Not finished yet.")
                |> mes("Please wait a second.")
                |> close()
              else
                ctx
                |> mes("[Grenouille]")
                |> mes("Wow, finished!")
                |> next()
                |> mes("[Grenouille]")
                |> mes("I think I'll call this perfume")
                |> mes("The ^3131FFSoul of Alfheim^000000!")
                |> next()
                |> mes("[Grenouille]")
                |> mes("This perfume can relieve their minds by using")
                |> mes("the scent of their hometown Alfheim.")
                |> mes(
                  "Though it's not a permanent solution, I think it will help them feel comfortable for now."
                )
                |> next()
                |> mes("[Grenouille]")
                |> mes("Here, I'll give you this perfume,")
                |> mes("help the exhausted soldiers and")
                |> mes("let me know the result, please!")
                |> set_char_var(:ep13_2_tre1, 5)
                |> give_item(6082, 5)
                |> changequest(2184, 2185)
                |> close()
              end
            else
              if get_char_var(ctx, :ep13_2_tre1, 0) == 5 do
                if count_item(ctx, 6082) < 1 do
                  ctx =
                    ctx
                    |> mes("[Grenouille]")
                    |> mes("Oh! How's the reaction of the soldiers?")
                    |> next()

                  ctx
                  |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                  |> mes("Yes, they seemed to be happy.")
                  |> mes("But, it still made someone cry because he probably misses Alfheim.")
                  |> next()
                  |> mes("[Grenouille]")
                  |> mes("Oh! That means it works!")
                  |> mes("Thanks.")
                  |> next()
                  |> mes("[Grenouille]")
                  |> mes("Thanks for your help.")
                  |> mes("This is my reward for you.")
                  |> mes("I hope this will be helpful to you.")
                  |> mes(
                    "If you have something to talk to me about, come to me whenever. Nice to meet you, human from Midgard."
                  )
                  |> set_char_var(:ep13_2_tre1, 6)
                  |> changequest(2185, 2186)
                  |> give_item(6081, 3)
                  |> close()
                else
                  ctx
                  |> mes("[Grenouille]")
                  |> mes("Go and spray this perfume for the exhausted soldiers in Splendide!")
                  |> close()
                end
              else
                ctx
                |> mes("[Grenouille]")
                |> mes("I hope this long battle will end soon.")
                |> close()
              end
            end
          end
        end
      end
    else
      ctx |> mes("[Grenouille]") |> mes("I hope this long battle will end soon.") |> close()
    end
  end
end

defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Luik do
  @moduledoc """
  Luik investigates Terra and the missing Sapha Ogen.

  ## Behavior

  - Questions the player about Terra and asks for evidence.
  - Accepts the muffler and bradium fragments to advance the rescue.

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
        map: "man_in01",
        x: 19,
        y: 126,
        dir: 3,
        sprite: 450,
        name: "Luik",
        scope: :shared,
        unique_name: "Luik#ep13md16"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 2}]) == 0 do
      ctx
      |> mes("Wait a moment!!")
      |> mes("You have too many items.")
      |> mes("You can't receive this.")
      |> mes("Lighten your weight and")
      |> mes("try again.")
      |> close()
    else
      talk_when_ready(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk_when_ready(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      if get_char_var(ctx, :ep13_mdrama, 0) < 20 do
        ctx
        |> mes("[Luik]")
        |> mes("...I really look forward to drawing something useful out of her.")
        |> mes("Your interpretion is trustworthy, right?")
        |> close()
      else
        if get_char_var(ctx, :ep13_mdrama, 0) == 20 do
          {ctx, _} =
            ctx
            |> mes("[Luik]")
            |> mes("First of all, Why did that Laphine come here?")
            |> mes("Why does she need a bradium?")
            |> next()
            |> select(["To give it to a Sapha in a cave..."])

          ctx =
            ctx
            |> mes("[Luik]")
            |> mes("Sapha in a cave? What cave?")
            |> mes("Nevermind.... Snorren. You must know something about that cave, right?")
            |> next()
            |> mes("[Luik]")
            |> mes("Wait...")
            |> mes("Why would a Laphine give a bradium to our ally?")
            |> next()

          {ctx, _} =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("They fought in the cave and your friend got hurt and began to petrify.")
            |> mes("So she came here to get a bradium to try to save his life...")
            |> next()
            |> mes("[Luik]")
            |> mes("They fought?")
            |> mes("Snorren! What's that look on your face?")
            |> mes("Spit if out if you have anything to say.")
            |> next()
            |> mes("[Snorren]")
            |> mes("Frankly, Luik. I... told you... Ogen's missing.")
            |> mes("Ogen's disappearance and that Laphine's arrival coincide...")
            |> next()
            |> mes("[Luik]")
            |> mes("And?")
            |> next()
            |> mes("[Snorren]")
            |> mes("Maybe the Sapha that Laphine is talking about is Ogen.")
            |> mes("Or do we have any other comrades who go to strange caves?")
            |> next()
            |> mes("[Luik]")
            |> mes("We don't, because there are no caves like that here.")
            |> mes("First, we should find out about the cave they are talking about.")
            |> next()
            |> mes("[Luik]")
            |> mes("You outsiders are in contact with the Laphine right?")
            |> mes("What if this is an evil plot by them?")
            |> next()
            |> select(["That's not true!"])

          ctx =
            ctx
            |> mes("[Luik]")
            |> mes("And how would you prove it?")
            |> mes("We've been fighting them for a long time.")
            |> mes("We don't have any reason to trust what you or they are saying.")
            |> next()
            |> mes("[Luik]")
            |> mes("And talking about some cave that doesn't even exist.")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("That cave really exists, I swear!")
            |> mes("I.. yeah. I saw a petrified Sapha in that cave.")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("I will bring back something that will make you believe.")
            |> mes("I'm not sure if that Sapha is this Ogen you are looking for...")
            |> mes("But I'll come back...")
            |> next()

          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Don't you dare...try to do any harm to Terra.")
          |> set_char_var(:ep13_mdrama, 21)
          |> changequest(7065, 7066)
          |> close()
        else
          if get_char_var(ctx, :ep13_mdrama, 0) == 21 do
            ctx
            |> mes("[Luik]")
            |> mes(
              "...Anything will do. Try and make me believe you -Outsider- and that Laphine."
            )
            |> mes("We Sapha are not stupid people.")
            |> next()
            |> mes("[Luik]")
            |> mes(
              "I promise you that we will continue to treat that Laphine as we did so far and will not do any harm to her."
            )
            |> next()
            |> mes("[Luik]")
            |> mes("Hence, you just focus on finding a way to make us believe you.")
            |> close()
          else
            if get_char_var(ctx, :ep13_mdrama, 0) == 22 do
              if count_item(ctx, 6085) > 0 and count_item(ctx, 6084) > 0 do
                {ctx, _} =
                  ctx
                  |> mes("[Luik]")
                  |> mes("...This Bradium has not been refined properly...")
                  |> mes("This would be no help...")
                  |> mes("and, this muffler...")
                  |> next()
                  |> mes("[Snorren]")
                  |> mes("This is Ogen's! Ogen's muffler!")
                  |> mes("Luik! Ogen! This is Ogen!")
                  |> mes("Unrefined Bradium!")
                  |> next()
                  |> mes("[Snorren]")
                  |> mes("Lu.. Luik. Ogen.. Ogen...?!")
                  |> mes("I'm going to Ogen!")
                  |> mes("Where is that cave?! Where!")
                  |> next()
                  |> select(["Calm down!"])

                ctx =
                  ctx
                  |> mes("[Luik]")
                  |> mes("Yeah. Listen to him, calm down. Snorren.")
                  |> mes("If it is Ogen... We could be able to save him if we make haste.")
                  |> next()
                  |> mes("[Luik]")
                  |> mes("Snorren. Go to Refinery and get the finest bradium...")
                  |> mes("Save him.")
                  |> next()
                  |> mes("[Luik]")

                ctx
                |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), "...eh?..."))
                |> mes("Please look after Snorren...and Ogen.")
                |> mes("This Laphine, I mean Terra...")
                |> mes("She truly wanted to save Ogen...")
                |> next()
                |> mes("[Luik]")
                |> mes("I will talk to my superiors to try and settle this matter...")
                |> mes("Please save Ogen.")
                |> delitem(6085, 1)
                |> delitem(6084, 1)
                |> set_char_var(:ep13_mdrama, 23)
                |> changequest(7067, 7068)
                |> close()
              else
                ctx
                |> mes("[Luik]")
                |> mes("You should bring something that can prove it?")
                |> mes(
                  "... We have been fighting them for so long, it is hard for us to believe you."
                )
                |> next()
                |> mes("[Snorren]")
                |> mes("...Yes... regardless of anything, just to prove what you say is true.")
                |> close()
              end
            else
              if get_char_var(ctx, :ep13_mdrama, 0) == 23 do
                ctx |> mes("[Luik]") |> mes("Please... Help Ogen.") |> close()
              else
                ctx
                |> mes("[Luik]")
                |> mes("How did you get in here?")
                |> mes("You shouldn't be here.")
                |> close()
              end
            end
          end
        end
      end
    else
      ctx
      |> mes("[Luik]")
      |> mes("Na w ewe w")
      |> mes("Aewrf sd fsd iyu. ")
      |> mes("Ou uur?")
      |> next()
      |> mes("Looks like Luik is giving me a look of scorn.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end

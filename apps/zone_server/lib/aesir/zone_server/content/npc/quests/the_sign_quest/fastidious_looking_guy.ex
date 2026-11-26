defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.FastidiousLookingGuy do
  @moduledoc """
  Cyon guards his laboratory and studies the Sobbing Starlight.

  ## Behavior

  - Confronts intruders and requests worn pages to decipher the starlight.
  - Exchanges ten pages for an ancient document and advances the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "um_in",
        x: 27,
        y: 23,
        dir: 3,
        sprite: 121,
        name: "Fastidious-Looking Guy",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    cond do
      checkweight(ctx, [{908, 200}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second! Right now,")
        |> mes(
          "you have too many items in your inventory. Please come back after you've freed up more inventory space.^000000"
        )
        |> close()

      get_char_var(ctx, :sign_q, 0) < 74 ->
        ctx
        |> mes("^333333*Giggle*^000000")
        |> mes("So if I do this,")
        |> mes("then that and then...")
        |> mes("Ooh, these calculations")
        |> mes("are absolutely perfect!")
        |> emotion(:kik)
        |> next()
        |> mes("[Cyon]")
        |> mes("Wh-what?!")
        |> mes("Who are you?")
        |> mes("H-how did you get")
        |> mes("in here? I demand")
        |> mes("that you leave, right now!")
        |> emotion(:fret)
        |> close2()
        |> warp("umbala", 111, 121)

      get_char_var(ctx, :sign_q, 0) == 74 ->
        {ctx, choice} =
          ctx
          |> mes("[Cyon]")
          |> mes("^333333*Giggle*^000000")
          |> mes("So if I do this,")
          |> mes("then that and then...")
          |> mes("Ooh, these calculations")
          |> mes("are absolutely perfect!")
          |> emotion(:kik)
          |> next()
          |> mes("[Cyon]")
          |> mes("Wh-what?!")
          |> mes("Who are you?")
          |> mes("H-how did you get")
          |> mes("in here? I demand")
          |> mes("that you leave, right now!")
          |> emotion(:fret)
          |> next()
          |> select([
            "I'm here for Metz Brayde.",
            "My apologies.",
            "Would you look at this?",
            "..."
          ])

        case choice do
          1 ->
            ctx
            |> mes("[Cyon]")
            |> mes("Huh? Brayde?")
            |> mes("Do you expect me")
            |> mes("to just trust you without")
            |> mes("a single shred of proof that")
            |> mes("he sent you? Get out now!")
            |> close()

          2 ->
            ctx
            |> mes("[Cyon]")
            |> mes("If you're so sorry,")
            |> mes("then hurry up and get")
            |> mes("out of here! Not just anyone")
            |> mes("is allowed here! Leave!")
            |> emotion(:hng)
            |> close()

          3 ->
            ctx
            |> mes("[Cyon]")
            |> mes("What could be so")
            |> mes("special about what")
            |> mes("you've brought here?!")
            |> mes("Fine, you've piqued my")
            |> mes("scientific curiosity...")
            |> next()
            |> emotion(:huk)
            |> next()
            |> mes("[Cyon]")
            |> mes("Sweet lord...")
            |> mes("This is 'God's Tear Drop!'")
            |> mes("The Sobbling Starlight!")
            |> mes("He finally made it....")
            |> next()
            |> mes("[Cyon]")
            |> mes("^333333*Giggle*^000000")
            |> mes("Well, since he's kept his promise, I suppose that I should keep mine")
            |> mes(
              "as well. Now, within this Sobbing Starlight are these tiny letters... ^FFFFFFcobo^000000"
            )
            |> next()
            |> mes("[Cyon]")
            |> mes(
              "The text is so small that even Hunters skilled in Vulture's Eye are unable to read them. However, I've read that this Sobbing"
            )
            |> mes("Starlight will respond")
            |> mes("to really old papers...")
            |> next()
            |> mes("[Cyon]")
            |> mes("Now, if we want to figure out")
            |> mes("what's written in the Sobbing")
            |> mes("Starlight, we'd need at least")
            |> mes("10 ancient pieces of paper...")
            |> set_char_var(:sign_q, 75)
            |> close()

          4 ->
            ctx
            |> specialeffect(:venomdust)
            |> mes("[Cyon]")
            |> mes("Not listening, eh?")
            |> mes("Fine, if you don't")
            |> mes("understand words, then")
            |> mes("I'll have to use force!")
            |> mes("Get out here right now!")
            |> close2()
            |> percent_heal(hp: -30, sp: 0)
            |> specialeffect2(:magnumbreak)

          _ ->
            ctx
        end

      get_char_var(ctx, :sign_q, 0) == 75 ->
        ctx =
          ctx
          |> mes("[Cyon]")
          |> mes("You've come back.")
          |> mes("I hope you were able")
          |> mes("to find some ancient")
          |> mes("or really aged paper...")
          |> next()

        cond do
          count_item(ctx, 1097) > 9 ->
            ctx
            |> mes("[Cyon]")
            |> mes("How did you find these")
            |> mes("Worn Out Pages? This is great,")
            |> mes("I'm sure the Sobbing Starlight")
            |> mes("will respond to these!")
            |> next()
            |> mes("[Cyon]")
            |> mes("Yes. Yes...")
            |> mes("This should be enough.")
            |> mes("Now give them to me")
            |> mes("and wait here while")
            |> mes("I try a few things...")
            |> next()
            |> specialeffect(:sphere)
            |> next()
            |> mes("[Cyon]")
            |> mes("Just as I thought!")
            |> mes(
              "The Sobbing Starlight is responding to these Worn Out Pages! Excellent! I've finally fulfilled my promise to Metz! Now he can leave"
            )
            |> mes("me alone!")
            |> delitem(1097, 10)
            |> set_char_var(:sign_q, 76)
            |> give_item(7275, 1)
            |> close()

          count_item(ctx, 1097) > 0 ->
            ctx
            |> mes("[Cyon]")
            |> mes("How did you find these")
            |> mes("^FF0000Worn Out Pages^000000? This is great,")
            |> mes("I'm sure the Sobbing Starlight")
            |> mes("will respond to these!")
            |> next()
            |> mes("[Cyon]")
            |> mes("Wait, we don't have enough")
            |> mes("of them to make the Sobbing")
            |> mes("Starlight respond. Find more")
            |> mes("of these papers and bring")
            |> mes("them all to me!")
            |> close()

          true ->
            ctx
            |> mes("[Cyon]")
            |> mes("You haven't found anything?")
            |> mes("What kind of scientist are you?")
            |> mes(
              "Now go out and find some old and ancient papers so that we can learn what's written in the Sobbing Starlight! Go!"
            )
            |> next()
            |> mes("[Cyon]")
            |> mes("...?")
            |> mes("Why are you still here?")
            |> mes("Leave and do what I told")
            |> mes("you to do, alright?! Don't")
            |> mes("make me get violent...")
            |> next()
            |> percent_heal(hp: -30, sp: 0)
            |> specialeffect2(:magnumbreak)
            |> next()
            |> warp("umbala", 111, 121)
        end

      get_char_var(ctx, :sign_q, 0) == 76 ->
        ctx
        |> mes("[Cyon]")
        |> mes(
          "My business with you is finished, so you go along on your way now. And tell Metz not to bother me anymore! I'm done doing favors!"
        )
        |> close()

      true ->
        ctx
        |> mes("[Cyon]")
        |> mes("How dare you intrude")
        |> mes("on my property?! Now,")
        |> mes("get out now before I get")
        |> mes("violent! Didn't you hear me?")
        |> mes("GET OUT OF HERE!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end

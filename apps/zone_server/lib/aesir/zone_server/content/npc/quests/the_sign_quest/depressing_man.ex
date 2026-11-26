defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.DepressingMan do
  @moduledoc """
  Gen guides adventurers through the Niflheim portion of the Sign quest.

  ## Behavior

  - Offers quest guidance and transports eligible adventurers to Lady Hell.

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
        map: "niflheim",
        x: 146,
        y: 241,
        dir: 0,
        sprite: 735,
        name: "Depressing Man",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    cond do
      get_char_var(ctx, :sign_q, 0) < 80 ->
        ctx
        |> mes("[????]")
        |> mes("Leave me be,")
        |> mes("ruffian! I'm disinclined")
        |> mes("towards conversation")
        |> mes("at the moment.")
        |> close()

      get_char_var(ctx, :sign_q, 0) < 87 ->
        ctx
        |> mes("[????]")
        |> mes("Don't go judging")
        |> mes("people based on just")
        |> mes("how they look. Try to look")
        |> mes("inside and find the truth")
        |> mes("within their hearts.")
        |> close()

      get_char_var(ctx, :sign_q, 0) == 87 ->
        if count_item(ctx, 2642) > 1 do
          {ctx, choice} =
            ctx
            |> mes("[Gen]")
            |> mes("You lookin' for")
            |> mes("something? Crayu")
            |> mes("must have sent you.")
            |> mes("Alright then, let's get")
            |> mes("straight to the point.")
            |> next()
            |> mes("[Gen]")
            |> mes("So, why is it that you")
            |> mes("wanna become one")
            |> mes("of Valkyrie's chosen?")
            |> next()
            |> select(["To prove my courage", "For honor", "To help people"])

          ctx =
            case choice do
              1 ->
                if get_char_var(ctx, :sign_sq, 0) > 2 do
                  set_char_var(ctx, :sign_sq, 0)
                else
                  set_char_var(ctx, :sign_sq, get_char_var(ctx, :sign_sq, 0) + 1)
                end

              2 ->
                ctx

              _ ->
                ctx
            end

          {ctx, answer} =
            ctx
            |> mes("[Gen]")
            |> mes("Alright...")
            |> mes("Now, did Crayu")
            |> mes("tell you why I'm here?")
            |> next()
            |> select(["Yes", "No"])

          case answer do
            1 ->
              ctx
              |> mes("[Gen]")
              |> mes("Good, then you")
              |> mes("already know what")
              |> mes("you need to do. Now go")
              |> mes("see the witch of Niflheim.")
              |> next()
              |> mes("[Gen]")
              |> mes("And, off the record,")
              |> mes("I think you should be")
              |> mes("really careful if you find")
              |> mes("yourself dealing with Serin...")
              |> set_char_var(:sign_q, 88)
              |> close()

            2 ->
              ctx
              |> mes("[Gen]")
              |> mes("You know, I was an")
              |> mes("adventurer myself. In fact,")
              |> mes("I even came here to Niflheim")
              |> mes(
                "for the ordeals set by the gods. However, I failed and ended up being bound to this realm..."
              )
              |> next()
              |> mes("[Gen]")
              |> mes("I just wanted to warn you.")
              |> mes("Be careful and don't justify")
              |> mes(
                "your greed for any sort of reward using the excuse that you're just gonna prove your courage."
              )
              |> mes("That's what I did...")
              |> next()
              |> mes("[Gen]")
              |> mes("Anyway, I've already talked")
              |> mes("too much. First, go and see")
              |> mes("the witch and ask her to")
              |> mes("help you out, okay?")
              |> next()
              |> mes("[Gen]")
              |> mes("One last thing. Off the")
              |> mes("record, I think you should")
              |> mes("be really careful if you find")
              |> mes("yourself dealing with Serin.")
              |> mes("She seems nice enough, but")
              |> mes("something's weird about her.")
              |> next()
              |> mes("[Gen]")
              |> mes("She's awfully persuasive,")
              |> mes("and the fact that she used")
              |> mes("to be a great wizard when she")
              |> mes(
                "was alive bothers me. She's a lot different than the rest of the guys stuck in Niflheim..."
              )
              |> set_char_var(:sign_q, 88)
              |> close()

            _ ->
              ctx
          end
        else
          ctx
          |> mes("[Gen]")
          |> mes("Are you here")
          |> mes("to prove your")
          |> mes("courage to the gods?")
          |> next()
          |> mes("[Gen]")
          |> mes("You know, I was an")
          |> mes("adventurer myself. In fact,")
          |> mes("I even came here to Niflheim")
          |> mes(
            "for the ordeals set by the gods. However, I failed and ended up being bound to this realm..."
          )
          |> next()
          |> mes("[Gen]")
          |> mes("I just wanted to warn you.")
          |> mes("Be careful and don't justify")
          |> mes(
            "your greed for any sort of reward using the excuse that you're just gonna prove your courage."
          )
          |> mes("That's what I did...")
          |> next()
          |> mes("[Gen]")
          |> mes("Anyway, I've already talked")
          |> mes("too much. First, go and see")
          |> mes("the witch and ask her to")
          |> mes("help you out, okay?")
          |> set_char_var(:sign_q, 88)
          |> close()
        end

      get_char_var(ctx, :sign_q, 0) < 117 ->
        ctx
        |> mes("[Gen]")
        |> mes("Huh... I hear you're")
        |> mes("looking for something")
        |> mes("pretty important. It's going")
        |> mes("to be a dangerous search.")
        |> next()
        |> mes("[Gen]")
        |> mes("They are plenty of")
        |> mes("other parties that are")
        |> mes("interested in the thing")
        |> mes("which you're seeking...")
        |> close()

      get_char_var(ctx, :sign_q, 0) == 117 ->
        {ctx, response} =
          ctx
          |> mes("[Gen]")
          |> mes("You must be a very")
          |> mes("resourceful mortal.")
          |> mes("Not even Lady Hell, with")
          |> mes("all her power, could find")
          |> mes("the soul of her mother")
          |> mes("for a long time.")
          |> next()
          |> mes("[Gen]")
          |> mes("There's no need")
          |> mes("for me to hide my")
          |> mes("true identity any longer.")
          |> mes("My real name is Ganglati,")
          |> mes("servant of Lady Hell, the")
          |> mes("ruler of Niflheim.")
          |> next()
          |> mes("[Gen]")
          |> mes("Her highness would")
          |> mes("have words with you.")
          |> mes("Shall I send you to her")
          |> mes("mansion, Eljudnir,")
          |> mes("right now?")
          |> next()
          |> select(["Yes", "No"])

        case response do
          1 ->
            ctx
            |> mes("[Gen]")
            |> mes("Remember to be")
            |> mes("careful and especially")
            |> mes("polite when you speak to")
            |> mes("Lady Hell. Otherwise, the")
            |> mes("consequences will be severe...")
            |> close2()
            |> warp("que_sign01", 45, 20)

          2 ->
            ctx
            |> mes("[Gen]")
            |> mes("I understand.")
            |> mes("Meeting with a deity is")
            |> mes("no small matter. However,")
            |> mes("I advise you to make haste")
            |> mes("as her highness is eager")
            |> mes("to see you soon.")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :sign_q, 0) == 118 ->
        ctx
        |> mes("[Gen]")
        |> mes("You must be most favored")
        |> mes("to receive the Symbol of the")
        |> mes("Nine Realms. Of course, it")
        |> mes("can be used only once, but")
        |> mes("it is still a great honor.")
        |> next()
        |> mes("[Gen]")
        |> mes("Once again, I ask that")
        |> mes("you be on guard against")
        |> mes("Serin. She may already be")
        |> mes("aware of what you plan to")
        |> mes("do with this symbol...")
        |> close()

      get_char_var(ctx, :sign_q, 0) < 129 ->
        ctx
        |> mes("[Gen]")
        |> mes("You must hurry and")
        |> mes("stop the summoning")
        |> mes("before your world in")
        |> mes("cast into immense peril!")
        |> next()
        |> mes("[Gen]")
        |> mes("Although Lady Hell")
        |> mes("is being rather blase")
        |> mes("about this matter, I beseech")
        |> mes("you to do what you can for")
        |> mes("the realm of the living!")
        |> close()

      get_char_var(ctx, :sign_q, 0) > 200 ->
        ctx
        |> mes("[Gen]")
        |> mes("I should have")
        |> mes("known you couldn't")
        |> mes("stop her. Still, I had")
        |> mes("a little hope that you'd")
        |> mes("be able to do it.")
        |> next()
        |> mes("[Gen]")
        |> mes("Perhaps I expected")
        |> mes("far too much of you.")
        |> mes("Goodbye for now, mortal.")
        |> close()

      true ->
        {ctx, final_choice} =
          ctx
          |> mes("[Gen]")
          |> mes("You've done a great")
          |> mes("job of stopping Serin.")
          |> mes("Excellent! Such great")
          |> mes("service on behalf of")
          |> mes("the realm of the living!")
          |> next()
          |> mes("[Gen]")
          |> mes("I'm pleased to inform")
          |> mes("you that you've been")
          |> mes("invited to Lady Hell's")
          |> mes("mansion once again.")
          |> mes("Are you ready to go?")
          |> next()
          |> select(["No, thanks.", "Yes."])

        case final_choice do
          1 ->
            ctx
            |> mes("[Gen]")
            |> mes("I see.")
            |> mes("Well then, come")
            |> mes("back to me when you")
            |> mes("feel fully prepared.")
            |> close()

          2 ->
            ctx
            |> mes("[Gen]")
            |> mes("Good, good.")
            |> mes("Don't forget to")
            |> mes("speak to her highness")
            |> mes("with the utmost respect!")
            |> close2()
            |> warp("que_sign01", 45, 20)

          _ ->
            ctx
        end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end

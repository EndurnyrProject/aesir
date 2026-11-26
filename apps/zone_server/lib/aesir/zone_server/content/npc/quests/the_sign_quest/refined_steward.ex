defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.RefinedSteward do
  @moduledoc """
  Mahatra oversees errands for the Alchesh family.

  ## Behavior

  - Entrusts the adventurer with a delivery and receives its receipt.
  - Directs the adventurer to help Seylin and reports their progress.

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
        map: "alberta_in",
        x: 114,
        y: 178,
        dir: 5,
        sprite: 109,
        name: "Refined Steward",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Mahatra]")

    cond do
      get_char_var(ctx, :sign_q, 0) < 37 ->
        ctx
        |> mes("Welcome to the")
        |> mes("Alchesh Estate.")
        |> mes("The Alcheshs are the")
        |> mes("most esteemed family")
        |> mes("in all of Alberta.")
        |> next()
        |> mes("[Mahatra]")
        |> mes("I am Mahatra Mornen,")
        |> mes("steward of this family.")
        |> mes("Feel free to ask me if")
        |> mes("you need anything and")
        |> mes("I shall do my best")
        |> mes("to assist you.")
        |> close()

      get_char_var(ctx, :sign_q, 0) == 37 ->
        ctx =
          ctx
          |> mes("Ah yes, the master informed")
          |> mes("me that you would be taking")
          |> mes("care of an urgent delivery for")
          |> mes("him. Please take this to a")
          |> mes("man named ^3355FFLeibech^000000.")
          |> next()
          |> mes("[Mahatra]")
          |> mes("It may be difficult")
          |> mes("to find him since he")
          |> mes("travels around the world.")
          |> mes("Ah yes, I have heard that")
          |> mes("he was in some other country...")
          |> next()
          |> mes("[Mahatra]")
          |> mes("Now, the item I am")
          |> mes("about to give you is")
          |> mes("one of a kind. Don't lose")
          |> mes("it or you will fall out of favor with the master...")
          |> next()
          |> mes("^3355FFMahatra gives you")
          |> mes("a unique stone that has")
          |> mes("your name attached to it.^000000")
          |> set_char_var(:sign_q, 38)

        ctx |> get_named_item(7049, char_name(ctx, 0)) |> close()

      get_char_var(ctx, :sign_q, 0) == 38 or
          (get_char_var(ctx, :sign_q, 0) == 39 and count_item(ctx, 7181) < 1) ->
        ctx
        |> mes("You haven't delivered")
        |> mes("the Stone yet? Please take")
        |> mes("good care of it since it's very")
        |> mes("rare. Don't use it or lose it.")
        |> mes("before it's delivered!")
        |> mes("Take care, now...")
        |> close()

      get_char_var(ctx, :sign_q, 0) == 39 ->
        ctx
        |> mes("Ah, you've returned.")
        |> mes("And I see you already")
        |> mes("delivered the Stone. Great,")
        |> mes("well done. Let me send a")
        |> mes("message to the master, so")
        |> mes("please visit him later.")
        |> delitem(7181, 1)
        |> set_char_var(:sign_q, 40)
        |> close()

      get_char_var(ctx, :sign_q, 0) == 40 ->
        ctx
        |> mes("Thank you very")
        |> mes("much for the trouble")
        |> mes("you've gone through")
        |> mes("on our behalf.")
        |> close()

      get_char_var(ctx, :sign_q, 0) == 41 ->
        {ctx, choice} =
          ctx
          |> mes("Greetings. Hm?")
          |> mes("Did the master ask")
          |> mes("you to perform another")
          |> mes("task for him already?")
          |> next()
          |> select(["No.", "You have another assignment for me."])

        case choice do
          1 ->
            ctx
            |> mes("[Mahatra]")
            |> mes("Very well.")
            |> mes("Then we shall")
            |> mes("converse later~")
            |> close()

          2 ->
            ctx
            |> mes("[Mahatra]")
            |> mes("I... I do...?")
            |> mes("The master didn't")
            |> mes("leave me any instructions.")
            |> mes("Hmmm. Oh, I know what you can")
            |> mes(
              "do! Why don't you help ^FF0000Seylin^000000? She seems bothered by something..."
            )
            |> set_char_var(:sign_q, 42)
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :sign_q, 0) < 51 ->
        ctx
        |> mes("Although you may only")
        |> mes("be doing it for the Sobbing")
        |> mes("Starlight, I really appreciate")
        |> mes("all your help. Seylin's a very")
        |> mes("nice girl and doesn't deserve")
        |> mes("to feel down...")
        |> close()

      get_char_var(ctx, :sign_q, 0) == 51 ->
        ctx
        |> mes("Yes.")
        |> mes("I heard from Seylin.")
        |> mes("I did not know she was worried about her brother.")
        |> mes("Ahem ahem...")
        |> mes("Thank you for helping her.")
        |> mes("I will send a message to my master.")
        |> next()
        |> mes("Mahatra]")
        |> mes("If there is anything else, he will let you pass the test.")
        |> mes("Good luck.")
        |> set_char_var(:sign_q, 52)
        |> close()

      get_char_var(ctx, :sign_q, 0) == 98 ->
        ctx
        |> mes("I'm very disappointed")
        |> mes("in you. We put our trust")
        |> mes("in you and you really")
        |> mes("let us down.")
        |> next()
        |> mes("[Mahatra]")
        |> mes("Well, I suppose")
        |> mes("that's the nature")
        |> mes("of the testing. They're")
        |> mes("designed so that only")
        |> mes("the best of the best")
        |> mes("can pass them.")
        |> close()

      true ->
        ctx
        |> mes("I hope the master listens")
        |> mes("to me and dresses more like")
        |> mes("a man in his position. Even if")
        |> mes("he thinks he's just a merchant,")
        |> mes("he's the master of this estate!")
        |> mes("But please don't tell him that~")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end

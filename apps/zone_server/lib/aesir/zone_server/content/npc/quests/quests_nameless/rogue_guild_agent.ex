defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.RogueGuildAgent do
  @moduledoc """
  A Rogue Guild agent investigates rumors of monsters escaping Geffen Tower.

  ## Behavior

  - Requests monster drops and directs the player to the agent in Payon.

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
      %{
        map: "geffen",
        x: 91,
        y: 36,
        dir: 5,
        sprite: 828,
        name: "Rogue Guild Agent",
        scope: :shared,
        unique_name: "Rogue Guild Agent#nd1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rumour_nd, 0) < 4 ->
        if get_char_var(ctx, :zdan_edq, 0) > 12 do
          ctx
          |> mes("[Rogue Guild Agent]")
          |> mes("Are you the one that's")
          |> mes("been helping to take")
          |> mes("down the Z Gang? Nice!")
          |> close()
        else
          ctx
          |> mes("[Rogue Guild Agent]")
          |> mes("If you got nothing")
          |> mes("to do with me, then...")
          |> mes("I got nothing to do")
          |> mes("with you. Later!")
          |> close()
        end

      get_char_var(ctx, :rumour_nd, 0) == 4 ->
        if get_char_var(ctx, :zdan_edq, 0) > 12 do
          ctx
          |> mes("[Rogue Guild Agent]")
          |> mes("This is from the")
          |> mes("Al De Baran agent?")
          |> mes("Thanks! It musta been")
          |> mes("kinda hard to find me, eh?")
          |> next()
          |> mes("[Rogue Guild Agent]")
          |> mes("The Z Gang's been")
          |> mes("spreading rumors about")
          |> mes("ghosts pouring out of")
          |> mes("Geffen Tower. Just to be")
          |> mes("sure, I want you to check")
          |> mes("it out. Will you do that?")
          |> next()
          |> request_evidence(5)
        else
          ctx
          |> mes("[Rogue Guild Agent]")
          |> mes("This report is from the")
          |> mes("Rogue agent in Al De Baran?")
          |> mes("Hey, this says that this is")
          |> mes("for the Rogue Guild. You")
          |> mes("better take this over there.")
          |> close()
        end

      get_char_var(ctx, :rumour_nd, 0) == 5 ->
        {ctx, choice} =
          ctx
          |> mes("[Rogue Guild Agent]")
          |> mes("Hey, you done hunting")
          |> mes("down the monsters in")
          |> mes("Geffen Tower yet?")
          |> mes("I hope you brought")
          |> mes("the stuff...")
          |> next()
          |> select(["Give Items", "I forgot what you need."])

        case choice do
          1 ->
            if count_item(ctx, 1062) > 0 and count_item(ctx, 944) > 0 and
                 count_item(ctx, 1038) > 0 and count_item(ctx, 1060) > 0 and
                 count_item(ctx, 1059) > 0 do
              ctx
              |> delitem(1062, 1)
              |> delitem(944, 1)
              |> delitem(1038, 1)
              |> delitem(1060, 1)
              |> delitem(1059, 1)
              |> set_char_var(:rumour_nd, 6)
              |> thank_for_items()
            else
              missing_items(ctx)
            end

          2 ->
            ctx
            |> mes("[Agent]")
            |> mes("^FF00001 Fabric^000000,")
            |> mes("^FF00001 Golden Hair^000000,")
            |> mes("^FF00001 Little Evil Horn^000000,")
            |> mes("^FF00001 Horseshoe^000000, and")
            |> mes("^FF00001 Jack O' Pumpkin^000000.")
            |> mes("Don't forget this time!")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :rumour_nd, 0) == 6 ->
        ctx
        |> mes("[Agent]")
        |> mes("Would you deliver")
        |> mes("my report over to")
        |> mes("the Rogue agent")
        |> mes("in Payon? Thanks.")
        |> close()

      get_char_var(ctx, :rumour_nd, 0) == 25 ->
        ctx =
          ctx
          |> mes("[Agent]")
          |> mes("Hey, the guild sent")
          |> mes("you over to see me?")
          |> mes("Oh, hey, you brought")
          |> mes("me a message. Let's")
          |> mes("take a look-see~")
          |> next()
          |> mes("[Agent]")
          |> mes("Umm...")
          |> next()

        if get_char_var(ctx, :zdan_edq, 0) > 12 do
          ctx
          |> mes("[Agent]")
          |> mes("So... The Z Gang's")
          |> mes("responsible for those")
          |> mes("rumors about the ghosts")
          |> mes("running loose in Geffen.")
          |> mes("Huh. Those rascally guys.")
          |> mes("Okay, this is what we do.")
          |> next()
          |> request_evidence(5)
        else
          ctx
          |> mes("[Rogue Guild Agent]")
          |> mes("The Z Gang's been")
          |> mes("spreading rumors about")
          |> mes("ghosts pouring out of")
          |> mes("Geffen Tower. Just to be")
          |> mes("sure, I want you to check")
          |> mes("it out. Will you do that?")
          |> next()
          |> request_evidence(26)
        end

      get_char_var(ctx, :rumour_nd, 0) == 26 ->
        if get_char_var(ctx, :zdan_edq, 0) > 12 do
          {ctx, choice} =
            ctx
            |> mes("[Agent]")
            |> mes("Hey, while you were")
            |> mes("gone, I heard the Z Gang")
            |> mes("was finally captured.")
            |> mes("Big relief to hear it.")
            |> next()
            |> mes("[Agent]")
            |> mes("But I still want to")
            |> mes("reassure the people in")
            |> mes("Geffen that the monsters")
            |> mes("in Geffen Tower are safely")
            |> mes("locked up inside. You")
            |> mes("bring the stuff?")
            |> next()
            |> select(["Give Items", "I forgot what you need."])

          case choice do
            1 ->
              if count_item(ctx, 1062) > 1 and count_item(ctx, 944) > 2 and
                   count_item(ctx, 1038) > 1 and count_item(ctx, 1060) > 2 and
                   count_item(ctx, 1059) > 0 do
                ctx
                |> delitem(1062, 2)
                |> delitem(944, 3)
                |> delitem(1038, 2)
                |> delitem(1060, 3)
                |> delitem(1059, 1)
                |> set_char_var(:rumour_nd, 6)
                |> thank_for_items()
              else
                missing_items(ctx)
              end

            2 ->
              ctx
              |> mes("[Rogue Guild Agent]")
              |> mes("^FF00001 Fabric^000000,")
              |> mes("^FF00001 Golden Hair^000000,")
              |> mes("^FF00001 Little Evil Horn^000000,")
              |> mes("^FF00001 Horseshoe^000000, and")
              |> mes("^FF00001 Jack O' Pumpkin^000000.")
              |> mes("Don't forget this time!")
              |> close()

            _ ->
              ctx
          end
        else
          {ctx, choice} =
            ctx
            |> mes("[Agent]")
            |> mes("I asked you to bring")
            |> mes("me items that prove that")
            |> mes("the monsters in Geffen")
            |> mes("Tower are safely locked")
            |> mes("up in there. You do that yet?")
            |> next()
            |> select(["Give Items", "I forgot what you need."])

          case choice do
            1 ->
              if count_item(ctx, 1062) > 1 and count_item(ctx, 944) > 2 and
                   count_item(ctx, 1038) > 1 and count_item(ctx, 1060) > 2 and
                   count_item(ctx, 1059) > 0 do
                ctx
                |> delitem(1062, 2)
                |> delitem(944, 3)
                |> delitem(1038, 2)
                |> delitem(1060, 3)
                |> delitem(1059, 1)
                |> set_char_var(:rumour_nd, 6)
                |> thank_for_items()
              else
                missing_items(ctx)
              end

            2 ->
              ctx
              |> mes("[Agent]")
              |> mes("^FF00001 Fabric^000000,")
              |> mes("^FF00001 Golden Hair^000000,")
              |> mes("^FF00001 Little Evil Horn^000000,")
              |> mes("^FF00001 Horseshoe^000000, and")
              |> mes("^FF00001 Jack O' Pumpkin^000000.")
              |> mes("Don't forget this time!")

            _ ->
              ctx
          end
        end

      get_char_var(ctx, :rumour_nd, 0) == 22 ->
        ctx =
          if get_char_var(ctx, :zdan_edq, 0) > 12 do
            ctx
            |> mes("[Agent]")
            |> mes("Looks like there'll")
            |> mes("be some peace and quiet")
            |> mes("with the Z Gang all locked up.")
            |> mes("Those guys were a double")
            |> mes("heaping of trouble if")
            |> mes("you ask me. Huh.")
          else
            ctx
            |> mes("[Agent]")
            |> mes("Keep up the good work!")
            |> mes("With guys like you on")
            |> mes("our side, the Z Gang'll")
            |> mes("caught sooner than later.")
          end

        close(ctx)

      true ->
        ctx |> mes("[Agent]") |> mes("So busy!") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp thank_for_items(ctx) do
    ctx
    |> mes("[Agent]")
    |> mes("Thanks. This stuff")
    |> mes("should help the people")
    |> mes("in Geffen calm down a bit.")
    |> mes("The Z Gang's been doin'")
    |> mes("all these things to make them")
    |> mes("believe the monsters are loose.")
    |> next()
    |> mes("[Agent]")
    |> mes("They've been leavin'")
    |> mes("horseprints that look like")
    |> mes("they belong to Nightmares,")
    |> mes("dressing up in Fabric and")
    |> mes("pretending they're Whispers...")
    |> mes("They're freakin' hooligans.")
    |> next()
    |> mes("[Agent]")
    |> mes("I think the Rogue agent")
    |> mes("in Payon should know about")
    |> mes("all this. Take this report")
    |> mes("over to him, will you?")
    |> mes("Thanks a bundle, pal.")
    |> close()
  end

  defp missing_items(ctx) do
    ctx
    |> mes("[Agent]")
    |> mes("Hold on, you're")
    |> mes("missing some stuff.")
    |> mes("You mind checking if")
    |> mes("you left some of it")
    |> mes("behind somewhere?")
    |> close()
  end

  defp request_evidence(ctx, stage) do
    ctx
    |> mes("[Rogue Guild Agent]")
    |> mes("I want you to capture")
    |> mes("some monsters, and get")
    |> mes("some proof that shows that")
    |> mes("the ghosts stay inside the")
    |> mes("tower, and they're not")
    |> mes("coming out. Yeah, bring...")
    |> next()
    |> mes("[Rogue Guild Agent]")
    |> mes("^FF00001 Fabric^000000,")
    |> mes("^FF00001 Golden Hair^000000,")
    |> mes("^FF00001 Little Evil Horn^000000,")
    |> mes("^FF00001 Horseshoe^000000, and")
    |> mes("^FF00001 Jack O' Pumpkin^000000.")
    |> mes("That oughta do it.")
    |> next()
    |> mes("[Rogue Guild Agent]")
    |> mes("We just need to get")
    |> mes("a little concrete proof")
    |> mes("so that the people can")
    |> mes("calm down, and not panick.")
    |> mes("Hurry it up before a riot")
    |> mes("breaks out or somethin'.")
    |> set_char_var(:rumour_nd, stage)
    |> close()
  end
end

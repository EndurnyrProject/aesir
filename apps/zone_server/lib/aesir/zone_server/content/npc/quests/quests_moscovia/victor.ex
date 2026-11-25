defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Victor do
  @moduledoc """
  Victor helps with the search for Mikhail and makes adhesive.

  ## Behavior

  - Shares information about Mikhail and crafts adhesive from gathered materials.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_in",
        x: 147,
        y: 202,
        dir: 3,
        sprite: 968,
        name: "Victor",
        scope: :shared,
        unique_name: "Victor#mos"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 2000 do
      ctx
      |> mes("- Please stop here!! -")
      |> mes("- You're carrying too many items -")
      |> mes("- Please try again -")
      |> mes("- after using the kafra service -")
      |> close()
    else
      speak(ctx, get_char_var(ctx, :mos_swan, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp speak(ctx, 8) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Excuse me.")
    |> mes("Could you spare a few minutes for me?")
    |> next()
    |> mes("[Victor]")
    |> mes("Who are you?")
    |> mes("What gives you the right to say such a thing?")
    |> mes("I'm busy appreciating wine in this glass.")
    |> close()
  end

  defp speak(ctx, 9) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Excuse me.")
      |> mes("Could you spare a few minutes for me?")
      |> next()
      |> mes("[Victor]")
      |> mes("Who are you?")
      |> mes("What gives you the right to say such a thing?")
      |> mes("I'm busy appreciating wine in this glass.")
      |> next()
      |> mes("[Victor]")
      |> mes("Pardon? You're drinking too.")
      |> mes("Ok, it's lonely to drink alone. I but I've gotten used to it.")
      |> next()
      |> mes("[Victor]")
      |> mes("Well, tell me what you have on your mind. I'm listening.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Have you seen a little boy who was looking for paste?")
      |> next()
      |> mes("[Victor]")
      |> mes("..................")
      |> next()
      |> mes("[Victor]")
      |> mes("You're talking about Mikhail?")
      |> mes("He's such a sentimental boy. I was troubled by him")
      |> next()
      |> mes("[Victor]")
      |> mes("By the way, how did you know that he came to see me? Did he say anything to you?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "Mikhail hasn't come back yet since he left to get the paste. He broke his mother's Matrushka.."
      )
      |> next()
      |> mes("[Victor]")
      |> mes("............What?")
      |> mes("Hmm.. Oh dear.....")
      |> mes("I doubt he went there.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("There?")
    |> next()
    |> mes("[Victor]")
    |> mes("Yes. Baba Yaga 'The Terrible' and other scary animals live there.")
    |> next()
    |> mes("[Victor]")
    |> mes("The little boy came here crying a few hours ago.")
    |> mes(
      "He's got something that needs to be stuck together, so he needed a high-strength adhesive."
    )
    |> next()
    |> mes("[Victor]")
    |> mes("But I don't carry such a thing. So I told him to bring me some stuff for it.")
    |> next()
    |> mes("[Victor]")
    |> mes(
      "To get the stuff for a high-strength adhesive, you need to go to an isolated swamp. You can reach it by boat and it takes a long time."
    )
    |> next()
    |> mes("[Victor]")
    |> mes(
      "But the way to the swamp is very dangerous. There are horrible monsters around it, all hunting with eager eyes."
    )
    |> next()
    |> mes("[Victor]")
    |> mes(
      "Especially, the old lady Baba Yaga who attacks anyone she sees. She especially likes youngsters like you. haha!"
    )
    |> mes("heeheehee!!")
    |> next()
    |> mes("[Victor]")
    |> mes("...You turned pale! hahaha!!")
    |> next()
    |> mes("[Victor]")
    |> mes("But...")
    |> mes("I'm exaggerating a little, it's true that there are scary things.")
    |> mes(
      "But, I don't believe that a little and timid boy like Mikhail would go there. It's impossible!"
    )
    |> next()
    |> mes("[Victor]")
    |> mes("I said to him, 'you can never, ever go there' and told him to go back home.")
    |> mes("He asked for the impossible so I calmed him down with some bread.")
    |> next()
    |> mes("[Victor]")
    |> mes(
      "He was already white with fear that he broke his mother's matrushka. Do you think that he would go there?"
    )
    |> next()
    |> mes("[Victor]")
    |> mes("He might've just hidden himself somewhere, haha!")
    |> set_char_var(:mos_swan, 10)
    |> changequest(18062, 18063)
    |> close()
  end

  defp speak(ctx, stage) when stage in [10, 11] do
    ctx
    |> mes("[Victor]")
    |> mes(
      "There's a large island near Moscovia. It takes so much time to reach there by a boat. So nobody wants to go there. "
    )
    |> next()
    |> mes("[Victor]")
    |> mes("If you go deep into its forest, you can find a swamp where sticky weeds are growing.")
    |> next()
    |> mes("[Victor]")
    |> mes(
      "The way to go there is full of danger. Do think that a timid boy like Mikhail can go there?"
    )
    |> close()
  end

  defp speak(ctx, 12) do
    ctx =
      ctx
      |> mes("[Victor]")
      |> mes("You came back. Hmm, are you about to make me responsible that he's gone?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("No, I found him. You don't have to worry.")
      |> next()
      |> mes("[Victor]")
      |> mes("So, what do you want with me?")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I promised him I'd make the high-strength adhesive. What do I have to do for that?")
    |> next()
    |> mes("[Victor]")
    |> mes("Why are you so eager to make it? How important is the stuff?")
    |> mes("Well, I don't care...")
    |> next()
    |> mes("[Victor]")
    |> mes(
      "There's a large island near Moscovia. It takes so much time to reach there by a boat. So nobody wants to go there."
    )
    |> next()
    |> mes("[Victor]")
    |> mes("If you go deep into its forest, you can find a swamp where sticky weeds are growing.")
    |> next()
    |> mes("[Victor]")
    |> mes(
      "You should bring ^3131FF'10 sticky herbs'^000000 and ^3131FF 1 medicine bowl^000000 to me."
    )
    |> set_char_var(:mos_swan, 13)
    |> changequest(18065, 18066)
    |> close()
  end

  defp speak(ctx, stage) when stage > 12 and stage < 23 do
    ctx
    |> mes("[Victor]")
    |> mes("If you want to make adhesives")
    |> mes("get 10 sticky herbs and")
    |> mes("1 medicine bowl for me.")
    |> mes(
      "Those sticky herbs are growing in the swamp. It may be dangerous but that shouldn't be a problem for you?"
    )
    |> close()
  end

  defp speak(ctx, 23) do
    ctx =
      ctx
      |> mes("[Victor]")
      |> mes("What do you want with me this time??")
      |> mes("Oh, you said you wanted an adhesive...")
      |> mes("You're bothering me so much!")
      |> next()

    if count_item(ctx, 7763) > 9 and Rathena.truthy?(count_item(ctx, 7134)) do
      make_adhesive(ctx)
    else
      missing_materials(ctx)
    end
  end

  defp speak(ctx, _stage) do
    ctx |> mes("[Victor]") |> mes("What did you say? I just want to drink peacefully!") |> close()
  end

  defp make_adhesive(ctx) do
    ctx
    |> mes("[Victor]")
    |> mes("Give me the stuff! I'll make it quickly. You're annoying me!")
    |> next()
    |> set_local(:i, 0)
    |> crunch_herbs()
    |> next()
    |> set_local(:i, 0)
    |> rub_herbs()
    |> next()
    |> mes("[Victor]")
    |> mes("Ok, done!")
    |> mes("I don't want you to bother me any longer!")
    |> mes("Please leave!")
    |> delitem(7763, 10)
    |> delitem(7134, 1)
    |> set_char_var(:mos_swan, 24)
    |> give_item(7764, 1)
    |> changequest(18067, 18068)
    |> close()
  end

  defp missing_materials(ctx) do
    ctx
    |> mes("[Victor]")
    |> mes("He's annoying me so much. Give me the materials!")
    |> mes("Oh dear? What are those things? I said 10 sticky herbs and 1 medicine bowl!!")
    |> next()
    |> mes("[Victor]")
    |> mes("Even though I'm always in the pub, I have my own business... !")
    |> next()
    |> mes("[Victor]")
    |> mes(".............!!!!")
    |> next()
    |> mes("[Victor]")
    |> mes("..................")
    |> mes("What are you staring at? Bring them to me right now!")
    |> close()
  end

  defp crunch_herbs(ctx) do
    if get_local(ctx, :i, 0) < 3 do
      ctx = mes(ctx, "- He's making adhesive with a crunching sound -")
      ctx |> set_local(:i, get_local(ctx, :i, 0) + 1) |> crunch_herbs()
    else
      ctx
    end
  end

  defp rub_herbs(ctx) do
    if get_local(ctx, :i, 0) < 4 do
      ctx = mes(ctx, "- And he may be rubbing something -")
      ctx |> set_local(:i, get_local(ctx, :i, 0) + 1) |> rub_herbs()
    else
      ctx
    end
  end
end

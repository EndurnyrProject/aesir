defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.DazedBoy do
  @moduledoc """
  A boy and his mother reveal clues about the Geoborg family curse.

  ## Behavior

  - The conversation changes as the investigation progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
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
        map: "mjolnir_01",
        x: 313,
        y: 269,
        dir: 5,
        sprite: 706,
        name: "Dazed Boy",
        scope: :shared,
        unique_name: "Dazed Boy#prt"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :prt_curse, 0) do
      11 -> hear_song(ctx)
      36 -> weary_boy(ctx)
      45 -> smiling_boy(ctx)
      stage when stage > 54 -> warm_smile(ctx)
      _ -> wary_boy(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp hear_song(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Absent-Minded Boy]")
      |> mes("The great serpent")
      |> mes("swallowed the sea.")
      |> mes("The eagle of the rainbow")
      |> mes("swallowed the serpent.")
      |> mes("Then snake scales grew on")
      |> mes("the eagle, and it slowly died.")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("Goodness...!")
      |> mes("Will you please stop")
      |> mes("singing that song?")
      |> next()
      |> mes("[Absent-Minded Boy]")
      |> mes("..................")
      |> next()
      |> mes("^3355FFThe little boy quietly")
      |> mes("stared at the woman for a")
      |> mes("little bit, and then crouched")
      |> mes("down and began petting a")
      |> mes("dog sitting next to him.^000000")
      |> next()
      |> select(["What did you just sing?", "Ignore them"])

    if choice == 1 do
      ask_about_song(ctx)
    else
      ctx
      |> mes("[Absent-Minded Boy]")
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> close()
    end
  end

  defp ask_about_song(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Absent-Minded Boy]")
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Absent-Minded Boy]")
      |> mes("Woof-woof, have you")
      |> mes("heard this song? Mommy")
      |> mes("taught me to sing it, you")
      |> mes("know. She says it was sung")
      |> mes("by people for a long time~")
      |> next()
      |> mes("^3355FFThe boy continued speaking")
      |> mes("to the dog like an old friend,")
      |> mes("ignoring your presence and")
      |> mes("acting as if you didn't exist.^000000")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("Kaanu...")
      |> mes("What did I tell")
      |> mes("you about ignoring")
      |> mes("people's questions!")
      |> next()
      |> mes("[Kaanu]")
      |> mes(".........")
      |> mes("..................")
      |> mes("Uh oh, Woof-woof.")
      |> mes("Mommy seems upset")
      |> mes("for some reason.")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("I'm sorry, my kid is...")
      |> mes("Look, did you want to know")
      |> mes("more about that song? Try")
      |> mes("not to worry about it: it's just an old children's tune.")
      |> next()
      |> select(["Why are you here?", "May I hear the song again?"])

    if choice == 1 do
      ctx
      |> mes("[Exhausted-Looking Woman]")
      |> mes(".................")
      |> next()
      |> mes("^3355FFThe woman's lip tightens")
      |> mes("with shame. It's obvious")
      |> mes("that this topic makes her")
      |> mes("feel very uncomfortable.^000000")
      |> next()
      |> mes("[Kaanu]")
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Kaanu]")
      |> mes("Woof-woof, do you know")
      |> mes("why Mommy is always")
      |> mes("so sad? I wish I knew")
      |> mes("why Mommy never smiles...")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("........")
      |> set_char_var(:prt_curse, 12)
      |> close()
    else
      ctx
      |> mes("[Exhausted-Looking Woman]")
      |> mes("..................")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("Okay. I can do this")
      |> mes("simple thing for you.")
      |> mes("Let me recite this song...")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("The great serpent")
      |> mes("swallowed the sea.")
      |> mes("The eagle of the rainbow")
      |> mes("swallowed the serpent.")
      |> mes("Then snake scales grew on")
      |> mes("the eagle, and it slowly died.")
      |> set_char_var(:prt_curse, 12)
      |> close()
    end
  end

  defp weary_boy(ctx) do
    ctx
    |> mes("^3355FFThe little boy looked")
    |> mes("very worn and weary of")
    |> mes("life, a look that is very")
    |> mes("unsettling on the face")
    |> mes("of a young child.^000000")
    |> close()
  end

  defp smiling_boy(ctx) do
    ctx
    |> mes("^3355FFThe little boy still")
    |> mes("won't talk to you, but")
    |> mes("he acknowledges your")
    |> mes("presense by making eye")
    |> mes("contact and smiling.^000000")
    |> close()
  end

  defp warm_smile(ctx) do
    ctx
    |> mes("^3355FFThe little boy still")
    |> mes("won't talk to you, but he")
    |> mes("make you feel welcome")
    |> mes("by giving you a warm smile.^000000")
    |> close()
  end

  defp wary_boy(ctx) do
    ctx
    |> mes("[Absent-Minded Boy]")
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("^3355FFYou find it difficult")
    |> mes("to ignore the little boy's")
    |> mes("probing, wary eyes directed")
    |> mes("at you. It's very clear that")
    |> mes("he doesn't trust you.^000000")
    |> close()
  end
end

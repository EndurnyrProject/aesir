defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Arc do
  @moduledoc """
  Concludes Terra and Arc's story after her rescue.

  ## Behavior

  - Recounts Terra's encounter with Ogen and awards coins and experience.
  - Provides different dialogue by quest progress, speaker, and language access.

  ## Credits

  - Original from rAthena, authors and contributors:
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
        map: "spl_in02",
        x: 236,
        y: 92,
        dir: 5,
        sprite: 447,
        name: "Arc",
        scope: :shared,
        unique_name: "Arc#ep13md_l02"
      },
      %{
        map: "spl_in02",
        x: 239,
        y: 93,
        dir: 3,
        sprite: 441,
        name: "Terra",
        scope: :shared,
        unique_name: "Terra#ep13md_l03"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    speaker = strnpcinfo(ctx, 1)

    cond do
      checkweight(ctx, [{1201, 2}]) == 0 ->
        overweight(ctx)

      is_equipped(ctx, 2782) == 1 ->
        translated_talk(ctx, get_char_var(ctx, :ep13_mdrama, 0), speaker)

      true ->
        untranslated_talk(ctx, speaker)
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes("Wait a moment!!")
    |> mes("You have too many items.")
    |> mes("You can't receive this.")
    |> mes("Lighten your weight and")
    |> mes("try again.")
    |> close()
  end

  defp untranslated_talk(ctx, "Arc") do
    ctx
    |> mes("[Arc]")
    |> mes("HirWosWeh. Yee DiebVilFar U manTalVil.")
    |> mes("LarsNeiser...??")
    |> mes("VeldTiTal Ko SharDurYur Di ?")
    |> close()
  end

  defp untranslated_talk(ctx, _speaker) do
    ctx
    |> mes("[Terra]")
    |> mes("ModBurDana...? Mu AnduWehFus Yee OsaLoLars...")
    |> mes("eoFusser....")
    |> mes("maurNohser Ur...... ThorNuffLars So ")
    |> close()
  end

  defp translated_talk(ctx, 26, _speaker), do: tell_story(ctx)
  defp translated_talk(ctx, 27, speaker), do: welcome(ctx, speaker)

  defp translated_talk(ctx, progress, "Arc") when progress > 27 do
    ctx
    |> mes("[Arc]")
    |> mes("How are you adapting to Splendide?")
    |> mes("Terra's still not fully recovered yet, so keep that in mind.")
    |> close()
  end

  defp translated_talk(ctx, progress, _speaker) when progress > 27 do
    ctx
    |> mes("[Terra]")
    |> mes("I'm sorry...")
    |> mes("My body is not fully recovered yet...")
    |> close()
  end

  defp translated_talk(ctx, _progress, "Arc") do
    ctx |> mes("[Arc]") |> mes("The back of the right ... ") |> mes("......") |> close()
  end

  defp translated_talk(ctx, _progress, _speaker) do
    ctx
    |> mes("[Terra]")
    |> mes("I'm sorry... I'm so sleepy...")
    |> mes("...I want to sleep...")
    |> close()
  end

  defp tell_story(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Terra]")
      |> mes(".........")
      |> next()
      |> mes("[Arc]")
      |> mes("I see. That's what happened.")
      |> mes("But... That Sapha...What has he become to you in that short period of time?")
      |> next()
      |> select(["Arc?"])

    {ctx, _} =
      ctx
      |> mes("[Arc]")
      |> mes("Ah, finally. I've been speaking with Terra while we waited for you.")
      |> mes("Terra. This is who saved you...")
      |> mes("You should thank #{if sex(ctx) == 1, do: "him.", else: "her."}")
      |> next()
      |> mes("[Terra]")
      |> mes("Thank you...")
      |> mes("I'm sorry Arc... Sorry...")
      |> mes("......")
      |> next()
      |> mes("[Arc]")
      |> mes("So, this is the story.")
      |> mes(
        "Terra was wandering around your Camp and found a Sapha who was also wandering around your Camp at the time."
      )
      |> next()
      |> mes("[Arc]")
      |> mes(
        "They were both being cautious not to be seen by you humans but they caught sight of each other and started to fight."
      )
      |> next()
      |> mes("[Arc]")
      |> mes(
        "And then they eventually fell into that hole in the swamp and ended up in that cave."
      )
      |> next()
      |> mes("[Terra]")
      |> mes("Yeah... We were both unconscious for some time..")
      |> mes("And by the time we were able to wake up and see... We were surrounded.")
      |> next()
      |> mes("[Terra]")
      |> mes("Our main concern was getting out of there...")
      |> mes(
        "Even though we couldn't understand each other's language... We made a temporary truce."
      )
      |> next()
      |> mes("[Terra]")
      |> mes("And then.....")
      |> mes(".........")
      |> next()
      |> select(["So that's what happened."])

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("You were outnumbered and at the last moment Ogen sacrificed himself to protect you.")
    |> next()
    |> mes("[Terra]")
    |> mes("So... I wanted to help him...")
    |> mes("I was just trying to repay him...")
    |> next()
    |> mes("[Terra]")
    |> mes("Was I wrong...?")
    |> mes("Was I thinking wrong?")
    |> next()
    |> mes("[Arc]")
    |> mes("Repaying one's dept is a good thing.")
    |> mes("Especially for a proud Laphine, It sure is.")
    |> next()
    |> mes("[Arc]")
    |> mes("But Terra...")
    |> mes("You've made two big mistakes.")
    |> mes("First is, You went away without permission...")
    |> mes("And secondly...")
    |> next()
    |> mes("[Arc]")
    |> mes("You didn't ask for help.")
    |> mes("If something like that happened... of course I would help...")
    |> next()
    |> mes("[Terra]")
    |> mes("I'm sorry Arc... I'm sorry...")
    |> mes("I won't act foolish ever again.")
    |> next()
    |> mes("[Arc]")
    |> mes("Get some rest.")
    |> mes("I will put in a good word to the superiors...")
    |> mes("And #{char_name(ctx, 0)}...")
    |> mes("Thank you.")
    |> next()
    |> mes("[Arc]")
    |> mes("Here, I will give you these to show my appreciation.")
    |> mes("It's not much, but you will be able to buy things in Splendide with these.")
    |> next()
    |> mes("[Arc]")
    |> mes("I'm sorry this is all I can give you for now.")
    |> set_char_var(:ep13_mdrama, 27)
    |> give_item(6081, 25)
    |> experience_reward()
    |> completequest(7071)
    |> close()
  end

  defp experience_reward(ctx) do
    if Rathena.truthy?(checkre(ctx, 3)) do
      getexp(ctx, 120_000, 10_000)
    else
      getexp(ctx, 1_200_000, 100_000)
    end
  end

  defp welcome(ctx, speaker) do
    ctx
    |> welcome_greeting(speaker)
    |> next()
    |> mes("[#{speaker}]")
    |> mes("Originally... we Laphine were extremely reluctant to have others in our area.")
    |> mes("#{char_name(ctx, 0)}, you will be a special exception.")
    |> next()
    |> mes("[#{speaker}]")
    |> welcome_note(speaker)
    |> mes("It might be cramped, but you are always welcome to visit us.")
    |> set_char_var(:ep13_mdrama, 28)
    |> close()
  end

  defp welcome_greeting(ctx, "Arc") do
    ctx
    |> mes("[Arc]")
    |> mes("Terra. Get some rest...")
    |> mes("Rest easy...")
    |> mes("And...")
  end

  defp welcome_greeting(ctx, _speaker) do
    ctx
    |> mes("[Terra]")
    |> mes("Arc... I will get some rest...")
    |> mes("I'm sorry... And. You...")
  end

  defp welcome_note(ctx, "Arc"), do: mes(ctx, "That's what Terra wants too.")
  defp welcome_note(ctx, _speaker), do: ctx
end

defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.CrusaderSkills.Pastor do
  @moduledoc """
  Father Arthur of Prontera Church, who brews the Goblin Poison Antidote for the Crusader
  Shrink skill quest.

  ## Behavior

  - Lists the antidote ingredients when Ford sends a Crusader to him.
  - Takes the ingredients and distills the antidote, then hands it over on the next visit.
  - Brews a fresh dose free of charge if the previous one failed.
  - Congratulates Paladins who completed the quest; welcomes everyone else to the church.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 87,
        y: 127,
        dir: 3,
        sprite: 755,
        name: "Pastor",
        scope: :shared,
        unique_name: "Pastor#1011"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @shrink 1002
  @sticky_mucus 938
  @empty_bottle 713
  @jellopy 909
  @coal 1003
  @grape 514
  @cyfar 7053
  @unripe_apple 619

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:crusader) do
      paladin_with_shrink? = upper(ctx) == 1 and Rathena.truthy?(getskilllv(ctx, @shrink))
      step = get_char_var(ctx, :CRUS_SK, 0)

      if paladin_with_shrink? and step == 8,
        do: proud_of_paladin(ctx),
        else: antidote_quest(ctx, step)
    else
      welcome(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp antidote_quest(ctx, 4), do: request_ingredients(ctx)
  defp antidote_quest(ctx, 5), do: check_ingredients(ctx)
  defp antidote_quest(ctx, 6), do: hand_over_antidote(ctx)
  defp antidote_quest(ctx, 7), do: hurry_up(ctx)
  defp antidote_quest(ctx, 8), do: patient_recovered(ctx)
  defp antidote_quest(ctx, 9), do: brew_fresh_dose(ctx)
  defp antidote_quest(ctx, 10), do: pleasant_reunion(ctx)
  defp antidote_quest(ctx, _step), do: welcome(ctx)

  defp proud_of_paladin(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("Oh, a Paladin now,")
    |> mes("are you? Ah, I'm quite")
    |> mes("proud of you. After all, I've")
    |> mes("known you back when you")
    |> mes("were a brave Crusader.")
    |> next()
    |> mes("[Father Arthur]")
    |> mes("I hope that you continue to")
    |> mes("use your power to combat")
    |> mes("the forces of evil and to")
    |> mes("protect the weak. May your")
    |> mes("heart guide your actions.")
    |> close()
  end

  defp request_ingredients(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("Greetings.")
    |> mes("How may I be of")
    |> mes("service to you today?")
    |> next()
    |> mes_player_name()
    |> mes("Someone was wounded")
    |> mes("by Goblins, and I was told")
    |> mes("by Sir Ford that you're the")
    |> mes("only one who can make the")
    |> mes("Goblin Poison Antidote.")
    |> next()
    |> mes("[Father Arthur]")
    |> mes("Saints preserve us,")
    |> mes("the Goblins are indeed")
    |> mes("cruel and merciless!")
    |> mes("Unfortunately, I'm fresh")
    |> mes("out of Goblin Poison Antidote")
    |> mes("and must make it from scratch.")
    |> next()
    |> mes_player_name()
    |> mes("Tell me what you")
    |> mes("need to make it, and")
    |> mes("I'll bring you all of the")
    |> mes("materials right away!")
    |> next()
    |> list_ingredients()
    |> set_char_var(:CRUS_SK, 5)
    |> close()
  end

  defp check_ingredients(ctx) do
    if has_ingredients?(ctx), do: distill_antidote(ctx), else: missing_ingredients(ctx)
  end

  defp has_ingredients?(ctx) do
    count_item(ctx, @grape) > 0 and count_item(ctx, @unripe_apple) > 0 and
      count_item(ctx, @coal) > 0 and count_item(ctx, @cyfar) > 2 and
      count_item(ctx, @empty_bottle) > 2 and count_item(ctx, @jellopy) > 4 and
      count_item(ctx, @sticky_mucus) > 19
  end

  defp distill_antidote(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("Ah, you've returned.")
    |> mes("Now let me check to")
    |> mes("see if you've brought")
    |> mes("everything needed to")
    |> mes("create the antidote.")
    |> next()
    |> mes("[Father Arthur]")
    |> mes("Good, good. It looks")
    |> mes("like everything is ready.")
    |> mes("Now, before I begin, I should")
    |> mes("tell you that the antidote has")
    |> mes("a time limit of effectiveness.")
    |> next()
    |> mes("[Father Arthur]")
    |> mes("However, there's no way")
    |> mes("to accurately predict when")
    |> mes("the antidote will become")
    |> mes("ineffective until you try it.")
    |> mes("Therefore, you may have to")
    |> mes("return to me for a new batch.")
    |> next()
    |> mes("[Father Arthur]")
    |> mes("These materials should")
    |> mes("be enough for multiple")
    |> mes("dosages, so you won't have")
    |> mes("to worry about collecting")
    |> mes("materials again. Now, give")
    |> mes("me a moment to distill this...")
    |> delitem(@sticky_mucus, 20)
    |> delitem(@unripe_apple, 1)
    |> delitem(@jellopy, 5)
    |> delitem(@grape, 1)
    |> delitem(@coal, 1)
    |> delitem(@cyfar, 3)
    |> delitem(@empty_bottle, 3)
    |> set_char_var(:CRUS_SK, 6)
    |> close()
  end

  defp missing_ingredients(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("I'm sorry, but these")
    |> mes("aren't enough materials")
    |> mes("in order for me to distill the")
    |> mes("antidote. Hmm, what were")
    |> mes("the required materials again?")
    |> next()
    |> list_ingredients()
    |> close()
  end

  defp list_ingredients(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("Ah, yes. Bring me")
    |> mes("^0000FF20 Sticky Mucus^000000,")
    |> mes("^0000FF3 Empty Bottles^000000,")
    |> mes("^0000FF5 Jellopies^000000...")
    |> next()
    |> mes("[Father Arthur]")
    |> mes("...^0000FF1 Coal^000000,")
    |> mes("^0000FF1 Grape^000000,")
    |> mes("^0000FF3 Cyfar^000000 and")
    |> mes("^0000FF1 Unripe Apple^000000.")
    |> mes("Now hurry, he won't")
    |> mes("last long if he's poisoned!")
  end

  defp hand_over_antidote(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("Your timing must be")
    |> mes("divinely inspired: I've")
    |> mes("just completed the Goblin")
    |> mes("Poison Antidote. Now please")
    |> mes("listen very carefully to me...")
    |> next()
    |> mes("[Father Arthur]")
    |> mes("I can't guarantee if this")
    |> mes("antidote will work. If it")
    |> mes("loses its effectiveness before")
    |> mes("you arrive, you'll have to come")
    |> mes("back and get a fresh new dose.")
    |> next()
    |> mes("[Father Arthur]")
    |> mes("You've got to hurry over")
    |> mes("to the wounded as quickly")
    |> mes("as possible. Now, as soon as")
    |> mes("I hand this to you, you've got")
    |> mes("to run there as fast as you")
    |> mes("can: a man's life is at stake!")
    |> next()
    |> mes("[Father Arthur]")
    |> mes("Here, take the")
    |> mes("antidote. Now go!")
    |> mes("Godspeed, adventurer!")
    |> set_char_var(:CRUS_SK, 7)
    |> close()
  end

  defp hurry_up(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("You haven't left yet?!")
    |> mes("Hurry over to the wounded")
    |> mes("and administer the antidote!")
    |> mes("You'll have to come back for")
    |> mes("a fresh batch of antidote if")
    |> mes("you arrive there too late!")
    |> close()
  end

  defp patient_recovered(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("Ah, so the antidote")
    |> mes("worked and that man is")
    |> mes("expected to fully recover?")
    |> mes("Good, good. It does my heart")
    |> mes("good to hear he's much better.")
    |> close()
  end

  defp brew_fresh_dose(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("The antidote failed?!")
    |> mes("We have no choice, but")
    |> mes("to try it again. Here, let")
    |> mes("me quickly distill a new")
    |> mes("dosage for you. Wait, wait...")
    |> mes("Ah! There! I've finished it!")
    |> next()
    |> mes("[Father Arthur]")
    |> mes("Now take this fresh")
    |> mes("antidote and run as")
    |> mes("fast as you can to")
    |> mes("the wounded! Go!")
    |> set_char_var(:CRUS_SK, 7)
    |> close()
  end

  defp pleasant_reunion(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("Ah, have you been well?")
    |> mes("It is good to see you under")
    |> mes("more pleasant circumstances.")
    |> mes("Nonetheless, if you think that")
    |> mes("I can be of service to you, then please let me know right away.")
    |> close()
  end

  defp welcome(ctx) do
    ctx
    |> mes("[Father Arthur]")
    |> mes("Ah, hello there~")
    |> mes("Welcome to Prontera")
    |> mes("Church. Please relax here,")
    |> mes("enjoy the silence, and invite")
    |> mes("spiritual calm into your heart.")
    |> close()
  end

  defp mes_player_name(ctx),
    do: mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
end

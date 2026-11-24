defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Euslan do
  @moduledoc """
  Euslan asks the player to find her missing fiance and bring her medicine.

  ## Behavior

  - Directs eligible players to search for Thierry and report news of him.
  - Receives his medicine and rewards the player with experience.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "yuno", x: 111, y: 156, dir: 3, sprite: 90, name: "Euslan", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if base_level(ctx) < 60 do
      cough(ctx)
    else
      stage = get_char_var(ctx, :hg_ma1, 0)

      cond do
        not Rathena.truthy?(stage) -> first_meeting(ctx)
        stage == 1 -> offer_help(ctx)
        stage == 2 -> repeat_offer(ctx)
        stage in 3..4 -> search_airship(ctx)
        stage == 5 -> news_from_kaci(ctx)
        stage in 6..7 -> find_eukran(ctx)
        stage in 8..11 -> await_thierry(ctx)
        stage == 12 -> receive_medicine(ctx)
        stage == 13 -> recovered(ctx)
        true -> ctx
      end
    end
  end

  defp first_meeting(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Euslan]")
      |> mes("^333333*Cough Cough*")
      |> mes("*Haaaaaaack*")
      |> mes("*C-cough* *Sob*^000000")
      |> next()
      |> select(["Ignore", "Speak to Euslan"])

    case choice do
      1 -> ignore(ctx)
      2 -> speak_first_time(ctx)
      _ -> ctx
    end
  end

  defp offer_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Euslan]")
      |> mes("^333333*Sniff* *Cough")
      |> mes("*Cough Cough*")
      |> mes("*Sob* *Sniff*^000000")
      |> next()
      |> select(["Ignore", "Speak to Euslan"])

    case choice do
      1 -> ignore(ctx)
      2 -> ask_after_euslan(ctx)
      _ -> ctx
    end
  end

  defp ask_after_euslan(ctx) do
    ctx =
      ctx
      |> mes("[Euslan]")
      |> mes("^333333*Sniff*")
      |> mes("*Huff Huff*")
      |> mes("*Cough Cough*^000000")
      |> next()
      |> mes("[Euslan]")
      |> mes("Oh...")
      |> mes("Hello, wh-what")
      |> mes("^333333*Cough cough*^000000 did")
      |> mes("you want? ^333333*Sniff*^000000")
      |> next()

    {ctx, choice} = select(ctx, ["Nothing!", "Are you alright?"])

    case choice do
      1 -> apologize(ctx)
      2 -> explain_situation(ctx)
      _ -> ctx
    end
  end

  defp explain_situation(ctx) do
    ctx =
      ctx
      |> mes("[Euslan]")
      |> mes("Th-thank you so much")
      |> mes("for your concern. My")
      |> mes("^333333*Cough*^000000 name is Euslan,")
      |> mes("and it's nice to meet you.")
      |> next()
      |> mes("[Euslan]")
      |> mes("I've just been waiting here")
      |> mes("for my fiancee to return, but")
      |> mes("I'm starting to worry since")
      |> mes("I haven't heard from him in")
      |> mes("days. I really want to go out")
      |> mes("and find him on my own. ^333333*Cough*^000000")
      |> next()
      |> mes("[Euslan]")
      |> mes("I really want to see my")
      |> mes("Thierry. If only I wasn't")
      |> mes("so sick, then I wouldn't have")
      |> mes("these problems. ^333333*Sob*^000000 Where")
      |> mes("is he? ^333333*Sniff*^000000 Where's my")
      |> mes("Thierry? I want to see him...")
      |> next()

    {ctx, choice} = select(ctx, ["Leave her alone", "Offer to find Thierry"])
    respond_to_offer(ctx, choice, true)
  end

  defp repeat_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Euslan]")
      |> mes("I've just been waiting here")
      |> mes("for my fiancee to return, but")
      |> mes("I'm starting to worry since")
      |> mes("I haven't heard from him in")
      |> mes("days. I really want to go out")
      |> mes("and find him on my own. ^333333*Cough*^000000")
      |> next()
      |> mes("[Euslan]")
      |> mes("I really want to see my")
      |> mes("Thierry. If only I wasn't")
      |> mes("so sick, then I wouldn't have")
      |> mes("these problems. ^333333*Sob*^000000 Where")
      |> mes("is he? ^333333*Sniff*^000000 Where's my")
      |> mes("Thierry? I want to see him...")
      |> next()
      |> select(["Leave her alone", "Offer to find Thierry"])

    respond_to_offer(ctx, choice, false)
  end

  defp respond_to_offer(ctx, 1, true), do: leave_first_time(ctx)
  defp respond_to_offer(ctx, 1, false), do: leave_again(ctx)
  defp respond_to_offer(ctx, 2, _), do: accept_offer(ctx)
  defp respond_to_offer(ctx, _, _), do: ctx

  defp cough(ctx) do
    ctx
    |> mes("[Euslan]")
    |> mes("^333333*Cough Cough*")
    |> mes("*Haaaaaaack*")
    |> mes("*C-cough* *Sob*^000000")
    |> close()
  end

  defp ignore(ctx) do
    ctx
    |> mes("[Euslan]")
    |> mes("^333333*Sniff*")
    |> mes("*Huff Huff*")
    |> mes("*Cough Cough*^000000")
    |> close()
  end

  defp speak_first_time(ctx) do
    ctx
    |> mes("[Euslan]")
    |> mes("*Huff Huff*")
    |> mes("*Cough Cough*^000000")
    |> next()
    |> mes("^3355FFEusan is seized")
    |> mes("with emotion: it's")
    |> mes("been so long since")
    |> mes("someone has tried")
    |> mes("to speak to her.^000000")
    |> set_char_var(:hg_ma1, 1)
    |> close()
  end

  defp apologize(ctx) do
    ctx
    |> mes("[Euslan]")
    |> mes("Oh, I'm s-sorry...")
    |> mes("^333333*Cough Cough*^000000 I must")
    |> mes("have been mistaken...")
    |> close()
  end

  defp leave_first_time(ctx) do
    ctx
    |> mes("[Euslan]")
    |> mes("Thierry... ^333333*Sob*^000000")
    |> mes("When are you")
    |> mes("coming home?")
    |> mes("I'm so worried...")
    |> mes("^333333*Cough Cough*^000000")
    |> set_char_var(:hg_ma1, 2)
    |> close()
  end

  defp leave_again(ctx) do
    ctx
    |> mes("[Euslan]")
    |> mes("Thierry... ^333333*Sob*^000000")
    |> mes("When are you")
    |> mes("coming home?")
    |> mes("I'm so worried...")
    |> mes("^333333*Cough Cough*^000000")
    |> close()
  end

  defp find_eukran(ctx) do
    ctx
    |> mes("[Euslan]")
    |> mes("If you get the chance,")
    |> mes("please visit my brother")
    |> mes("Eukran in Hugel, and ask")
    |> mes("him where my Thierry might be.")
    |> mes("Thank you again for your kindness.")
    |> close()
  end

  defp await_thierry(ctx) do
    ctx
    |> mes("^3355FFEuslan is waiting for")
    |> mes("you to bring her news from")
    |> mes("her fiancee Thierry. You better")
    |> mes("go back to Hugel to find him.")
    |> close()
  end

  defp recovered(ctx) do
    ctx
    |> mes("^3355FFEuslan is still waiting")
    |> mes("for her fiancee to return")
    |> mes("home, but she appears")
    |> mes("much more relieved and")
    |> mes("relaxed than she used to be.^000000")
    |> close()
  end

  defp accept_offer(ctx) do
    ctx =
      ctx
      |> mes("[Euslan]")
      |> mes("...Are you really willing to")
      |> mes("go out and look for Thierry")
      |> mes("for me? Oh, thank you so")
      |> mes("much! You don't know how")
      |> mes("much your kind offer means")
      |> mes("to me. Now, let's see...")
      |> next()
      |> mes("[Euslan]")
      |> mes("^333333*Cough*^000000 Right, Thierry")
      |> mes("went on a trip, traveling")
      |> mes("on one of the Airships, to")
      |> mes("find some medicine that the")
      |> mes("doctors say I need for my")
      |> mes("illness. ^333333*Cough Cough*^000000")
      |> next()
      |> mes("[Euslan]")
      |> mes("I know it's like searching")
      |> mes("for a needle in a haystack,")
      |> mes("but the only way I can think")
      |> mes("of finding Thierry is to ask")
      |> mes("the Airship Crewmen if they")
      |> mes("might know where my fiancee is.")
      |> next()
      |> mes("[Euslan]")
      |> mes("^333333*Cough*^000000 Oh, right...")
      |> mes("My fiancee was planning on")
      |> mes("searching the Schwarzwald")
      |> mes("Republic, so maybe the crewmen")
      |> mes("on the Schwarzwald Republic domestic flights might know him.")
      |> next()
      |> mes("[Euslan]")
      |> mes("If you manage to find")
      |> mes("where Thierry might have")
      |> mes("gone, then please let me")
      |> mes("know as soon as you can,")
      |> mes("okay? Thanks for cheering")

    ctx
    |> mes(Rathena.concat(Rathena.concat("me up, ", char_name(ctx, 0)), "."))
    |> set_char_var(:hg_ma1, 3)
    |> setquest(8044)
    |> close()
  end

  defp search_airship(ctx) do
    ctx
    |> mes("^333333Euslan is still patiently")
    |> mes("waiting for Thierry's return.")
    |> mes("You should keep your promise")
    |> mes("to her by asking the crewmen on")
    |> mes("the Schwaltvalt Republic domestic flights about Euslan's fiancee.^000000")
    |> close()
  end

  defp news_from_kaci(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Euslan]")
      |> mes("Oh, you're back!")
      |> mes("^333333*Cough*^000000 Maybe it's too")
      |> mes("much to hope for, but did")
      |> mes("you learn anything about")
      |> mes("where my fiancee might be?")
      |> next()
      |> select(["Well, I met Kaci on the Airship."])

    ctx
    |> mes("[Euslan]")
    |> mes("Oh, Kaci works on the")
    |> mes("Airship? It's been so long")
    |> mes("since I've seen her. I guess")
    |> mes("we've lost touch ever since")
    |> mes("I've gotten sick... Still, I'm")
    |> mes("glad to have heard from her.")
    |> next()
    |> mes("[Euslan]")
    |> mes("Oh, how fortunate! So Kaci")
    |> mes("knows where Thierry might be?")
    |> mes("^333333*Cough*^000000 Ah, he went to Hugel.")
    |> mes("I have a brother that lives")
    |> mes("there, though it's been a while")
    |> mes("since I've heard from him...")
    |> next()
    |> mes("[Euslan]")
    |> mes("Um, if you don't mind, would")
    |> mes("you please do another favor")
    |> mes("for me? If you travel to Hugel,")
    |> mes("would you find Thierry and tell")
    |> mes("that I'm alright? He must be")
    |> mes("so worried about he by now...")
    |> next()
    |> mes("[Euslan]")
    |> mes("^333333*Cough Cough*^000000 It might")
    |> mes("be a good idea to ask my")
    |> mes("brother Eukran, who's working")
    |> mes("as a Bingo game coordinator")
    |> mes("in Hugel, since he might know")
    |> mes("where Thierry is. ^333333*Cough*^000000")
    |> next()
    |> mes("[Euslan]")
    |> mes("I know that it's a lot")
    |> mes("to ask, so please don't")
    |> mes("trouble yourself if it's out")
    |> mes("of your way. Still, I'd really")
    |> mes("appreciate your help if you")
    |> mes("happen to pass through Hugel.")
    |> set_char_var(:hg_ma1, 6)
    |> changequest(8046, 8047)
    |> close()
  end

  defp receive_medicine(ctx) do
    ctx =
      ctx
      |> mes("[Euslan]")
      |> mes("Oh, you've returned!")
      |> mes("^333333*Cough*^000000 Were you able to")
      |> mes("speak to my brother and")
      |> mes("find my fiancee Thierry?")
      |> next()
      |> mes("^333333You tell Euslan that you")
      |> mes("were able to find Thierry,")
      |> mes("and that he has managed to")
      |> mes("procure some medicine for")
      |> mes("her. You give Euslan the")
      |> mes("medicine as Thierry requested.^000000")
      |> next()
      |> mes("[Euslan]")
      |> mes("*Sniff* I don't deserve")
      |> mes("such a wonderful man. Why")
      |> mes("did that silly fool go through")
      |> mes("so much trouble for a useless")
      |> mes("woman like me. *Cough* I still don't understand it... I don't...")
      |> next()
      |> mes("[Euslan]")
      |> mes("Thank you so much for")
      |> mes("your help, adventurer, and")
      |> mes("for bringing me this medicine.")
      |> mes("I'll be waiting for Thierry to")
      |> mes("come back home, and do my")
      |> mes("best to get better. ^333333*Cough*^000000")
      |> next()
      |> mes("[Euslan]")

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("", char_name(ctx, 0)),
          "..."
        )
      )
      |> mes("I'll never forget what")
      |> mes("you've done for Thierry and")
      |> mes("me. I'll always be praying for")
      |> mes("your safety in your adventures.")
      |> mes("Take care of yourself...")
      |> close()
      |> set_char_var(:hg_ma1, 13)
      |> completequest(8052)
      |> specialeffect(:absorbspirits)

    if Rathena.truthy?(checkre(ctx, 3)) do
      getexp(ctx, 90_000, 60_000)
    else
      getexp(ctx, 900_000, 600_000)
    end
  end
end

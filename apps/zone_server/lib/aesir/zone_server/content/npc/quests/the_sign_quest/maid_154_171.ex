defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Maid154171 do
  @moduledoc """
  Seylin asks visitors to help her send a birthday gift to her brother.

  ## Behavior

  - Shares information and requests help as the Sign quest progresses.
  - Gives a letter for her brother and rewards the completed delivery.

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
        x: 154,
        y: 171,
        dir: 5,
        sprite: 758,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#s10"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Seylin]")
    progress = get_char_var(ctx, :sign_q, 0)

    cond do
      progress < 38 -> busy(ctx)
      progress == 38 -> leibech(ctx)
      progress < 42 -> worried(ctx, false)
      progress == 42 -> worried(ctx, true)
      progress < 51 -> quest(ctx, progress)
      progress == 97 -> muddy_shoes(ctx)
      progress == 98 -> busy(ctx)
      true -> greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp busy(ctx) do
    ctx
    |> mes("I'm sorry, but I'm")
    |> mes("busy cleaning the manor")
    |> mes("right now so I don't have")
    |> mes("time to talk. Oh, and would")
    |> mes("you please wipe your shoes")
    |> mes("on the mat before coming in?")
    |> close()
  end

  defp leibech(ctx) do
    ctx
    |> mes("Leibech...?")
    |> mes("I remember that he's")
    |> mes("a regular customer who")
    |> mes("orders the strangest things.")
    |> mes("Last I heard, he was traveling")
    |> mes("near Mount Mjolnir.")
    |> next()
    |> mes("[Seylin]")
    |> mes("Yes, that was where")
    |> mes("his last order was sent")
    |> mes("to. Hm, I wonder. Do you")
    |> mes("think he could have been")
    |> mes("heading towards the")
    |> mes("Schwarzwald Republic?")
    |> close()
  end

  defp worried(ctx, advance?) do
    ctx =
      ctx
      |> mes("Ooooh...")
      |> mes("What am I going")
      |> mes("to do?! Oh-- You")
      |> mes("startled me!")
      |> next()
      |> mes("[Seylin]")
      |> mes("I'm sorry, but")
      |> mes("I was just thinking")
      |> mes("about something. I hope")
      |> mes("I didn't bother you. ^333333*Sigh*^000000")

    ctx = if advance?, do: set_char_var(ctx, :sign_q, 43), else: ctx
    close(ctx)
  end

  defp quest(ctx, 43), do: offer_help(ctx)
  defp quest(ctx, 44), do: reconsider(ctx)
  defp quest(ctx, 45), do: decide(ctx)
  defp quest(ctx, progress) when progress in [46, 47], do: medicine_reminder(ctx)
  defp quest(ctx, 48), do: receive_medicine(ctx)
  defp quest(ctx, 49), do: delivery_reminder(ctx)
  defp quest(ctx, 50), do: reward(ctx)
  defp quest(ctx, _), do: ctx

  defp offer_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^333333*Sigh...*^000000")
      |> mes("Oh dear...")
      |> mes("What can I do")
      |> mes("about this...?")
      |> next()
      |> select(["Ignore her.", "Excuse me, but Mahatra sent me..."])

    case choice do
      1 ->
        ctx
        |> mes("[Seylin]")
        |> mes("Oh, it's no use")
        |> mes("worrying about")
        |> mes("something I can do")
        |> mes("nothing about. I better")
        |> mes("get back to work...")
        |> close()

      2 ->
        explain_help(ctx)

      _ ->
        ctx
    end
  end

  defp explain_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Seylin]")
      |> mes("Mister Mahatra")
      |> mes("sent you to me?")
      |> mes("Hm? Does he need")
      |> mes("me for anything?")
      |> next()
      |> select(["Actually, he wants me to help you."])

    case choice do
      1 -> request_medicine(ctx)
      _ -> ctx
    end
  end

  defp request_medicine(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Seylin]")
      |> mes("Oh, how very kind!")
      |> mes("Yes, yes, I could use")
      |> mes("some help right now!")
      |> mes("You see, it'll be my brother's")
      |> mes("birthday, but I'm so busy with")
      |> mes("work that I can't see him.")
      |> emotion(:thanks)
      |> next()
      |> mes("[Seylin]")
      |> mes("The last time I saw him,")
      |> mes("he looked so tired and weak")
      |> mes("so it's worrying me. Now, I've")
      |> mes("heard there's some new medicine")
      |> mes("called ^FF0000Vigorgra^000000. I don't know much about it, but it should help him!")
      |> next()
      |> mes("[Seylin]")
      |> mes("Do you think you could")
      |> mes("find that medicine and")
      |> mes("bring it to me? If you don't")
      |> mes("want to, I understand. Plus,")
      |> mes("I don't know if the master")
      |> mes("would approve of this...")
      |> next()
      |> select([
        "I can't do it.",
        "Let me think about it.",
        "Sure, why not?"
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Seylin]")
        |> mes("Oh, really?")
        |> mes("Alright, I can")
        |> mes("understand. I'm")
        |> mes("very sorry to bother")
        |> mes("you with my problems.")
        |> set_char_var(:sign_q, 44)
        |> close()

      2 ->
        ctx
        |> mes("[Seylin]")
        |> mes("Oh okay.")
        |> mes("Take your time.")
        |> mes("If you can help")
        |> mes("me, I'd really")
        |> mes("appreciate it~")
        |> set_char_var(:sign_q, 45)
        |> close()

      3 ->
        accept_help(ctx)

      _ ->
        ctx
    end
  end

  defp reconsider(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Hello there~")
      |> mes("Oh, have you")
      |> mes("changed your mind")
      |> mes("about helping me?")
      |> mes("I'll repay you,")
      |> mes("of course.")
      |> next()
      |> select(["No.", "Yes."])

    case choice do
      1 ->
        ctx
        |> mes("[Seylin]")
        |> mes("Oh really?")
        |> mes("I'm sorry, I...")
        |> mes("I just thought")
        |> mes("that maybe...")
        |> close2()
        |> emotion(:think)

      2 ->
        accept_help(ctx)

      _ ->
        ctx
    end
  end

  defp decide(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Hello there~")
      |> mes("So have you decided")
      |> mes("yet? If you help me,")
      |> mes("I'll be sure to pay")
      |> mes("you back somehow.")
      |> next()
      |> select(["Um, I'm still thinking.", "Yes."])

    case choice do
      1 ->
        ctx
        |> mes("[Seylin]")
        |> mes("Oh okay.")
        |> mes("But please hurry~")
        |> mes("My brother's birthday")
        |> mes("is coming up soon!")
        |> close()

      2 ->
        accept_help(ctx)

      _ ->
        ctx
    end
  end

  defp accept_help(ctx) do
    ctx
    |> mes("[Seylin]")
    |> mes("Oh, thank you so much!")
    |> mes("Now, I remember hearing")
    |> mes("that you can find Vigorgra")
    |> mes("somewhere in Al de Baran.")
    |> mes("Somebody in the Alchemist")
    |> mes("Guild makes it, I think.")
    |> next()
    |> mes("[Seylin]")
    |> mes("I'm sorry, but I don't")
    |> mes("know much about the medicine.")
    |> mes("Well, aside from the fact that")
    |> mes("it makes men feel young again.")
    |> mes("So that must be good, right?")
    |> mes("Thanks again for your help~")
    |> set_char_var(:sign_q, 46)
    |> close()
  end

  defp medicine_reminder(ctx) do
    ctx
    |> mes("I know that you might")
    |> mes("be able to find Vigorgra")
    |> mes("in the Alchemist's Guild")
    |> mes("in Al de Baran. Aside from")
    |> mes("that, I don't know much...")
    |> next()
    |> mes("[Seylin]")
    |> mes("Once you get it,")
    |> mes("would you bring")
    |> mes("the Vigorgra to me?")
    |> close()
  end

  defp receive_medicine(ctx) do
    if count_item(ctx, 7044) < 1 do
      ctx
      |> mes("Oh, you know where")
      |> mes("you can get Vigorgra?")
      |> mes("That's great news!")
      |> mes("Oh, when you have it,")
      |> mes("bring to me, okay?")
      |> close()
    else
      ctx
      |> mes("Hurray~!")
      |> mes("You brought the")
      |> mes("Vigorgra! I hope")
      |> mes("my brother will")
      |> mes("be happy with this!")
      |> next()
      |> mes("[Seylin]")
      |> mes("Oh! Would you please")
      |> mes("bring this Vigorgra to my")
      |> mes("brother? His name is Maruin")
      |> mes("and he's working over at")
      |> mes("the Prontera Castle.")
      |> next()
      |> mes("[Seylin]")
      |> mes("Ah, I almost forgot!")
      |> mes("I just finished writing")
      |> mes("him this letter, so would")
      |> mes("you also make sure he gets")
      |> mes("this? Thank you so much!")
      |> set_char_var(:sign_q, 49)
      |> give_item(7183, 1)
      |> close()
    end
  end

  defp delivery_reminder(ctx) do
    ctx
    |> mes("Would you please")
    |> mes("deliver the Vigorgra")
    |> mes("and my letter to my brother")
    |> mes("Maruin in the Prontera Castle?")
    |> mes("And wish him 'Happy Birthday~'")
    |> close()
  end

  defp reward(ctx) do
    ctx
    |> mes("Thanks so much")
    |> mes("for your help again!")
    |> mes("I want you to have this")
    |> mes("as a token of my gratitude.")
    |> mes("You really are a kind person~")
    |> set_char_var(:sign_q, 51)
    |> give_item(525, 3)
    |> next()
    |> emotion(:chupchup)
    |> close()
  end

  defp muddy_shoes(ctx) do
    ctx
    |> mes("Oh no~!")
    |> mes("Please don't")
    |> mes("drag your muddy")
    |> mes("feet over the carpet!")
    |> mes("Would you please leave?")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("Although the master isn't")
    |> mes("a messy person, he's pretty")
    |> mes("unorganized. I wish he'd make")
    |> mes("it easier for me to tell which")
    |> mes("papers are documents and ")
    |> mes("which ones are trash...")
    |> next()
    |> mes("[Seylin]")
    |> mes("So how have you been?")
    |> mes("Is everything okay with you?")
    |> mes("I hope you have a lot of good")
    |> mes("experiences in your adventures~")
    |> close()
  end
end

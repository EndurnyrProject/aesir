defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNiflheim.Feylin do
  @moduledoc """
  A Niflheim sorcerer who, once convinced, tries to summon Erious' late wife for Message
  Delivery questers.

  ## Behavior

  - On the first visit he tells the living player to leave; insisting on the next visit
    advances the quest.
  - With a Witherless Rose as proof that Billik sent them, players of base level 80 or more
    may pay 10 Yggdrasil Leaves for the ritual.
  - The ritual consumes the rose and leaves either way. On 87 of 100 rolls it fails and
    takes 99% HP; otherwise it takes 50% HP and summons Elly, who forgives Erious and
    hands over her Mementos.
  - Lacking the rose, level or leaves, or declining, ends the conversation without changes.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Evera
    - Lupus
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - The original successful ritual runs `changequest 11040,11043`, but the player holds
    quest 11041 at that step (set by the previous step, and used by the failed ritual's
    `changequest 11041,11042`), so the change never applied and Erious could not complete
    quest 11043. It is fixed to change 11041 into 11043.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "niflheim", x: 153, y: 215, dir: 3, sprite: 794, name: "Feylin", scope: :shared}
    ]

  @witherless_rose 748
  @yggdrasil_leaf 610
  @mementos 934

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :nif_revive, 0) do
      2 -> first_meeting(ctx)
      3 -> refuse(ctx)
      4 -> ritual_offer(ctx)
      _ -> send_away(ctx)
    end
  end

  defp first_meeting(ctx) do
    ctx
    |> mes("[Feylin]")
    |> mes("Poor #{if sex(ctx) == 1, do: "guy", else: "girl"}...")
    |> mes("Dying at such a young age...")
    |> mes("I am always sorry to see the")
    |> mes("young pass away.")
    |> next()
    |> mes("[Feylin]")
    |> mes("............??")
    |> mes("Oh, I see you're not dead yet,")
    |> mes("are you? It's unbelievable to")
    |> mes("see another living person")
    |> mes("in this town.")
    |> next()
    |> mes("[Feylin]")
    |> mes("Are you coming to rescue someone,")
    |> mes("or do you have another purpose?")
    |> mes("If you came here to meet a")
    |> mes("deceased friend of yours, you've")
    |> mes("come to the wrong person.")
    |> next()
    |> mes("[Feylin]")
    |> mes("Nobody in Niflheim can")
    |> mes("perform that kind of miracle...")
    |> next()
    |> mes("[Feylin]")
    |> mes("I can tell you have been through")
    |> mes("much hardship, but unfortunately,")
    |> mes("you came here for nothing. I hope")
    |> mes("you go back to where you came")
    |> mes("from before it's too late.")
    |> set_char_var(:nif_revive, 3)
    |> changequest(11_039, 11_040)
    |> close()
  end

  defp refuse(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Feylin]")
      |> mes("I've asked you to leave this")
      |> mes("town immediately. I'm sorry")
      |> mes("but I know nothing about what")
      |> mes("you are asking.")
      |> emotion(:fret)
      |> next()
      |> select(["But...", "I am sorry."])

    if choice == 1 do
      ctx
      |> mes("[Feylin]")
      |> mes("You must know something...")
      |> mes("Otherwise, you wouldn't be")
      |> mes("so stubborn. I am not sure")
      |> mes("who told you contacting the")
      |> mes("dead might be possible...")
      |> next()
      |> mes("[Feylin]")
      |> mes("But I surely wouldn't have told")
      |> mes("you. Besides, speaking about")
      |> mes("such things is taboo.")
      |> set_char_var(:nif_revive, 4)
      |> changequest(11_040, 11_041)
      |> close()
    else
      ctx
      |> mes("[Feylin]")
      |> mes("Please consider leaving this")
      |> mes("place as soon as possible.")
      |> mes("Nobody should stay in")
      |> mes("Niflheim for too long.")
      |> close()
    end
  end

  defp ritual_offer(ctx) do
    if count_item(ctx, @witherless_rose) > 0 do
      warn_price(ctx)
    else
      ctx
      |> mes("[Feylin]")
      |> mes("No matter how many times you ask")
      |> mes("me, I cannot help you. Please")
      |> mes("leave this place as soon as you can.")
      |> close()
    end
  end

  defp warn_price(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Feylin]")
      |> mes("Huh, Billik must have sent you.")
      |> mes("Since I'm indebted to him, I")
      |> mes("suppose I will help you.")
      |> mes("But let me warn you.")
      |> mes("The price that I demand may be")
      |> mes("more that you expect...")
      |> next()
      |> select(["I'm willing to do this.", "I don't think I can do this."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Feylin]")
        |> mes("You made a good decision.")
        |> mes("It's not a good idea to perform")
        |> mes("this kind of sorcery in the")
        |> mes("first place because of the")
        |> mes("risks involved...")
        |> close()

      base_level(ctx) > 79 ->
        explain_ritual(ctx)

      true ->
        ctx
        |> mes("[Feylin]")
        |> mes("Hmm... You don't seem to have")
        |> mes("the strength to endure the")
        |> mes("casting of this spell. At")
        |> mes("your current strength, this")
        |> mes("spell will kill you.")
        |> mes("I cannot take that risk.")
        |> close()
    end
  end

  defp explain_ritual(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Feylin]")
      |> mes("Alright, but you must promise")
      |> mes("me that you will not let other")
      |> mes("people know what I am about")
      |> mes("to tell you.")
      |> next()
      |> mes("[Feylin]")
      |> mes("This sorcery requires great")
      |> mes("sacrifice. Needless to say, there")
      |> mes("is a chance that this spell may")
      |> mes("fail. I must also have")
      |> mes("10 Yggdrasil Leaf to cast this")
      |> mes("spell. Do you wish to continue?")
      |> next()
      |> select(["Yes", "No"])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Feylin]")
        |> mes("I hope you will bring the items")
        |> mes("first. But... I don't have the")
        |> mes("confidence to promise that")
        |> mes("this spell will cast successfully.")
        |> close()

      count_item(ctx, @yggdrasil_leaf) > 9 ->
        cast_ritual(ctx)

      true ->
        ctx
        |> mes("[Feylin]")
        |> mes("If you don't have the")
        |> mes("items, we cannot proceed.")
        |> mes("Remember, I need 10 Yggdrasil")
        |> mes("Leaves to perform this spell.")
        |> mes("Please bring them as soon")
        |> mes("as possible.")
        |> close()
    end
  end

  defp cast_ritual(ctx) do
    ctx =
      ctx
      |> mes("[Feylin]")
      |> mes("I see. Then we shall begin.")
      |> mes("Woombahsokasabahah!")
      |> mes("Woombah woombah hoombabah!")
      |> mes("Yeeeeep!")
      |> next()

    if Enum.random(1..100) < 88, do: ritual_failed(ctx), else: summon_elly(ctx)
  end

  defp ritual_failed(ctx) do
    ctx
    |> mes("[Feylin]")
    |> mes("...I am sorry.")
    |> mes("I have failed to summon")
    |> mes("who you wish to see. I am")
    |> mes("really sorry for this result.")
    |> emotion(:huk)
    |> delitem(@witherless_rose, 1)
    |> delitem(@yggdrasil_leaf, 10)
    |> set_char_var(:nif_revive, 5)
    |> changequest(11_041, 11_042)
    |> percent_heal(hp: -99, sp: 0)
    |> next()
    |> mes("[Feylin]")
    |> mes("Unfortunately, it may be")
    |> mes("impossible to summon the")
    |> mes("spirit of the person with")
    |> mes("whom you wished to speak...")
    |> close()
  end

  defp summon_elly(ctx) do
    {ctx, _} =
      ctx
      |> delitem(@witherless_rose, 1)
      |> delitem(@yggdrasil_leaf, 10)
      |> percent_heal(hp: -50, sp: 0)
      |> mes("[Feylin]")
      |> mes("..........")
      |> mes("..........")
      |> next()
      |> mes("[Elly]")
      |> mes("..........")
      |> mes(".....Umm...")
      |> mes("...Wasn't I just dead?")
      |> mes("Um, do I know you?")
      |> next()
      |> select(["I brought a message from your husband."])

    {ctx, _} =
      ctx
      |> mes("[Elly]")
      |> mes("Oh...I see...I'm sorry that I could not meet him before I died...")
      |> mes("So what is his message for me?")
      |> next()
      |> select(["Forgive him for what happened a month ago."])

    ctx
    |> mes("[Elly]")
    |> mes("*Sigh* He's such a nice husband...")
    |> mes("He pays such attention, even to")
    |> mes("the little things. Though, I")
    |> mes("should be the one apologizing")
    |> mes("to him...")
    |> next()
    |> mes("[Elly]")
    |> mes("Please give him this box, and tell")
    |> mes("him to forget about me. He should")
    |> mes("live the rest of his life happily")
    |> mes("with someone else. Oh, also let")
    |> mes("him know that I forgive him.")
    |> set_char_var(:nif_revive, 6)
    |> changequest(11_041, 11_043)
    |> give_item(@mementos, 1)
    |> next()
    |> mes("[Elly]")
    |> mes("I am glad to hear from my")
    |> mes("husband one more time. But I")
    |> mes("think I have to go now.")
    |> mes("Thank you for your trouble.")
    |> mes("Farewell...")
    |> next()
    |> mes("[Elly]")
    |> mes(".....................")
    |> mes("....................")
    |> next()
    |> mes("[Feylin]")
    |> mes("I guess you have accomplished what")
    |> mes("you wanted. Well then, be careful")
    |> mes("when you go back...")
    |> close()
  end

  defp send_away(ctx) do
    ctx
    |> mes("[Feylin]")
    |> mes("What makes you to come to such")
    |> mes("a dangerous town? Please leave")
    |> mes("this place as soon as you can.")
    |> close()
  end
end

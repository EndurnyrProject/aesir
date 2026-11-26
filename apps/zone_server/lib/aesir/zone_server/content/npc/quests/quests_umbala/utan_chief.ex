defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsUmbala.UtanChief do
  @moduledoc """
  Guides visitors through the Utan language quest and the shaman's request.

  ## Behavior

  - Teaches the language to visitors wearing a suitable mask who bring the required materials.
  - Requests a Mr. Smile mask before confirming the visitor's qualification to the shaman.

  ## Credits

  - Original from rAthena, authors and Contributors
    - sabernet09
    - rAthena Team
    - x[tsk]
    - Lupus
    - PoW
    - Evera
    - SinSloth
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "um_in", x: 39, y: 122, dir: 5, sprite: 784, name: "Utan Chief", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :event_umbala, 0) do
      0 -> welcome(ctx)
      1 -> discuss_language(ctx)
      2 -> teach_language(ctx)
      4 -> request_mask(ctx)
      5 -> accept_mask(ctx)
      progress when progress >= 3 -> greeting(ctx)
      _ -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_language(ctx) do
    {ctx, choice} = language_menu(ctx)

    case choice do
      1 ->
        if Enum.any?([2278, 2297, 2288, 2292, 5005, 2281, 5043], fn item ->
             Rathena.truthy?(is_equipped(ctx, item))
           end) do
          offer_lesson(ctx)
        else
          explain_mask(ctx)
        end

      2 ->
        discuss_culture(ctx)

      3 ->
        discuss_journey(ctx)

      _ ->
        ctx
    end
  end

  defp teach_language(ctx) do
    if count_item(ctx, 7151) > 9 and count_item(ctx, 7111) > 4 and
         count_item(ctx, 1024) > 0 and count_item(ctx, 916) > 0 do
      complete_lesson(ctx)
    else
      remind_materials(ctx)
    end
  end

  defp accept_mask(ctx) do
    if count_item(ctx, 2278) > 0, do: complete_request(ctx), else: remind_mask(ctx)
  end

  defp welcome(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("Huh huh, a Rune-Midgartsian.")
    |> mes("I guess this is your first")
    |> mes("visit to my village, isn't it?")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Everyone from Rune-Midgarts")
    |> mes("that I've met had the same")
    |> mes("same expression on their")
    |> mes("face as you do right now")
    |> mes("when they first came here.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Maybe it's because they cannot")
    |> mes("communicate with us due to")
    |> mes("the language barrier, so")
    |> mes("they have no idea what's going")
    |> mes("on. Yeah, I understand...")
    |> mes("Anyway, welcome to my village.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("My name is Karkatan, and I")
    |> mes("am the chief of the Utan tribe.")
    |> mes("You must be wondering how")
    |> mes("I can speak your language.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("It was taught to me long ago")
    |> mes("by an adventurer from your")
    |> mes("land. It's been a long time,")
    |> mes("and I do not know what has")
    |> mes("become of him...")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Anyhow, I learned many things")
    |> mes("about Rune-Midgartsian culture")
    |> mes("and language.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Sometimes, I teach the Utan")
    |> mes("language, but I do not give")
    |> mes("everyone that privilege.")
    |> mes("If unscrupulous outsiders")
    |> mes("learn the Utan language, they")
    |> mes("may bring harm to my tribe.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Before you can learn the Utan")
    |> mes("language, first try to learn")
    |> mes("Utan culture by exploring our")
    |> mes("village.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Although you are not able to")
    |> mes("communicate with my people")
    |> mes("right now, try to understand")
    |> mes("our way of life through your")
    |> mes("observations.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Pay attention to the dress,")
    |> mes("appearance and life style of the")
    |> mes("local people. When you think")
    |> mes("you understand enough about Utan")
    |> mes("culture, come back to me and show me what you have learned.")
    |> set_char_var(:event_umbala, 1)
    |> close()
  end

  defp language_menu(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("Oh, it's you again. So...")
    |> mes("Have you learned about Utan")
    |> mes("culture? I want to hear your")
    |> mes("opinion, as well as your impression.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("There are still some villagers")
    |> mes("who are very naive about Rune-Midgartsians.")
    |> mes("Usually, they fear encounters")
    |> mes("with your people and will")
    |> mes("hide themselves.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("So...")
    |> mes("May I help you with anything?")
    |> mes("I assume you did not have much of")
    |> mes("a problem looking around the")
    |> mes("village, but it seems you have something to ask of me.")
    |> next()
    |> select(["I want to learn Utan language.", "Umbabah Umbabah?", "Nothing."])
  end

  defp offer_lesson(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("Hmmm...That's an awesome mask")
    |> mes("you're wearing. We Utans like")
    |> mes("wearing masks to keep from")
    |> mes("showing our facial expressions.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("That's why we wear masks all the")
    |> mes("time. We believe that interaction")
    |> mes("and treatment of other people")
    |> mes("should not depend on how we look.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Alright. I am sure you are")
    |> mes("qualified to learn the Utan")
    |> mes("language. I will teach you how")
    |> mes("speak and to read in Utan from")
    |> mes("now on.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("However, I need you to get some")
    |> mes("items ready so that we may proceed")
    |> mes("with the lessons. First, we need")
    |> mes("two different kinds of paper.")
    |> mes("^3377FF10 Oil Paper^000000 and ")
    |> mes("^3377FF5 Slick Paper^000000.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("We'll also need something to")
    |> mes("write with. Let's use")
    |> mes("^3377FF1 Squid Ink^000000 and")
    |> mes("^3377FF1 Feather of Birds^000000.")
    |> mes("Please bring me those, and I will")
    |> mes("teach you when you're ready.")
    |> set_char_var(:event_umbala, 2)
    |> close()
  end

  defp explain_mask(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("You don't seem to understand")
    |> mes("our culture yet. You cannot")
    |> mes("learn another language if you")
    |> mes("do not understand the culture.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("When you have that expression on")
    |> mes("your face, Utans will be")
    |> mes("intimidated... Since we do")
    |> mes("not show our faces to others,")
    |> mes("we are actually very")
    |> mes("vulnerable to facial expression.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Go explore the village a little")
    |> mes("longer. You can come back")
    |> mes("anytime when you think you're ready.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("In any case, what do you think")
    |> mes("about my mask? It's the current")
    |> mes("trend among us Utans...don't you")
    |> mes("think it's awesome?")
    |> close()
  end

  defp discuss_culture(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("Haha~ When you're just imitating")
    |> mes("the sound, you won't make any")
    |> mes("sense. Language is a mutual system")
    |> mes("for the communication of thoughts and feelings.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("I regret to say that it seems that")
    |> mes("nowadays, all peoples are no")
    |> mes("longer sensitive to other cultures")
    |> mes("in that respect.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("I see people that despise or")
    |> mes("ridicule others that do not")
    |> mes("understand them. It's really")
    |> mes("sad that such bigotry still exists...")
    |> next()
    |> mes("[Karkatan]")
    |> mes("If you are interested in Utan")
    |> mes("language, try to understand our")
    |> mes("culture better and come back")
    |> mes("when you're ready. I will")
    |> mes("teach you the meanings of those sounds you are using.")
    |> close()
  end

  defp discuss_journey(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("Sometimes it's good to wander")
    |> mes("without purpose. But it's")
    |> mes("better to set a goal for")
    |> mes("a journey if you want to")
    |> mes("learn something out of")
    |> mes("the experience.")
    |> close()
  end

  defp complete_lesson(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("Okay, I guess we're good to go.")
    |> mes("Let's get the lesson started.")
    |> mes("I hope you will communicate better")
    |> mes("with Utans when we are done.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("..............")
    |> next()
    |> mes("[Karkatan]")
    |> mes("..............")
    |> mes(".....................")
    |> next()
    |> mes("[Karkatan]")
    |> mes("..............")
    |> mes(".....................")
    |> mes("............................")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Alright, that's all. Just forget")
    |> mes("about how you've felt about Utans")
    |> mes("before you learned the language.")
    |> mes("Now go try to talk to Utans.")
    |> mes("Conversation is a very important method in understanding others.")
    |> delitem(7151, 10)
    |> delitem(7111, 5)
    |> delitem(1024, 1)
    |> delitem(916, 1)
    |> set_char_var(:event_umbala, 3)
    |> next()
    |> mes("[Karkatan]")
    |> mes("Okay, if you have any business")
    |> mes("in our village later, feel free")
    |> mes("to talk to me. I will try to help")
    |> mes("you as much as I can.")
    |> close()
  end

  defp remind_materials(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("I guess you are not ready yet...")
    |> mes("Did you forget what items you")
    |> mes("need? I will let you know")
    |> mes("again, so please bring them")
    |> mes("so that we can start the lesson.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("^3377FF10 Oil Paper^000000,")
    |> mes("^3377FF5 Slick Paper^000000,")
    |> mes("^3377FF1 Squid Ink^000000,")
    |> mes("^3377FF1 Feather of Birds^000000.")
    |> mes("When you bring all of these,")
    |> mes("I will teach you our language.")
    |> close()
  end

  defp request_mask(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("Puchuchartan must have sent you to")
    |> mes("me. I need to check whether or not")
    |> mes("you are qualified to request")
    |> mes("her help...We Utans do not want")
    |> mes("to help evil people.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Hmmmm....")
    |> mes("It would be good to have a mask")
    |> mes("that was made in Rune-Midgarts...")
    |> next()
    |> mes("[Karkatan]")
    |> mes("I wish to have ^3377FF1 Mr. Smile^000000.")
    |> mes("To Utans, receiving a mask as a")
    |> mes("present is considered an")
    |> mes("honor. Maybe Puchuchartan")
    |> mes("wants you to show us your respect by doing so.")
    |> set_char_var(:event_umbala, 5)
    |> close()
  end

  defp complete_request(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("Oh, you brought it! Yes, I've")
    |> mes("always wished that I could have")
    |> mes("this mask! This is truly an")
    |> mes("honor! Thank you, adventurer")
    |> mes("from Rune-Midgarts.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("I will tell Puchuchartan that I")
    |> mes("confirmed your qualification.")
    |> mes("Go and speak to her. Though I")
    |> mes("am not sure what help she can give")
    |> mes("you, I hope we will be able to return this favor.")
    |> delitem(2278, 1)
    |> set_char_var(:event_umbala, 6)
    |> close()
  end

  defp remind_mask(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("Did I tell you that you need")
    |> mes("^3377FF1 Mr. Smile^000000?")
    |> mes("Please bring that as proof")
    |> mes("of your goodwill, as well")
    |> mes("as your sense of honor.")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Karkatan]")
    |> mes("How's it going?")
    |> mes("I wish I could guide you around")
    |> mes("the village, but I cannot neglect")
    |> mes("my duty as tribal chief.")
    |> next()
    |> mes("[Karkatan]")
    |> mes("Leading a tribe is not as easy")
    |> mes("as it looks. You would understand")
    |> mes("if you were in the same position")
    |> mes("as me. Anyway, I hope you will enjoy your time in our village.")
    |> close()
  end
end

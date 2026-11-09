defmodule Aesir.ZoneServer.Content.Npc.Quests.ObbQuest.OldMan do
  @moduledoc """
  Elder Creek offers advice and concludes the Old Blue Box quest.

  ## Behavior

  - Tests adventurers seeking fortune and offers advice on everyday problems.
  - Requests supplies and rewards their delivery with an Old Blue Box.
  - Occasionally forgives insults and sends rude visitors away after the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celesta
    - Lupus
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/obb_quest.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 68,
        y: 195,
        dir: 0,
        sprite: 120,
        name: "Old Man",
        scope: :shared,
        unique_name: "Old Man#thai"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("- Wait a moment! -")
      |> mes("- Currently you're carrying -")
      |> mes("- too many items with you. -")
      |> mes("- Please enlighten your weight -")
      |> mes("- and try again. -")
      |> close()
    else
      quest_dialogue(ctx)
    end
  end

  defp quest_dialogue(ctx) do
    case get_char_var(ctx, :thai_head, 0) do
      11 -> seek_guidance(ctx)
      12 -> seek_forgiveness(ctx)
      13 -> request_supplies(ctx)
      14 -> seek_more_advice(ctx)
      15 -> bring_supplies(ctx)
      stage when stage > 15 -> offer_advice(ctx)
      _ -> first_advice(ctx)
    end
  end

  defp seek_guidance(ctx) do
    {ctx, goal} =
      ctx
      |> mes("[Elder Creek]")
      |> mes("Good day, adventurer.")
      |> mes("What kind of business")
      |> mes("do you have with me?")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("Are you seeking fortune or")
      |> mes("mental relief? If not, do")
      |> mes("you wish to finish something")
      |> mes("you've started?")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("Answer me, adventurer!")
      |> next()
      |> select(["I seek fortune!", "I seek...wisdom.", "I want to finish what I've started."])

    case goal do
      1 ->
        fortune_quiz(ctx)

      2 ->
        request_advice(ctx)

      3 ->
        ctx |> mes("[Elder Creek]") |> mes("Yes, you need to see things to the end.") |> close()

      _ ->
        ctx
    end
  end

  defp seek_forgiveness(ctx) do
    if Enum.random(1..1000) == 792 do
      ctx
      |> mes("[Elder Creek]")
      |> mes("....*Sigh* Okay.")
      |> mes("I forgive you.")
      |> set_char_var(:thai_head, 11)
      |> close()
    else
      ctx
      |> mes("[Elder Creek]")
      |> mes("I do not wish to continue this conversation with you.")
      |> mes("Get out of my sight immediately!")
      |> close()
    end
  end

  defp request_supplies(ctx) do
    ctx
    |> mes("[Elder Creek]")
    |> mes("...I was just testing you")
    |> mes("in order to give you something")
    |> mes("special. I'm the only person in the world that can give you this...")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("I had to check if you are the right person as I initially thought.")
    |> mes("....Hmm.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("But you don't expect me to give something special without any compensation, do you?")
    |> mes("Would you bring the items I want?")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("It's not a hard thing to do.")
    |> mes("That is...")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("10 Brigan,")
    |> mes("15 Clam Shell,")
    |> mes("10 Crab Shell")
    |> mes("and 50 Cyfar.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Well, I am collecting those as my hobby.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("I have no doubt that you will be able to gather them all.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Do me this favor, young man.")
    |> set_char_var(:thai_head, 15)
    |> close()
  end

  defp seek_more_advice(ctx) do
    if Enum.random(1..30) == 5 do
      ctx
      |> mes("[Elder Creek]")
      |> mes("....hmm. I see you want more.")
      |> mes("Come back later.")
      |> set_char_var(:thai_head, 13)
      |> close()
    else
      ctx
      |> mes("[Elder Creek]")
      |> mes("Is there any business left between")
      |> mes("us? Tell me, young adventurer...")
      |> next()
      |> mes("^3355FFYou feel there may be something you missed.^000000")
      |> close()
    end
  end

  defp bring_supplies(ctx) do
    if count_item(ctx, 7054) > 9 and count_item(ctx, 965) > 14 and count_item(ctx, 964) > 9 and
         count_item(ctx, 7053) > 49 do
      ctx
      |> mes("[Elder Creek]")
      |> mes("I see you know how the world")
      |> mes("works. When you need something")
      |> mes("from someone, you must give")
      |> mes("in order to receive.")
      |> mes("Thank you for your kindness.")
      |> delitem(7054, 10)
      |> delitem(965, 15)
      |> delitem(964, 10)
      |> delitem(7053, 50)
      |> next()
      |> set_char_var(:thai_head, 16)
      |> give_item(603, 1)
      |> mes("[Elder Creek]")
      |> mes("Please, take this first.")
      |> mes("If you would, please go talk to my")
      |> mes("grandson later. He seemed to witness something horrible a while ago...")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("I have no idea what he saw,")
      |> mes("because the shock took away")
      |> mes("his ability to speak.")
      |> mes("When he recovers, I will tell you.")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("In fact, the items I have asked")
      |> mes("for will be used to cure")
      |> mes("his condition. I don't")
      |> mes("really collect these as a")
      |> mes("hobby...")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("I am sorry to cause you")
      |> mes("much trouble for my own good.")
      |> close()
    else
      ctx
      |> mes("[Elder Creek]")
      |> mes("Remember, when you want something,")
      |> mes("especially when it's special, you")
      |> mes("should always offer something in exchange.")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("I want...")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("10 Brigan,")
      |> mes("15 Clam Shell,")
      |> mes("10 Crab Shell and")
      |> mes("50 Cyfar.")
      |> close()
    end
  end

  defp offer_advice(ctx) do
    {ctx, wants_advice} =
      ctx
      |> mes("[Elder Creek]")
      |> mes("Feel free to come back anytime...")
      |> mes("And if you need advice, I am more than willing to help you.")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("Do you wish for me to give you advice, adventurer?")
      |> next()
      |> select(["Yes.", "No."])

    if wants_advice == 1 do
      {ctx, problem} =
        ctx
        |> mes("[Elder Creek]")
        |> mes("Now, tell me what bothers you at the moment.")
        |> next()
        |> select([
          "Boy/girlfriend issue.",
          "Financial problem.",
          "Bored to death.",
          "Career issue.",
          "Give me items, old man."
        ])

      give_advice(ctx, problem)
    else
      ctx
      |> mes("[Elder Creek]")
      |> mes("I hope you will enjoy your life. Remember, time flies and you live only once.")
      |> close()
    end
  end

  defp first_advice(ctx) do
    {ctx, problem} =
      ctx
      |> mes("[Elder Creek]")
      |> mes("I have been helping people by giving them advice to improve their lives.")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("Since you need my help as well, I shall endeavor to impart some wisdom.")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("Now tell me, what bothers you right now?")
      |> next()
      |> select([
        "Boy/girlfriend issue.",
        "Financial problem.",
        "Bored to death.",
        "Career issue.",
        "Give me items, old man."
      ])

    give_advice(ctx, problem)
  end

  defp fortune_quiz(ctx) do
    {ctx, meaning} =
      ctx
      |> mes("[Elder Creek]")
      |> mes("You're honest...!")
      |> mes("However, I suggest that you try not to be enamored with wealth.")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("Do you know the exact meaning")
      |> mes("of the old saying...")
      |> mes("^0000FFToo much is as bad as too little^000000?")
      |> mes("I will give you what you want if")
      |> mes("you answer the way I expect you to.")
      |> next()
      |> select([
        "It's necessary to have a lot!",
        "Too dumb to see the future.",
        "Too much of a good thing can be bad.",
        "Cringe to the powerful."
      ])

    case meaning do
      1 ->
        ctx
        |> mes("[Elder Creek]")
        |> mes("...")
        |> mes("Get out of my sight,")
        |> mes("you greedy fool.")
        |> set_char_var(:thai_head, 12)
        |> close()

      2 ->
        ctx
        |> mes("[Elder Creek]")
        |> mes("Bah! The more ignorant they are, the more arrogantly they act!")
        |> mes("Did you think that I would accept just any meaning?")
        |> mes("Take care, you ignorant fool.")
        |> set_char_var(:thai_head, 12)
        |> close()

      3 ->
        ctx
        |> mes("[Elder Creek]")
        |> mes("That's right. You know it pretty")
        |> mes("well. That adage serves as a lesson in greed.")
        |> next()
        |> mes("[Elder Creek]")
        |> mes("There is a man I've known for a")
        |> mes("long time...he was so greedy for")
        |> mes("money and fortune, he didn't care what other people thought of him.")
        |> next()
        |> mes("[Elder Creek]")
        |> mes("Consequently, people around him")
        |> mes("didn't like him at all. In the end, he lost his friends due to his greed.")
        |> next()
        |> mes("[Elder Creek]")
        |> mes("Of course, this rule applies to")
        |> mes("you as well. That sort of thing is a universal principle, after all.")
        |> set_char_var(:thai_head, 13)
        |> close()

      4 ->
        ctx
        |> mes("[Elder Creek]")
        |> mes(".....")
        |> mes("Did you think that I would accept just any meaning??")
        |> mes("Take care, you ignorant fool.")
        |> set_char_var(:thai_head, 12)
        |> close()

      _ ->
        ctx
    end
  end

  defp request_advice(ctx) do
    {ctx, problem} =
      ctx
      |> mes("[Elder Creek]")
      |> mes("I see. I have been trying to help")
      |> mes("other people who need advice in")
      |> mes("order to improve their lives.")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("Since you need my advice")
      |> mes("as well, I will try to")
      |> mes("impart my wisdom in a")
      |> mes("way that you will understand.")
      |> next()
      |> mes("[Elder Creek]")
      |> mes("Now, tell me what is bothering right now.")
      |> next()
      |> select([
        "Boy/girlfriend issue.",
        "Financial problem.",
        "Bored to death.",
        "Career issue.",
        "I want money.",
        "Give me items, old man."
      ])

    give_quest_advice(ctx, problem)
  end

  defp quest_boredom_advice(ctx) do
    ctx
    |> mes("[Elder Creek]")
    |> mes("Yes, we always need to be")
    |> mes("entertained. But...it")
    |> mes("seems you may not be satisfied with anything.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("It's all about the various tastes")
    |> mes("and interests people will have.")
    |> mes("Things other people enjoy might not")
    |> mes("displease you. Also, if your")
    |> mes("mind is unwilling to be happy,")
    |> mes("you will not enjoy life.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Here's an example of having")
    |> mes("the right frame of mind.")
    |> mes("Let's say we're cleaning")
    |> mes("the street for the town,")
    |> mes("which can be hard, grueling work...")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("You're always covered in dust.")
    |> mes("In the summer, your body is")
    |> mes("sticky with sweat...")
    |> mes("In the winter, you'll be")
    |> mes("be out in the freezing cold...")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("However, even so, it will be different to someone with a different perspective.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Ideally, we should try")
    |> mes("to find joy in making")
    |> mes("other people happy.")
    |> mes("By cleaning the street, we can")
    |> mes("give others a reason to smile.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Tourists passing through the street")
    |> mes("can enjoy its cleanliness...")
    |> mes("Overall, it makes the entire community look good.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("If your parents see you cleaning")
    |> mes("the street, they will be proud of")
    |> mes("their child.")
    |> mes("...But now, I think I'm beginning to make no sense.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Oh well, I apologize.")
    |> mes("Just try to think positively.")
    |> mes("With the right attitude, eventually you will find something to enjoy.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Haha~ I can see you're just")
    |> mes("clicking the 'next' button on these")
    |> mes("windows, because you're sick and tired of this NPC conversation.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("....anyway, that is all.")
    |> mes("I hope you will be happy")
    |> mes("with my wise advice.")
    |> close()
    |> set_char_var(:thai_head, 14)
  end

  defp reject_demands(ctx) do
    ctx
    |> mes("[Elder Creek]")
    |> mes("You rascal!")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Get out of my sight immediately! I don't talk to trash!")
  end

  defp give_quest_advice(ctx, 1) do
    give_advice(ctx, 1) |> set_char_var(:thai_head, 14)
  end

  defp give_quest_advice(ctx, 2) do
    give_advice(ctx, 2) |> set_char_var(:thai_head, 14)
  end

  defp give_quest_advice(ctx, 3) do
    quest_boredom_advice(ctx)
  end

  defp give_quest_advice(ctx, 4) do
    give_advice(ctx, 4) |> set_char_var(:thai_head, 14)
  end

  defp give_quest_advice(ctx, 5) do
    ctx
    |> mes("[Elder Creek]")
    |> mes("....")
    |> mes("I see, you chose the wrong answer in the first place.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("I believe this will be a lesson to be more honest with yourself.")
    |> mes("Choose the right answer next time!")
    |> close()
  end

  defp give_quest_advice(ctx, 6) do
    reject_demands(ctx) |> set_char_var(:thai_head, 12) |> close()
  end

  defp give_quest_advice(ctx, _) do
    ctx
  end

  defp give_advice(ctx, 1) do
    ctx
    |> mes("[Elder Creek]")
    |> mes("I'm envious of you! Still, young")
    |> mes("folk like you are lucky to")
    |> mes("have such problems...sadly,")
    |> mes("no one but yourself can really")
    |> mes("help you in those kinds of")
    |> mes("situations...")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("However, the advice I can give you")
    |> mes("is this: Be honest with your")
    |> mes("beloved. One lie leads to")
    |> mes("another lie in no time.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("If you treat the person you love")
    |> mes("as special to you, that person")
    |> mes("will eventually come to")
    |> mes("understand your feelings...")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("And, remember this...")
    |> mes("Everyone has a different way of showing that they love someone.")
    |> mes("So...don't be discouraged if your feelings aren't returned.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("But still, I believe being honest")
    |> mes("is the best way to gain your")
    |> mes("true love.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("....well, that is all I can tell")
    |> mes("you. I hope you will be happy")
    |> mes("with that nugget of wisdom.")
    |> close()
  end

  defp give_advice(ctx, 2) do
    ctx
    |> mes("[Elder Creek]")
    |> mes("...yes, everybody has their own")
    |> mes("financial problems. However, think of it in this way:")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Money is important to make")
    |> mes("a living, but it's not what life is all about.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Some may have the life goal of")
    |> mes("making fortunes, but I don't think it's the happiest way of living.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("As you see, there are powerful")
    |> mes("people in this world who can control our lives. But oftentimes...")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("They are too greedy to be in that")
    |> mes("position and they don't have")
    |> mes("their priorities straight.")
    |> mes("Instead of improving the world, they use their power to only help themselves.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("If I were them, I wouldn't want to")
    |> mes("rule the world in that way.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Don't you think we need somebody who can change this world??")
    |> next()
    |> mes("[Elder Creek]")
    |> mes(".....I apologize for being short")
    |> mes("tempered. I just wanted to let")
    |> mes("you know that money is not everything. But, it is something you need to live.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("I'm aware that greedy people")
    |> mes("ridicule this belief, saying")
    |> mes("that it is a poor man's effort")
    |> mes("to protect his pride.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("But, I still believe I am right.")
    |> mes("After all...I am a Sage.")
    |> mes("I hope you will be happy with my wise advice.")
    |> close()
  end

  defp give_advice(ctx, 3) do
    ctx
    |> mes("[Elder Creek]")
    |> mes("Yes, we always need to be")
    |> mes("entertained. But...it seems")
    |> mes("you may not be satisfied")
    |> mes("with anything.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("It's all about the various tastes")
    |> mes("and interests people will have.")
    |> mes("Things other people enjoy might")
    |> mes("displease you. Also, if your")
    |> mes("mind is unwilling to be happy,")
    |> mes("you will not enjoy life.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Here's an example of having")
    |> mes("the right frame of mind.")
    |> mes("Let's say we're cleaning")
    |> mes("the street for the town,")
    |> mes("which can be hard, grueling work...")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("You're always covered in dust.")
    |> mes("In the summer, your body is")
    |> mes("sticky with sweat...")
    |> mes("In the winter, you'll be")
    |> mes("be out in the freezing cold...")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("However, even so, it will be different to someone with a different perspective.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Ideally, we should try")
    |> mes("to find joy in making")
    |> mes("other people happy.")
    |> mes("By cleaning the street, we can")
    |> mes("give others a reason to smile.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Tourists passing through the")
    |> mes("street can enjoy its")
    |> mes("cleanliness...")
    |> mes("Overall, it makes the entire community look good.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("If your parents see you cleaning")
    |> mes("the street, they will be proud of")
    |> mes("their child.")
    |> mes("...But now, I think I'm beginning to make no sense.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Oh well, I apologize.")
    |> mes("Just try to think positively.")
    |> mes("With the right attitude, eventually you will find something to enjoy.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Haha~ I can see you're just")
    |> mes("clicking the 'next' button on")
    |> mes("these windows, because you're sick and tired of this NPC conversation.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("....anyway, that is all.")
    |> mes("I hope you will be happy")
    |> mes("with my wise advice.")
    |> close()
  end

  defp give_advice(ctx, 4) do
    ctx
    |> mes("[Elder Creek]")
    |> mes("That's an agonizing thought for every young person.")
    |> mes("But you have a lot time to think about what you want to do in the future.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Experience more in many different")
    |> mes("places, and read as many books")
    |> mes("as you can. Focus on broadening your perspective.")
    |> next()
    |> mes("[Elder Creek]")
    |> mes("Then, you will realize what you really want to do.")
    |> mes("....that's all I can say.")
    |> mes("I hope you will be happy with my wise advice.")
    |> close()
  end

  defp give_advice(ctx, 5) do
    reject_demands(ctx) |> close() |> warp("comodo", 196, 255)
  end

  defp give_advice(ctx, _) do
    ctx
  end
end

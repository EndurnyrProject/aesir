defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Iromo do
  @moduledoc """
  Iromo is a reclusive boy whose quest encourages him to explore the world.

  ## Behavior

  - Advances his quest through stories, food, and a monster hunt, awarding experience.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta_in",
        x: 131,
        y: 95,
        dir: 5,
        sprite: 706,
        name: "Iromo",
        scope: :shared,
        unique_name: "Iromo#ep3_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ep13_2_hiki, 0) == 13 ->
        dream_of_the_world(ctx)

      get_char_var(ctx, :ep13_2_hiki, 0) == 12 ->
        share_adventures(ctx)

      get_char_var(ctx, :ep13_2_hiki, 0) == 11 and get_char_var(ctx, :friendship, 0) > 14 ->
        share_friendship(ctx)

      get_char_var(ctx, :ep13_2_hiki, 0) == 11 ->
        reluctant_friend(ctx)

      get_char_var(ctx, :ep13_2_hiki, 0) == 10 ->
        after_friendship_wait(ctx)

      get_char_var(ctx, :ep13_2_hiki, 0) == 9 and get_char_var(ctx, :lhz_rekenber, 0) > 21 ->
        share_sibling_story(ctx)

      get_char_var(ctx, :ep13_2_hiki, 0) == 8 or get_char_var(ctx, :ep13_2_hiki, 0) == 9 ->
        ask_about_siblings(ctx)

      get_char_var(ctx, :ep13_2_hiki, 0) == 7 ->
        after_cat_hunt(ctx)

      get_char_var(ctx, :ep13_2_hiki, 0) == 6 and count_item(ctx, 528) > 0 and
          count_item(ctx, 501) > 0 ->
        deliver_snacks(ctx)

      get_char_var(ctx, :ep13_2_hiki, 0) == 3 or get_char_var(ctx, :ep13_2_hiki, 0) == 4 or
        get_char_var(ctx, :ep13_2_hiki, 0) == 5 or get_char_var(ctx, :ep13_2_hiki, 0) == 5 ->
        stay_indoors(ctx)

      get_char_var(ctx, :ep13_2_hiki, 0) == 1 or get_char_var(ctx, :ep13_2_hiki, 0) == 2 ->
        discuss_going_out(ctx)

      true ->
        quiet_greeting(ctx)
    end
  end

  defp dream_of_the_world(ctx) do
    ctx
    |> mes("[Iromo]")
    |> mes("But... this world is...")
    |> mes("What a big world... Not just humans...")
    |> mes("Other lifeforms just like us...")
    |> mes("Where could they be?...")
    |> next()
    |> mes("[Iromo]")
    |> mes("...Their lives.. and...")
    |> mes("Their kingdom... and land...")
    |> mes("Where could they be...")
    |> next()
    |> mes("[Iromo]")
    |> mes("If they exist, that'd be great...")
    |> mes("No... they must exist...")
    |> mes("I wish one day... one day I can go there...")
    |> close()
  end

  defp share_adventures(ctx) do
    ctx =
      ctx
      |> mes("[Iromo]")
      |> mes("If it's too painful...")
      |> mes("It's better if I don't...")
      |> next()
      |> mes("-Silent pause-")
      |> next()

    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("-", char_name(ctx, 0)), " starts to speak-"))
      |> mes("-And tells him of the journeys-")
      |> mes("-Adventures, joy, sorrow, and loss-")
      |> mes("-One by one to the boy-")
      |> next()
      |> mes("-Fighting monsters, and winning-")
      |> mes("-Coming across many people, and-")
      |> mes("-leaving them, and tells of many other things-")
      |> mes("-As much as possible, to the boy.-")
      |> next()
      |> mes("-Much has happened, and-")
      |> mes("-There were many dangers, but in the end-")
      |> mes("-Happy things outweighs the bad,-")
      |> mes("-What I have received is more than what I have lost.-")
      |> mes("-I try hard to convey this message to Iromo.-")
      |> next()
      |> mes("[Iromo]")
      |> mes("...")
      |> next()
      |> mes("[Iromo]")
      |> mes("...So in the end...")
      |> mes("You just want me... to go outside...")
      |> mes("Am I right...")
      |> next()
      |> select(["It's true, you'll get more than you pay."])

    ctx =
      ctx
      |> mes("[Iromo]")
      |> mes("...")
      |> next()
      |> mes("[Iromo]")
      |> mes("...But now... I am not going outside.")
      |> mes("I am still afraid...")
      |> next()
      |> mes("[Iromo]")
      |> mes("Even if I don't go out right now,")
      |> mes("I will still... make an effort to do so.")
      |> mes("One day, I will surely become...")
      |> mes("..An adventurer... and do many, many things.")
      |> next()
      |> set_char_var(:ep13_2_hiki, 13)
      |> completequest(10089)

    ctx
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 8000, else: 80000), 0)
    |> mes("[Iromo]")
    |> mes("The world is big, there are many things...")
    |> mes("I have not seen yet. Yes... I want to...")
    |> mes("...see them all.")
    |> close()
  end

  defp share_friendship(ctx) do
    ctx =
      ctx
      |> mes("[Iromo]")
      |> mes("To go on an adventure with my friends,")
      |> mes("I would still rather stay here.")
      |> mes("I would still rather stay here quietly and safely.")
      |> next()
      |> mes("[Iromo]")
      |> mes("Alright...go away. I know...")
      |> mes("I know what you want to say...what an annoyance...")
      |> next()
      |> mes("-You don't give up, and continue to-")
      |> mes("-tell of the stories-")
      |> mes("-shared with friends.-")
      |> mes("-You tell of the truth.-")
      |> next()
      |> mes("-Someone met long ago,-")
      |> mes("-Suddenly leaves,-")
      |> mes("-and finally reunited, but-")
      |> mes("-because of the cruel fate-")
      |> mes("-he dies in this tragedy.-")
      |> mes("-In the end, it's all a tragedy...-")
      |> next()
      |> mes("-But you emphasize -")
      |> mes("-Even though the ending is tragic,-")
      |> mes("-A beautiful friendship-")
      |> mes("-Will not disappear because of that.-")
      |> next()
      |> mes("[Iromo]")
      |> mes("...")
      |> next()
      |> mes("[Iromo]")
      |> mes("...Thank you for telling me...")
      |> mes("They are great friends...")
      |> next()

    ctx =
      if sex(ctx) == 0 do
        ctx
        |> mes("[Iromo]")
        |> mes("...And? ...What do you...")
        |> mes("Want to say to me this time...")
        |> mes("You've told me many stories...")
        |> mes("...How about one of your own?")
        |> next()
      else
        ctx
        |> mes("[Iromo]")
        |> mes("...And? ...What do you...")
        |> mes("Want to say to me this time...")
        |> mes("You've told me many stories...")
        |> mes("...How about one of your own?")
        |> next()
      end

    {ctx, _} = select(ctx, ["Friendship cannot be forgotten."])

    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("...")
      |> next()
      |> select(["To have that kind of friends and that kind of friendship..."])

    {ctx, _} = select(ctx, ["You need to get out of your house and see the world."])

    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("Though you changed a story... but...")
      |> mes("You're still talking about this...")
      |> next()
      |> select(["To be honest, the other kids miss you."])

    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("...Him? ...Miss me? That's...")
      |> mes("Something from a long time ago...")
      |> next()
      |> select(["There are many things you don't know yet."])

    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("...")
      |> next()
      |> select(["Don't you think it's a waste to stay home?"])

    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("...")
      |> next()
      |> select(["In order to find safety, you would give up fun adventures?"])

    {ctx, _} = select(ctx, ["That's too bad. Change is a very fun thing."])

    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("...Change...")
      |> mes("Is fun...?")
      |> next()
      |> select(["Outside this city and this kingdom, there is a bigger world."])

    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("...")
      |> next()
      |> select(["Since it's so big, there are many fun things."])

    ctx
    |> mes("[Iromo]")
    |> mes("Really...? Other than Alberta, and Rune-Midgarts...?")
    |> mes("There are other places...?")
    |> next()
    |> set_char_var(:ep13_2_hiki, 12)
    |> changequest(10088, 10089)
    |> mes("[Iromo]")
    |> mes("But... there will also be many troubles...")
    |> mes("Isn't that true... I can't relax...")
    |> mes("I... don't like those...")
    |> close()
  end

  defp reluctant_friend(ctx) do
    ctx
    |> mes("[Iromo]")
    |> mes("To go on an adventure with my friends,")
    |> mes("I would still rather stay here.")
    |> mes("I would still rather stay here quietly and safely.")
    |> next()
    |> mes("[Iromo]")
    |> mes("Alright... go away. I know...")
    |> mes("I know what you want to say... what an annoyance...")
    |> close()
  end

  defp after_friendship_wait(ctx) do
    ctx = set_local(ctx, :cooltime, checkquest(ctx, 10087, :playtime))

    if get_local(ctx, :cooltime, 0) == 2 do
      ctx =
        ctx
        |> mes("[Iromo]")
        |> mes("...You really are annoying...")
        |> mes("What exactly do you want from me...?")
        |> next()
        |> mes("[Iromo]")
        |> mes("A long time ago... I had a friend just like you.")
        |> mes("I met him when I went out to play...")
        |> mes("But...")
        |> mes("He must've forgotten all about me...")
        |> next()
        |> set_char_var(:ep13_2_hiki, 11)
        |> changequest(10087, 10088)

      ctx
      |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 6700, else: 67000), 0)
      |> mes("[Iromo]")
      |> mes("Nevermind... it's not unexpected...")
      |> mes("To go on an adventure with my friends,")
      |> mes("I would still rather stay here.")
      |> mes("I would still rather stay here quietly and safely.")
      |> close()
    else
      ctx
      |> mes("[Iromo]")
      |> mes("...What... Right now, I...")
      |> mes("I don't want to... hear anything...")
      |> mes("Go away...")
      |> close()
    end
  end

  defp share_sibling_story(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("...What is it... this time...?")
      |> next()
      |> select(["A story about a pair of siblings."])

    {ctx, _} =
      ctx
      |> mes("-Tell him about Kazien and Lyozien.-")
      |> mes("-Because of ill fate,-")
      |> mes("-They were born to do illegal tasks-")
      |> mes("-But the innocent Lyozien-")
      |> mes("-Trusted his brother...-")
      |> next()
      |> mes("-And even though Kazien has become-")
      |> mes("-a criminal, but as an older brother-")
      |> mes("-He hopes to take good care of his younger brother.-")
      |> next()
      |> mes("-This is a story from far away,-")
      |> mes("-But because you have seen it with your own eyes,-")
      |> mes("-You can clearly express-")
      |> mes("-Your feelings.-")
      |> next()
      |> mes("-This story must be able to-")
      |> mes("-Stir up the interest of-")
      |> mes("-Iromo, who has always wanted a brother.-")
      |> next()
      |> mes("[Iromo]")
      |> mes("I see...They were great siblings...")
      |> mes("Tragic...but also beautiful.")
      |> mes("If only...I can be the protagonist...")
      |> mes("..in such a story...")
      |> next()
      |> mes("[Iromo]")
      |> mes("...But...I'm an only child...")
      |> mes("...So there's nothing I can do...")
      |> next()
      |> select(["You don't need to be related by blood to be brothers."])

    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("...")
      |> next()
      |> select(["You can find make of these brothers outside."])

    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("...Outside?...")
      |> next()
      |> select(["But if you stay at home, nothing will change."])

    ctx =
      ctx
      |> mes("[Iromo]")
      |> mes("...")
      |> next()
      |> mes("[Iromo]")
      |> mes("...What... So it's all my fault...")
      |> mes("What you want to say...")
      |> mes("...is always the same...")
      |> mes("Get out... I'm not in the mood...")
      |> next()
      |> set_char_var(:ep13_2_hiki, 10)
      |> changequest(10086, 10087)

    ctx
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 5700, else: 57000), 0)
    |> mes("[Iromo]")
    |> mes("...I'm not in a good mood, get out...")
    |> close()
  end

  defp ask_about_siblings(ctx) do
    ctx = set_local(ctx, :cooltime, checkquest(ctx, 10085, :playtime))

    if get_local(ctx, :cooltime, 0) == 2 do
      ctx =
        ctx
        |> mes("[Iromo]")
        |> mes("You never give up, don't you?")
        |> mes("What are you trying to say?")
        |> next()
        |> mes("[Iromo]")
        |> mes("It is frustrating. But...")
        |> mes("Why do you care about me so much?")
        |> next()

      ctx =
        if sex(ctx) == 0 do
          ctx
          |> mes("[Iromo]")
          |> mes("Really, its not that bad...")
          |> mes("I wish I could have a sister like you.")
          |> next()
        else
          ctx
          |> mes("[Iromo]")
          |> mes("Really, its not that bad...")
          |> mes("I wish I could have a brother like you.")
          |> next()
        end

      ctx
      |> mes("[Iromo]")
      |> mes("Do you have any stories about siblings?")
      |> next()
      |> set_char_var(:ep13_2_hiki, 9)
      |> changequest(10085, 10086)
      |> mes("[Iromo]")
      |> mes("What? Anything to say?")
      |> mes("Seriously!")
      |> mes("Just leave me alone.")
      |> close()
    else
      ctx
      |> mes("[Iromo]")
      |> mes("Thank you for caring...")
      |> mes("But that is ok...No thanks...")
      |> close()
    end
  end

  defp after_cat_hunt(ctx) do
    ctx = set_local(ctx, :goyang, checkquest(ctx, 10084, :hunting))

    if get_local(ctx, :goyang, 0) == 2 do
      ctx =
        ctx
        |> mes("[Iromo]")
        |> mes("Oh, you made the furious cat")
        |> mes("go away from the village?")
        |> mes("...Oh, you did..Thanks!")
        |> next()
        |> mes("[Iromo]")
        |> mes("But, I am still scared of")
        |> mes("being outside.")
        |> mes("I would rather stay at home.")
        |> next()
        |> set_char_var(:ep13_2_hiki, 8)
        |> changequest(10084, 10085)

      ctx
      |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 4700, else: 47000), 0)
      |> mes("[Iromo]")
      |> mes("Thank you for being helpful.")
      |> mes("But, no thanks.")
      |> close()
    else
      ctx
      |> mes("[Iromo]")
      |> mes("If I go out, I will see the scary cat.")
      |> next()
      |> mes("[Iromo]")
      |> mes("He will bite me..and")
      |> mes("scratch me again.")
      |> mes("I should stay at home.")
      |> close()
    end
  end

  defp deliver_snacks(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Iromo]")
      |> mes("...Huh? This smell...")
      |> mes("This is the one I like the most.")
      |> mes("Ha Ha!")
      |> next()
      |> mes("[Iromo]")
      |> mes("But..my mom is beside me.")
      |> mes("(Wink, Wink)")
      |> next()
      |> mes("[Iromo]")
      |> mes("...Thanks! I need to hide this.")
      |> mes("Anyway, thank you!")
      |> next()
      |> mes("[Iromo]")
      |> mes("It smells so good.")
      |> next()
      |> mes("[Iromo]")
      |> mes("Huh?? If I go out,")
      |> mes("then can I get these things?")
      |> next()
      |> mes("[Iromo]")
      |> mes("......")
      |> next()
      |> mes("[Iromo]")
      |> mes("But... I'm scared...")
      |> next()
      |> mes("[Iromo]")
      |> mes("I am scared. If I go out...")
      |> mes("No, I don't want to get hurt again.")
      |> next()
      |> select(["Again?"])

    ctx =
      ctx
      |> mes("[Iromo]")
      |> mes("...there is a weird cat that can walk on two feet.")
      |> mes("I like cats so I approached him.")
      |> mes("Then suddenly he scratched and bit me.")
      |> next()
      |> delitem(528, 1)
      |> delitem(501, 1)
      |> set_char_var(:ep13_2_hiki, 7)
      |> changequest(10083, 10084)

    ctx
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 3750, else: 37500), 0)
    |> mes("[Iromo]")
    |> mes("I don't want to see the cat again.")
    |> mes("If I go out, I will see him. It is scary.")
    |> close()
  end

  defp stay_indoors(ctx) do
    ctx
    |> mes("[Iromo]")
    |> mes("... I don't like being outside of the village.")
    |> mes("Being inside of the house is the best.")
    |> close()
  end

  defp discuss_going_out(ctx) do
    ctx =
      ctx
      |> mes("[Iromo]")
      |> mes("Mother told me that")
      |> mes("I should go out and play")
      |> mes("with friends. But I don't")
      |> mes("want to go out with them.")
      |> next()
      |> mes("[Iromo]")
      |> mes("It is little bit inconvenient that")
      |> mes("I can't get delicious food")
      |> mes("that grows outside of the village.")
      |> mes("I can stand it.")
      |> next()

    ctx =
      if get_char_var(ctx, :ep13_2_hiki, 0) == 1 do
        ctx |> set_char_var(:ep13_2_hiki, 2) |> changequest(10079, 10080)
      else
        ctx
      end

    ctx
    |> mes("[Iromo]")
    |> mes("But, I can have other food")
    |> mes("instead of the outside food.")
    |> mes("That way I don't have to go out.")
    |> close()
  end

  defp quiet_greeting(ctx) do
    ctx
    |> mes("[Iromo]")
    |> mes("......")
    |> next()
    |> mes("[Iromo]")
    |> mes("I like my house and my room.")
    |> mes("I don't want to go out.")
    |> close()
  end
end

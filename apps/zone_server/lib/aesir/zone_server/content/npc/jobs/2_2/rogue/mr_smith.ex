defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.MrSmith do
  @moduledoc """
  Mr. Smith collects the Rogue Guild application fee and assigns candidates their next mentor.

  ## Behavior

  - Gives candidates who passed Markie's quiz one of three random item lists, or, in a foul mood,
    a long list of seventeen items plus the fee.
  - Takes the fee and items once the candidate brings everything and advances the quest.
  - Sends candidates who paid a regular list to a random mentor, each with a password; those who
    paid the long list go to Hermanthorn Jr. and get a Worn Out Page.
  - Reminds candidates where to go and turns away those who have not seen Markie yet.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 376,
        y: 23,
        dir: 1,
        sprite: 57,
        name: "Mr. Smith",
        scope: :shared,
        unique_name: "Mr. Smith#rg"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @full_fee_items [
    915,
    713,
    1002,
    953,
    507,
    919,
    715,
    913,
    904,
    942,
    528,
    914,
    705,
    916,
    917,
    908,
    945
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    rogue_q = get_char_var(ctx, :ROGUE_Q, 0)

    cond do
      rogue_q == 2 -> assign_application_fee(ctx)
      rogue_q < 2 -> lose_count(ctx)
      rogue_q > 2 -> continue_application(ctx, rogue_q)
      true -> request_fee(ctx, [0, 0, 0, 0], 0)
    end
  end

  defp assign_application_fee(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Smith]")
      |> mes("Welcome to")
      |> mes("the Rogue guild.")
      |> mes("From here on, I will")
      |> mes("verify your qualification.")
      |> next()
      |> mes("[Mr. Smith]")
      |> mes("Before we get started,")
      |> mes("I want you to know")
      |> mes("about something...")
      |> next()
      |> mes("[Mr. Smith]")
      |> mes(
        "All new Rogues are required to pay an application fee, so I hope you take care of that first."
      )
      |> next()
      |> mes("[Mr. Smith]")
      |> mes(
        "What you have to understand is that the Rogue Guild does a lot of business, ^666666sometimes illegally^000000, that needs financial backup."
      )
      |> next()

    item_need = Enum.random(1..15)

    cond do
      item_need > 0 and item_need < 6 ->
        request_fee(
          ctx,
          ["10 Skel-bone", "6 Blue Herb", "10 Decayed Nail", "10 Horrendous Mouth"],
          3
        )

      item_need > 5 and item_need < 11 ->
        request_fee(ctx, ["10 Green Herb", "10 Crab Shell", "10 Snake Scale", "10 Garlet"], 4)

      item_need > 10 and item_need < 15 ->
        request_fee(
          ctx,
          ["10 Yellow Herb", "10 Shell", "10 Grasshopper's Leg", "10 Bear's Footskin"],
          5
        )

      item_need == 15 ->
        rant_about_job(ctx)

      true ->
        request_fee(ctx, [0, 0, 0, 0], 0)
    end
  end

  defp request_fee(ctx, [first, second, third, fourth], next_step) do
    ctx
    |> mes("[Mr. Smith]")
    |> mes("First, the")
    |> mes("application fee:")
    |> mes("^FF000010,000 zeny^000000.")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("We also need")
    |> mes("you to bring")
    |> mes("^FF0000#{first}^000000,")
    |> mes("^FF0000#{second}^000000,")
    |> mes("^FF0000#{third}^000000 and")
    |> mes("^FF0000#{fourth}^000000.")
    |> set_char_var(:ROGUE_Q, next_step)
    |> changequest(2017, fee_quest(next_step))
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Hmm...?")
    |> mes("What was that?")
    |> mes("Did you just say that")
    |> mes("you're willing to donate")
    |> mes("more for the guild?")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("That sounds sweet,")
    |> mes("I appreciate that.")
    |> mes("But come back when")
    |> mes("you're ready.")
    |> close()
  end

  defp fee_quest(step) when step == 3, do: 2018
  defp fee_quest(step) when step == 4, do: 2019
  defp fee_quest(_step), do: 2020

  defp rant_about_job(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Mr. Smith]")
    |> mes("I will let you know...")
    |> set_char_var(:ROGUE_Q, 6)
    |> changequest(2017, 2021)
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("I will let you know......")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("I will let you know........")
    |> mes("By the way.....")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Oh man...")
    |> mes("This is...")
    |> mes("Damn...")
    |> mes("Annoying!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("...")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Today, I'm in a pissed off mood, ya' know why?! I haven't collected any bills! God! Idiot Thieves coming at me all the time, wanting to become Rogues!"
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Jesus! Now I understand why our leader told us that working as customer support sucks."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "That god damn guild master assigned me to this shitty job. I'm better than this F$@king job!"
    )
    |> mapannounce(
      "in_rogue",
      "That god damn guild master assigned me to this shitty job! That Bastard!",
      1
    )
    |> shout(
      "That bastard should go to F$@king hell, I'm gonna kick that mother F$@kers ass! F#%k F#%k F#%k !!!"
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> shout("That dipshit who just tried to change his job, the one before you...")
    |> shout("You know what the f#@k he talked to me about?!?")
    |> shout("F#$@%#$*#$%@#$!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> shout(
      "What the--?! What's with this chat filter?! Stop #*!@$ing me! you stupid F#$%*! Let me talk!!!"
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> shout("What the f#@k you looking at...? #{name}? That's your name!?")
    |> mes(" ")
    |> mes("[#{name}]")
    |> mes("Umm...")
    |> mes("Sir...?")
    |> mes("I didn't mean to make you upset. I just came here to so I could become a Rogue.")
    |> next()
    |> mes("[Mr. Smith]")
    |> shout("Holy shit on a stick, what the f#$k was I just f!#king talking about, you moron!")
    |> next()
    |> mes("[Mr. Smith]")
    |> shout("Just leave me alone! Just leave alone! Just leave me alone!")
    |> next()
    |> mes("[Mr. Smith]")
    |> shout("Do whatever you want, okay? Just do whatever the F$!!K you want...!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Your application fee... ^FF000010,000 zeny^000000!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("^FF00005 Crysalis^000000!")
    |> mes("^FF00005 Empty Bottle^000000!")
    |> mes("^FF00005 Iron Ore^000000!")
    |> mes("^FF00005 Stone Heart^000000!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("^FF00005 Red Herb^000000!")
    |> mes("^FF00005 Animal Skin^000000!!")
    |> mes("^FF00005 Yellow Gemstone^000000!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("^FF00005 Tooth of Bat^000000!")
    |> mes("^FF00005 Scorpion Tail^000000!!")
    |> mes("^FF00005 Yoyo Tail^000000!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("^FF00005 Monster's Feed^000000!")
    |> mes("^FF00005 Fluff^000000!!")
    |> mes("^FF00005 Clover^000000!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("^FF00005 Feather of Birds^000000!")
    |> mes("^FF00005 Talon^000000!!")
    |> mes("^FF00005 Spawn^000000!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Don't even think about coming back until you've got all those or I'll kill you where you stand."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("What the F$@k? Did you just say I'm annoying you? Shut up, you ungrateful prick!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("I just added ^FF000010 Raccoon Leaf^000000 to the list. You better get it!")
    |> next()
    |> mes("[Mr. Smith]")
    |> shout(
      "F%$#*&#@$%#@$@#$%@$%&*k! Haven't you ever thought about how hard it would be to be an NPC!?!"
    )
    |> close()
  end

  defp shout(ctx, line) do
    ctx
    |> mes(line)
    |> mapannounce("in_rogue", line, 1)
  end

  defp lose_count(ctx) do
    ctx
    |> mes("[Mr. Smith]")
    |> mes(
      "Three thousand, two hundred seventy two. Three thousand, two hundred seventy three. Three thousand, two hundred seventy four..."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Uhh...")
    |> mes("Headache...")
    |> mes("This is too much")
    |> mes("zeny to count.")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Uh...?")
    |> mes(
      "What are you doing here? If you're going to talk about the job change, you need to speak to the other guy first."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("...Shit!")
    |> mes("I lost count!")
    |> close()
  end

  defp continue_application(ctx, rogue_q) do
    cond do
      rogue_q == 3 -> check_items(ctx, [{510, 6}, {932, 10}, {957, 10}, {958, 10}])
      rogue_q == 4 -> check_items(ctx, [{511, 10}, {910, 10}, {926, 10}, {964, 10}])
      rogue_q == 5 -> check_items(ctx, [{508, 10}, {948, 10}, {935, 10}, {940, 10}])
      rogue_q == 6 -> check_full_fee(ctx)
      rogue_q == 7 -> assign_mentor(ctx)
      rogue_q == 8 -> send_to_hermanthorn(ctx)
      rogue_q == 9 -> remind_aragham(ctx)
      rogue_q == 10 -> remind_antonio(ctx)
      rogue_q == 11 -> remind_hollgrehenn(ctx)
      rogue_q > 11 -> send_to_training(ctx)
      true -> request_fee(ctx, [0, 0, 0, 0], 0)
    end
  end

  defp check_items(ctx, requirements) do
    has_everything? =
      zeny(ctx) > 9999 and
        Enum.all?(requirements, fn {item_id, amount} -> count_item(ctx, item_id) >= amount end)

    if has_everything? do
      collect_items(ctx, requirements)
    else
      repeat_requirements(ctx, requirements)
    end
  end

  defp collect_items(ctx, requirements) do
    [first, second, third, fourth] = Enum.map(requirements, &describe_item/1)

    ctx =
      ctx
      |> mes("[Mr. Smith]")
      |> mes(
        "Okay, we've got the application fee, ^FF000010,000 zeny^000000, #{first}, #{second}, #{third} and #{fourth}..."
      )
      |> pay_zeny(10_000)

    requirements
    |> Enum.reduce(ctx, fn {item_id, amount}, ctx -> delitem(ctx, item_id, amount) end)
    |> set_char_var(:ROGUE_Q, 7)
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Great, great...")
    |> mes("I think you")
    |> mes("brought everything.")
    |> set_char_var(:ROGUE_Q, 7)
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Alright, wait just a moment while")
    |> mes("I prepare these things. Let's see... Your next test is...")
    |> close()
  end

  defp repeat_requirements(ctx, requirements) do
    ctx =
      ctx
      |> mes("[Mr. Smith]")
      |> mes(
        "What the f$@k!? You didn't bring all the required items?! Are you telling me that you need to check the requirements again!?"
      )
      |> next()
      |> mes("[Mr. Smith]")
      |> mes("Now listen...!")
      |> mes("Bring ^FF000010,000 zeny^000000,")
      |> mes("and the following items...")
      |> next()
      |> mes("[Mr. Smith]")

    requirements
    |> Enum.reduce(ctx, fn requirement, ctx ->
      mes(ctx, "^FF0000 #{describe_item(requirement)}^000000,")
    end)
    |> mes("You got it this time?")
    |> close()
  end

  defp describe_item({item_id, amount}), do: "#{amount} #{Rathena.getitemname(item_id)}"

  defp check_full_fee(ctx) do
    has_everything? =
      zeny(ctx) > 9999 and Enum.all?(@full_fee_items, &(count_item(ctx, &1) > 4))

    if has_everything?, do: collect_full_fee(ctx), else: repeat_full_fee(ctx)
  end

  defp collect_full_fee(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Smith]")
      |> mes("Ummm...let's see...")
      |> pay_zeny(10_000)

    @full_fee_items
    |> Enum.reduce(ctx, &delitem(&2, &1, 5))
    |> set_char_var(:ROGUE_Q, 8)
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Wow, you've brought each and every single thing I asked you to. Good work... I salute you."
    )
    |> next()
    |> mes("^CCCCCC- Middle Finger -^000000'")
    |> mes("*Grins*")
    |> set_char_var(:ROGUE_Q, 8)
    |> changequest(2021, 2025)
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Since you showed such great effort, I'm going to write a recommendation letter for you. I usually don't do that, you know."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "But I'm sure you'll be a great asset to the Rogue Guild. Hmm, I don't have a blank piece of paper right now, so take this instead..."
    )
    |> give_item(1097, 1)
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("*Sigh...*")
    |> mes(
      "I know, I know. I'm supposed to control myself in the work place. Getting enraged is a bad habit..."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("*Mumble mumble...*")
    |> mes("How was I... *Mumble...*")
    |> mes("How did... I remember...")
    |> mes("*Sigh* It was all because of my bad temper!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Wah....!!!")
    |> next()
    |> mes("^3355FFIt might be a better")
    |> mes("idea to come back later.^000000")
    |> close()
  end

  defp repeat_full_fee(ctx) do
    ctx
    |> mes("[Mr. Smith]")
    |> mes("Listen this time!")
    |> mes("Application fee:")
    |> mes("^FF000010000 zeny^000000,")
    |> mes("^FF00005 Crysalis^000000!")
    |> mes("^FF00005 Empty Bottle^000000!")
    |> mes("^FF00005 Iron Ore^000000!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("^FF00005 Stone Heart^000000!!")
    |> mes("^FF00005 Red Herb^000000!")
    |> mes("^FF00005 Animal Skin^000000!!")
    |> mes("^FF00005 Yellow Gemstone^000000!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("^FF00005 Tooth of Bat^000000!")
    |> mes("^FF00005 Scorpion Tail^000000!!")
    |> mes("^FF00005 Yoyo Tail^000000!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("^FF00005 Monster's Feed^000000!")
    |> mes("^FF00005 Fluff^000000!!")
    |> mes("^FF00005 Clover^000000!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("^FF00005 Feather of Birds^000000!")
    |> mes("^FF00005 Talon^000000!!")
    |> mes("^FF00005 Spawn^000000!!")
    |> mes("^FF000010 Raccoon Leaf^000000!!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Don't even think")
    |> mes("of coming back")
    |> mes("without them!")
    |> close()
  end

  defp assign_mentor(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Smith]")
      |> mes("Let me see...")
      |> mes("Who would should")
      |> mes("I send you to...?")

    case Enum.random(1..3) do
      1 -> ctx |> set_char_var(:ROGUE_Q, 9) |> advance_fee_quest(2022) |> send_to_aragham()
      2 -> ctx |> set_char_var(:ROGUE_Q, 10) |> advance_fee_quest(2023) |> send_to_antonio()
      3 -> ctx |> set_char_var(:ROGUE_Q, 11) |> advance_fee_quest(2024) |> send_to_hollgrehenn()
      _ -> request_fee(ctx, [0, 0, 0, 0], 0)
    end
  end

  defp advance_fee_quest(ctx, mentor_quest) do
    cond do
      checkquest(ctx, 2018) != -1 -> changequest(ctx, 2018, mentor_quest)
      checkquest(ctx, 2019) != -1 -> changequest(ctx, 2019, mentor_quest)
      true -> changequest(ctx, 2020, mentor_quest)
    end
  end

  defp send_to_aragham(ctx) do
    ctx
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Right! I know")
    |> mes("just the guy~!")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Go visit Aragham Junior who lives South of the Sandarman Fortress. That area is located one field east from here."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "He's a pretty nice guy, you know. He works hard and is really good at bill collecting."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Before he joined the Rogue Guild, people have been trying to kill him for something his father did in the past. So, he became a runaway."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Well anyway, that's why he's been with us. We've been helping him hide from his enemies."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Ah, you might want to remember the password if you want to meet him. He doesn't let anybody in his house without the password."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("The password is ^0000FFAragham never hoarded upgrade items^000000.")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Well, I will wish you luck. His place isn't that far from here, so come back as soon as possible. Being swift... That is the spirit of the Rogue."
    )
    |> close()
  end

  defp send_to_antonio(ctx) do
    ctx
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Hmm...")
    |> mes("This guy might be")
    |> mes("good for you, but...")
    |> mes("He's a little dangerous.")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "I want you to meet Antonio Junior, son of Antonio the first. For some reason people have been trying to kill him because of something his father did in the past."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "He was brought up in Payon, but he's staying in an empty house near the Kokomo beach at the moment."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "I've heard lately that he's been complaining a lot about the noise outside of his house, and he fears an assassination attempt. Anyway..."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "He's kind of tense, so he throws a dagger at anyone who approaches his house. He has a violent personality."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "However, he does have magnificent business skills. And he also loves gambling. Once you get to know him, he'll take care of your Rogue training really well."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Ah, you might want to remember the password to meet him in person. The password is ^0000FFAntonio doesn't enjoy destroying upgrade items^000000."
    )
    |> close()
  end

  defp send_to_hollgrehenn(ctx) do
    ctx
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("Hmm...")
    |> mes("This guy might be")
    |> mes("good for you, but...")
    |> mes("He's a little dangerous.")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("His name is")
    |> mes("Hollgrehenn Junior,")
    |> mes("a genius at manipulation.")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "However, because of something his father did long ago, people have been trying to kill him. Because of this, he is very high strung and will throw daggers at people he doesn't trust."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Our leader has been able to get him to join our guild, and his brilliant mind has been an asset to us. Once you get to know him, he'll take care of your Rogue training really well."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Ah, you might want to remember the password to meet him in person. The password is ^0000FFMy father never hoarded upgrade items^000000."
    )
    |> close()
  end

  defp send_to_hermanthorn(ctx) do
    ctx
    |> mes("[Mr. Smith]")
    |> mes(
      "Alright... Now that I've calmed down, I can inform you of your next destination. *Whew*"
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Go and find Hermanthorn Junior, who is living near the ^0000FFthe checkpoint of Paros Lighthouse^000000, which is at the border between Morocc and Comodo."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes(
      "Ah...almost forgot, keep in mind not to mention anything about upgrading items. This is very important."
    )
    |> close()
  end

  defp remind_aragham(ctx) do
    ctx
    |> ask_forgot_where_to_go()
    |> mes(
      "Head one field East and enter the building that is South of the Sandarman Fortress to meet Aragham Junior."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("The password is ^0000FFAragham never hoarded upgrade items^000000.")
    |> close()
  end

  defp remind_antonio(ctx) do
    ctx
    |> ask_forgot_where_to_go()
    |> mes("Go to the building")
    |> mes("at Kokomo Beach,")
    |> mes("which is on the way")
    |> mes("to Comodo, to meet")
    |> mes("Antonio Junior.")
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("The password is ^0000FF'Antonio doesn't enjoy destroying upgrade items'^000000.")
    |> close()
  end

  defp remind_hollgrehenn(ctx) do
    ctx
    |> ask_forgot_where_to_go()
    |> mes(
      "Go to the field South of Sandarman Fortress, which is on the way to Morocc from here, to meet Hollgrehenn Junior."
    )
    |> next()
    |> mes("[Mr. Smith]")
    |> mes("The password is ^0000FFMy father never hoarded upgrade items^000000.")
    |> close()
  end

  defp ask_forgot_where_to_go(ctx) do
    ctx
    |> mes("[Mr. Smith]")
    |> mes("What...?")
    |> mes("Did you just")
    |> mes("say that you")
    |> mes("forgot where to go?")
    |> next()
    |> mes("[Mr. Smith]")
  end

  defp send_to_training(ctx) do
    ctx
    |> mes("[Mr. Smith]")
    |> mes("Hmmm...?")
    |> mes("Don't you have")
    |> mes("to go somewhere")
    |> mes("else to complete")
    |> mes("your Rogue training?")
    |> close()
  end
end

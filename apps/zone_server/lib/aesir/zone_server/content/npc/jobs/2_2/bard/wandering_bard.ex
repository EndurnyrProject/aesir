defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Bard.WanderingBard do
  @moduledoc """
  Lalo, the wandering bard in Comodo who guides Archers through the Bard job quest and performs
  the job change.

  ## Behavior

  - Transcendent characters and non-Archers only get flavor dialogue.
  - Sings Drums of War on request; a male Archer above Job Level 39 who liked it starts the quest.
  - Asks for a flower, reacting to each kind; an acceptable one sends the candidate to befriend
    Jack Frost in Lutie.
  - Once the candidate made friends there, gives a random six-line sing-along test that must be
    sung back without a single wrong line.
  - After passing, changes the candidate into a Bard, with a souvenir instrument when they bring
    60 trunks of one kind.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Lupus
    - Samuray22
    - L0ne_W0lf
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 226,
        y: 123,
        dir: 5,
        sprite: 741,
        name: "Wandering Bard",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @gifted_flowers [
    {629, ["Ooh! It's a Singing Flower!", "It's full of my memories..."],
     ["My friend Tchaikovsky used to like it.", "I wonder what he's doing now..."]},
    {703,
     [
       "Aah... the cute Hinelle...",
       "It doesn't have a scent but it's a very moderate cute flower."
     ],
     [
       "The leaves gave me strength when I used to fall.",
       "I really like this flower, thank you."
     ]},
    {704, ["Aloe... This is a rare flower.", "How'd you get it? Rather skilled, eh?"],
     [
       "The leaves are good and Aloe Vera is delicious, too..",
       "but it's defnitely the most beautiful when it's a flower."
     ]},
    {708,
     [
       "Ment... You can forget about all your hardships with one of these.",
       "Nice to see it in such a long time!"
     ],
     ["I heard you can make Anodyne with it...", "But that would be a slight waste.. thanks!"]},
    {709, ["Ooh, isn't this an Izidor?", "It's a dangerous yet beautiful flower..."],
     ["The deep purple charms a person.. ", "Thank you, I really like this flower."]},
    {748,
     [
       "Ooh, a Witherless Rose. The strong flower that doesn't wither.",
       "Great to give to a girlfriend."
     ],
     [
       "I wonder if it would be ok for a wanderer like me to accept it.",
       "Haha, it should be ok.. right?"
     ]},
    {749,
     [
       "Frozen Rose... you can't really call this a flower,",
       "But it is still beautiful... a clear Rose."
     ],
     [
       "You can call it a flower even though it doesn't have a scent anymore.",
       "Then I'll greatly take this."
     ]},
    {710, ["Oh, isn't this an Illusion Flower!?", "Wow, how did you obtain such a rare flower!!"],
     [
       "Than you very much, aah... I feel like heaven is in front of my eyes.",
       "What a wonderful feeling! I'm really happy!"
     ]}
  ]

  @refused_flowers [
    {712, true, ["Eh? This is just a normal flower.", "I like it... but it's not enough."],
     [
       "You can get this flower from the girl in Prontera.",
       "Please bring me a different flower."
     ]},
    {744, false, ["Oh no, you brought a Bouquet?", "You can't bring me something like this."],
     [
       "Go give this to a graduating Sage or something.",
       "Since it's great as that kind of gift... Bring a different flower."
     ]},
    {745, true,
     [
       "Oy oy... did you go to a wedding or something?",
       "What do you expect a guy to do with a Wedding Bouquet?"
     ],
     [
       "It's not me. Go give it to a lady or something.",
       "This isn't the type of flower I wanted."
     ]},
    {2207, false, ["Mmm... a Fancy Flower.", "It's nice... but this isn't good enough."],
     [
       "I like flowers that have a scent and are beautiful.",
       "I don't like fake flowers that go on top of heads."
     ]},
    {1032, true, ["...Agh, why'd you bring such a hideous thing?", "Are you thinking at all?"],
     [
       "if you were trying to be funny, it was a good attempt...",
       "but bring a normal flower now."
     ]}
  ]

  @no_flower {nil, true,
              ["Hmm? What... you didnt' bring anything.", "Didn't I ask you to bring a flower?"],
              [
                "Well... if you want to learn on your own, then so be it.",
                "Anyone can just go out and sing."
              ]}

  @immortal_hero_song [
    "There was a man",
    "who was said to be immortal.",
    "His name Jichfreid,",
    "Son of the hero Jichmunt.",
    "The evil giant Papner,",
    "Turned into a dragon and ate him."
  ]

  @proud_merchant_song [
    "A Merchant without money or equipment,",
    "a Merchant that couldn't sell anything.",
    "But he was too proud to beg.",
    "So he gathered some money selling items.",
    "At first he only sold Red Potions.",
    "Some say he sold Sweet Potatoes, too."
  ]

  @goddess_eden_song [
    "All Gods never age.",
    "The ever so Beautiful Goddess Eden,",
    "Beautiful and graceful Goddess Eden,",
    "Odin's daughter-in-law and Bragi's wife.",
    "Her sweet apples in her basket,",
    "All thanks to her sweet apples."
  ]

  @bragi_song [
    "Bragi, Bragi,",
    "Forever call the poets name.",
    "My songs are his breath,",
    "My mind is his will,",
    "All wandering poets are his people,",
    "And all praise shall go to him."
  ]

  @warriors_song [
    "Louder, louder, louder.",
    "Give strength to the warriors!",
    "Shake the sky and roar through the land.",
    "Make my heart pound again!",
    "Let the castle walls ring.",
    "This day will never come again!"
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      upper(ctx) == 1 -> greet_transcendent(ctx)
      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:archer) -> greet_non_archer(ctx)
      true -> continue_quest(ctx, get_char_var(ctx, :BARD_Q, 0))
    end
  end

  defp greet_transcendent(ctx) do
    ctx
    |> mes("[Lalo]")
    |> mes("Chosen ones who are destined to become Gods")
    |> mes("are so many in this era")
    |> mes("but they never realise their fate while alive.")
    |> mes("They end up to become ordinary men...")
    |> next()
    |> mes("[Lalo]")
    |> mes("Wind and Clouds, please send this message to them,")
    |> mes("who pursue food, clothing, shelter and wealth.")
    |> mes("Tell them they are wasting their time...")
    |> mes("Tell them they forget the most important goal of the life...")
    |> finish("job_bard_aiolo01")
  end

  defp greet_non_archer(ctx) do
    ctx
    |> non_archer_dialogue()
    |> finish("job_bard_aiolo01")
  end

  defp non_archer_dialogue(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:bard) ->
        ctx
        |> mes("[Lalo]")
        |> mes("Ooh hey! How's your singing these days?")
        |> mes("I wonder if your voice got any better.")
        |> next()
        |> mes("[Lalo]")
        |> mes("You don't forget to spread good news in each town, right?")
        |> mes("And don't forget to learn new songs, too...")
        |> next()
        |> mes("[Lalo]")
        |> mes("Never forget to have a positive attitude and the meaning of joy.")
        |> mes("Our songs are supposed to deliver happiness and joy to everyone.")

      Rathena.job_id(class(ctx)) == Rathena.job_id(:novice) ->
        ctx
        |> cutin("job_bard_aiolo01", 2)
        |> mes("[Lalo]")
        |> mes("The sadness that overcomes my heart.. ")
        |> mes("It will not reside..")
        |> mes("Is this the reason behind my troubles,")
        |> mes("is this why I am weak,")
        |> mes("This must be why I cannot seem to forget you...")
        |> next()
        |> mes("[Lalo]")
        |> mes("Oh, sorry. I didn't see you because I was concentrating on writing some lyrics.")
        |> mes("Do you want to listen to my songs? Shall I sing a song for you?")
        |> next()
        |> mes("[Lalo]")
        |> mes("Heh... try asking someone else.")
        |> mes("I'm trying to compose a new song.")

      true ->
        verse =
          if male?(ctx),
            do: ["Forget about your worries~", "And enjoy everything~"],
            else: ["Cute lady, shall we dance~"]

        ctx
        |> cutin("job_bard_aiolo01", 2)
        |> mes("[Lalo]")
        |> mes("Lalala, lalala. Beautiful Comodo.")
        |> mes("Always full of happy moments~")
        |> next()
        |> mes("[Lalo]")
        |> mes_lines(verse)
        |> mes("Youth never repeats itself~")
    end
  end

  defp continue_quest(ctx, bard_q) do
    cond do
      bard_q == 0 -> first_meeting(ctx)
      bard_q == 1 -> offer_apprenticeship(ctx)
      bard_q == 2 -> receive_flower(ctx)
      bard_q >= 3 or bard_q <= 5 -> singing_test(ctx, bard_q)
      true -> hum(ctx)
    end
  end

  defp first_meeting(ctx) do
    greeting = if male?(ctx), do: "Hi! Delightful Archer.", else: "Hello! Beautiful Archer Lady."

    {ctx, choice} =
      ctx
      |> cutin("job_bard_aiolo01", 2)
      |> mes("[Lalo]")
      |> mes(greeting)
      |> mes("How can a wanderer like me help you?")
      |> next()
      |> select(["You have a nice voice.", "Could you sing for me, please?", "Nothing."])

    case choice do
      1 ->
        ctx
        |> mes("[Lalo]")
        |> mes("Hahaha! Of course!")
        |> mes("if you sing with a happy heart, your voice always gets better.")
        |> next()
        |> mes("[Lalo]")
        |> mes("But, to Bards your voice is your life.")
        |> mes("Sometimes your voice will go, but you must be careful.")
        |> finish("job_bard_aiolo02")

      2 ->
        sing_drums_of_war(ctx)

      3 ->
        ctx
        |> cutin("job_bard_aiolo02", 2)
        |> mes("[Lalo]")
        |> mes("Oy, not requesting a song when you run into a Bard isn't very polite.")
        |> mes("Well... can't help it since you look like you're in a hurry anyways.")
        |> next()
        |> mes("[Lalo]")
        |> mes("Hunting is good... but you can't forget to relax once in a while.")
        |> mes("Youth is short and won't come again once it passes by..")
        |> finish("job_bard_aiolo02")

      _ ->
        finish(ctx, "job_bard_aiolo02")
    end
  end

  defp sing_drums_of_war(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lalo]")
      |> mes("A song... let's see.")
      |> mes("Ok, I got one...")
      |> next()
      |> mes("[Lalo]")
      |> mes("I'll sing.. Drums of War.")
      |> mes("*ehem...*cough...gag..mememememe...")
      |> mes("1, 2, 3, 4...")
      |> next()
      |> mes("^000088The sound of horses galloping over the horizon")
      |> mes("The dust that covers the distant sun")
      |> mes("When thousands of eyes open in the night sky")
      |> mes("The castle's fire will burn with power.^000000")
      |> next()
      |> mes("^000088I can hear.. the beating of my heart.")
      |> mes("I can feel.. the blood rushing through my veins.")
      |> mes(".. and the weight of my armor.")
      |> mes("I can see.. my enemies.^000000")
      |> next()
      |> mes("^000088Louder, louder louder..")
      |> mes("Give strength to the warriors!")
      |> mes("Higher, higher, higher..")
      |> mes("This day will never come again!^000000")
      |> next()
      |> mes("^000088Shake the sky and roar through the land.")
      |> mes("Make my heart pound again!")
      |> mes("Let the trumpets sound, and castle walls ring.")
      |> mes("This moment will never come again!^000000")
      |> next()
      |> mes("[Lalo]")
      |> mes("Hmm... that's always a good song to sing.")
      |> mes("How was it? Don't you think it's a nice song?")
      |> next()
      |> select(["Yes, it was very nice.", "No, not really..."])

    if choice == 1 do
      ctx =
        ctx
        |> mes("[Lalo]")
        |> mes("Thanks! if you enjoyed my song, it makes me happy, too.")
        |> next()

      if male?(ctx) and job_level(ctx) > 39 do
        ctx
        |> mes("[Lalo]")
        |> mes("It would be nice if more people went around and sang...")
        |> mes("Well, it's quite ok as it is now... hmmhmm.")
        |> set_char_var(:BARD_Q, 1)
        |> setquest(3000)
        |> finish("job_bard_aiolo01")
      else
        ctx
        |> mes("[Lalo]")
        |> mes("if you ever want to hear my song again, just ask.")
        |> finish("job_bard_aiolo01")
      end
    else
      ctx
      |> cutin("job_bard_aiolo02", 2)
      |> mes("[Lalo]")
      |> mes("Hmm... Did I lose my senses, I'll have to try harder.")
      |> mes("Anyways.. Thanks for listening.")
      |> finish("job_bard_aiolo02")
    end
  end

  defp offer_apprenticeship(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("job_bard_aiolo01", 2)
      |> mes("[Lalo]")
      |> mes("Hey there Archer fellow.")
      |> mes("How can a wanderer like me help you?")
      |> next()
      |> select(["You have a nice voice.", "Could you sing for me, please?", "Nothing."])

    case choice do
      1 ->
        ask_to_sing(ctx)

      2 ->
        ctx
        |> mes("[Lalo]")
        |> mes("Hmm... seems like you have some singing talents?")
        |> mes("Don't just request songs.. singing to others is quite fun, too.")
        |> next()
        |> mes("[Lalo]")
        |> mes("Try enjoying your life as a Bard.")
        |> mes("You go from town to town, singing to the people. Doesn't it sound great?")
        |> finish("job_bard_aiolo01")

      3 ->
        ctx
        |> mes("[Lalo]")
        |> mes("Hmm... I'm not sure what's what, but enjoy life.")
        |> mes("You look too uptight.")
        |> next()
        |> mes("[Lalo]")
        |> mes("Well then~ Have a great time~")
        |> finish("job_bard_aiolo01")

      _ ->
        finish(ctx, "job_bard_aiolo01")
    end
  end

  defp ask_to_sing(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lalo]")
      |> mes("Hoho, your voice is rather nice as well?")
      |> mes("Ever think about singing?")
      |> next()
      |> select(["Of course!", "I can't quite possibly..."])

    if choice == 1 do
      ctx
      |> mes("[Lalo]")
      |> mes("Haha, nice attitude. You have to be like that to become a Bard.")
      |> mes("I'll help you become a Bard then.")
      |> next()
      |> mes("[Lalo]")
      |> mes("But before that... do you think you can bring me a Flower?")
      |> mes("I need to smell the scent of a Flower to feel like teaching.")
      |> next()
      |> mes("[Lalo]")
      |> mes("It doesn't really matter which Flower, but try to bring one that I like.")
      |> mes("And don't just buy any random Flower, ok?")
      |> set_char_var(:BARD_Q, 2)
      |> changequest(3000, 3001)
      |> finish("job_bard_aiolo01")
    else
      ctx
      |> mes("[Lalo]")
      |> mes("Haha, what a timid one.")
      |> mes("Don't think so little of yourself.")
      |> next()
      |> mes("[Lalo]")
      |> mes("You have plenty of talent.")
      |> mes("Come again if you change your mind.")
      |> finish("job_bard_aiolo01")
    end
  end

  defp receive_flower(ctx) do
    ctx =
      ctx
      |> cutin("job_bard_aiolo01", 2)
      |> mes("[Lalo]")
      |> mes("Welcome! Archer friend.")
      |> mes("Did you bring a Flower? Let me see.")
      |> next()
      |> mes("[Lalo]")

    case Enum.find(@gifted_flowers, fn {item_id, _, _} -> count_item(ctx, item_id) > 0 end) do
      {item_id, reaction, thanks} ->
        ctx
        |> mes_lines(reaction)
        |> next()
        |> delitem(item_id, 1)
        |> mes("[Lalo]")
        |> mes_lines(thanks)
        |> send_to_lutie()

      nil ->
        refused_flower = Enum.find(@refused_flowers, @no_flower, &has_item?(ctx, &1))
        refuse_flower(ctx, refused_flower)
    end
  end

  defp has_item?(ctx, {item_id, _, _, _}), do: count_item(ctx, item_id) > 0

  defp refuse_flower(ctx, {_item_id, frown?, reaction, advice}) do
    cutin_image = if frown?, do: "job_bard_aiolo02", else: "job_bard_aiolo01"
    ctx = if frown?, do: cutin(ctx, cutin_image, 2), else: ctx

    ctx
    |> mes_lines(reaction)
    |> next()
    |> mes("[Lalo]")
    |> mes_lines(advice)
    |> finish(cutin_image)
  end

  defp send_to_lutie(ctx) do
    ctx
    |> next()
    |> cutin("job_bard_aiolo01", 2)
    |> mes("[Lalo]")
    |> mes("As I promised, I'll help you become a Bard.")
    |> mes("But it's not easy my friend. Haha!")
    |> next()
    |> mes("[Lalo]")
    |> mes("It is important to get to know a lot of people to learn how to sing.")
    |> mes("You must also keep up with all the things going on in different villages...")
    |> next()
    |> mes("[Lalo]")
    |> mes("There's a talking snowman in a town called Lutie.")
    |> mes("Go there and bring back a present.")
    |> next()
    |> set_char_var(:BARD_Q, 3)
    |> changequest(3001, 3002)
    |> set_char_var(:xmas_npc, 1)
    |> mes("[Lalo]")
    |> mes("if you become friends with ^008800Jack Frost^000000, you will receive something.")
    |> mes("And also talk to the townspeople while you're at it...")
    |> finish("job_bard_aiolo01")
  end

  defp singing_test(ctx, bard_q) do
    cond do
      bard_q == 3 and get_char_var(ctx, :xmas_npc, 0) > 10 ->
        ctx
        |> cutin("job_bard_aiolo01", 2)
        |> mes("[Lalo]")
        |> mes("How was the trip? Did you meet a lot of people?")
        |> mes("You should have been able to learn something more important than a gift.")
        |> next()
        |> mes("[Lalo]")
        |> mes("Then, do you want to try singing...?")
        |> mes("I'll sing a short melody...")
        |> mes("and you try after.")
        |> start_singing_quest()
        |> next()
        |> mes("[Lalo]")
        |> mes("Here I go.")
        |> mes("Ehem *clears throat*")
        |> mes("1, 2, 3, 4")
        |> next()
        |> sing_along_unless_passed(bard_q)

      bard_q == 3 ->
        ctx
        |> cutin("job_bard_aiolo01", 2)
        |> set_char_var(:xmas_npc, 1)
        |> mes("[Lalo]")
        |> mes("Eh, you still haven't become his friend?")
        |> mes("Talking will not be enough.")
        |> next()
        |> mes("[Lalo]")
        |> mes("if you become friends with ^008800Jack Frost^000000, you will receive something.")
        |> mes("And talk with the village people, too...")
        |> finish("job_bard_aiolo01")

      bard_q == 4 ->
        ctx
        |> cutin("job_bard_aiolo01", 2)
        |> mes("[Lalo]")
        |> mes("Hmm... this time you can do better, right?")
        |> mes("Let's try again, you can do it.")
        |> next()
        |> mes("[Lalo]")
        |> mes("I'll sing one part...")
        |> mes("and you try it after.")
        |> next()
        |> mes("[Lalo]")
        |> mes("Here we go.")
        |> mes("*Ehem*")
        |> mes("1, 2, 3, 4")
        |> next()
        |> sing_along_unless_passed(bard_q)

      true ->
        sing_along_unless_passed(ctx, bard_q)
    end
  end

  defp start_singing_quest(ctx) do
    if checkquest(ctx, 3003) == -1, do: changequest(ctx, 3002, 3003), else: ctx
  end

  defp sing_along_unless_passed(ctx, bard_q) do
    if bard_q != 5 do
      song = local(ctx, Enum.random(1..5), 0)
      {ctx, mistakes} = sing_along(ctx, song_lyrics(song))

      if local(ctx, mistakes, 0) > 0 do
        ctx
        |> cutin("job_bard_aiolo02", 2)
        |> mes("[Lalo]")
        |> mes("Oy, You got the lyrics wrong!")
        |> mes("Can't you even sing along..?")
        |> next()
        |> mes("[Lalo]")
        |> mes("Your pronunciation is very unclear.")
        |> mes("Do a better job next time.")
        |> finish("job_bard_aiolo02")
      else
        praise_singing(ctx)
      end
    else
      offer_job_change(ctx, 0)
    end
  end

  defp song_lyrics(1), do: @immortal_hero_song
  defp song_lyrics(2), do: @proud_merchant_song
  defp song_lyrics(3), do: @goddess_eden_song
  defp song_lyrics(4), do: @bragi_song
  defp song_lyrics(_), do: @warriors_song

  defp sing_along(ctx, lyrics) do
    lyrics
    |> Enum.with_index()
    |> Enum.reduce({ctx, 0}, fn {line, index}, {ctx, mistakes} ->
      {ctx, answer} = ctx |> mes_lines(highlight(lyrics, index)) |> next() |> input(:string)
      {ctx, if(answer != line, do: mistakes + 1, else: mistakes)}
    end)
  end

  defp highlight(lyrics, index) do
    lyrics
    |> List.update_at(index, &(&1 <> "^000000"))
    |> List.update_at(0, &("^3377FF" <> &1))
  end

  defp praise_singing(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lalo]")
      |> mes("..........")
      |> next()
      |> set_char_var(:BARD_Q, 5)
      |> mes("[Lalo]")
      |> mes("Wonderful! Finished it in one try!")
      |> mes("You can become a great Bard. ")
      |> next()
      |> mes("[Lalo]")
      |> mes("Mmm... So you will not become a Bard.")
      |> mes("But I want to give you a souvenir...")
      |> next()
      |> mes("[Lalo]")
      |> mes("Do you want to just change jobs now?")
      |> mes("Or do you want a present.")
      |> next()
      |> select(["Just change my job please.", "I'd be thankful for a present."])

    offer_job_change(ctx, local(ctx, choice, 0))
  end

  defp offer_job_change(ctx, selection) do
    bard_q = get_char_var(ctx, :BARD_Q, 0)

    if selection == 1 or bard_q == 5 do
      change_job(ctx, bard_q)
    else
      request_trunks(ctx)
    end
  end

  defp change_job(ctx, bard_q) do
    cond do
      Rathena.truthy?(skill_point(ctx)) ->
        ctx
        |> cutin("job_bard_aiolo01", 2)
        |> mes("[Lalo]")
        |> mes("Ah... Everything is good, but you still have some skill points left.")
        |> mes("Go learn the rest of the skills and come back.")
        |> next()
        |> mes("[Lalo]")
        |> mes("And I am going to give you a small present...")
        |> mes("So bring some trunks.")
        |> mes("It doesn't matter what kind, as long as they are 60 of the same kind...")
        |> finish("job_bard_aiolo01")

      bard_q == 5 ->
        change_job_for_trunks(ctx)

      true ->
        become_bard(ctx)
    end
  end

  defp change_job_for_trunks(ctx) do
    cond do
      count_item(ctx, 1019) > 59 -> become_bard_with_souvenir(ctx, 1019, 1901)
      count_item(ctx, 1068) > 59 -> become_bard_with_souvenir(ctx, 1068, 1903)
      count_item(ctx, 1067) > 59 -> become_bard_with_souvenir(ctx, 1067, 1903)
      count_item(ctx, 1066) > 59 -> become_bard_with_souvenir(ctx, 1066, fine_trunk_souvenir(ctx))
      true -> offer_change_without_trunks(ctx)
    end
  end

  defp fine_trunk_souvenir(ctx), do: if(job_level(ctx) > 49, do: 1910, else: 1905)

  defp offer_change_without_trunks(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("job_bard_aiolo01", 2)
      |> mes("[Lalo]")
      |> mes("Mmm? Seems like you haven't prepared all trunks the yet? ")
      |> mes("Do you want to just change jobs anyways?")
      |> next()
      |> select(["Yes, just change my job already.", "No, I'll go prepare them."])

    if choice == 2, do: request_trunks(ctx), else: become_bard(ctx)
  end

  defp request_trunks(ctx) do
    ctx
    |> changequest(3003, 3004)
    |> mes("[Lalo]")
    |> mes("Hmm... very well, bring some trunks.")
    |> mes("It doesn't matter what kind, as long as they are 60 of the same kind...")
    |> next()
    |> mes("[Lalo]")
    |> mes("I will give you a gift once you bring them.")
    |> mes("Have a safe trip.")
    |> finish("job_bard_aiolo01")
  end

  defp become_bard(ctx) do
    {ctx, _} = ctx |> completequest(3003) |> jobchange(:bard) |> FClearjobvar.call([])

    ctx
    |> mes("[Lalo]")
    |> mes("Very well! Hope you sing happy enjoyable songs.")
    |> mes("Live like the wind and the clouds!")
    |> next()
    |> mes("[Lalo]")
    |> mes("See you again next time!")
    |> finish("job_bard_aiolo01")
  end

  defp become_bard_with_souvenir(ctx, trunk_id, souvenir_id) do
    {ctx, _} = ctx |> completequest(3004) |> jobchange(:bard) |> FClearjobvar.call([])

    ctx
    |> mes("[Lalo]")
    |> mes("Good job. I will make you a job change souvenir with this.")
    |> mes("Wait just a moment.")
    |> next()
    |> mes("[Lalo]")
    |> mes("^3355FFScrape Scrape Tang Tang^000000")
    |> mes("^3355FFSqueak Squeak Scratch Scratch^000000")
    |> delitem(trunk_id, 60)
    |> give_item(souvenir_id, 1)
    |> next()
    |> mes("[Lalo]")
    |> mes("Here you go, a souvenir. It is useful when you sing.")
    |> mes("Hope you sing happy songs.")
    |> next()
    |> mes("[Lalo]")
    |> mes("See you next time!")
    |> finish("job_bard_aiolo01")
  end

  defp hum(ctx) do
    ctx
    |> cutin("job_bard_aiolo01", 2)
    |> mes("[Lalo]")
    |> mes("Whee~ whee~ whee~")
    |> finish("job_bard_aiolo01")
  end

  defp male?(ctx), do: sex(ctx) == get_char_var(ctx, :SEX_MALE, 0)

  # set_local is a no-op on a halted ctx, so the original read these locals as their defaults.
  defp local(%{status: {:error, _}}, _value, default), do: default
  defp local(_ctx, value, _default), do: value

  defp finish(ctx, cutin_image), do: ctx |> close() |> cutin(cutin_image, 255)

  defp mes_lines(ctx, lines), do: Enum.reduce(lines, ctx, &mes(&2, &1))
end

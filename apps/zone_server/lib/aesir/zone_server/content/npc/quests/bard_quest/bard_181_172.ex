defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.Bard181172 do
  @moduledoc """
  Gunther Doubleharmony recalls lyrics for Errende and entertains passing listeners.

  ## Behavior

  - Asks for the song title and Errende's full name before writing down the lyrics.
  - Identifies Kino Kitty as the songwriter when the player returns with questions.
  - Offers three songs and three stories, or responds to being ignored.

  ## Credits

  - Original from rAthena, by Riotblade and L0ne_W0lf.
  - Changelog contributors: Lupus, SinSloth, and Euphy.

  ## Adaptation

  - Transpiled by `mix aesir.import.npcs` from `quests/bard_quest.txt`.
  - LLM-assisted Elixir refactor.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 181,
        y: 172,
        dir: 3,
        sprite: 51,
        name: "Bard",
        scope: :shared,
        unique_name: "Bard#4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = set_temp_var(ctx, :"name$", char_name(ctx, 0))

    cond do
      get_char_var(ctx, :gef_bard_q, 0) == 2 or get_char_var(ctx, :gef_bard_q, 0) == 22 ->
        recover_lyrics(ctx)

      get_char_var(ctx, :gef_bard_q, 0) == 6 or get_char_var(ctx, :gef_bard_q, 0) == 26 ->
        identify_songwriter(ctx)

      true ->
        offer_entertainment(ctx)
    end
  end

  defp recover_lyrics(ctx) do
    ctx =
      ctx
      |> mes("[Gunther Doubleharmony]")
      |> mes("Hahaha~!")
      |> mes("Listen, listen!")
      |> next()
      |> mes("[Gunther Doubleharmony]")
      |> mes(
        "I was told this song from one of my friends about this Merchant who lives in Payon and everyone loves this song, especially because I'm singing it and you know that..."
      )
      |> next()

    {ctx, song_title} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", get_temp_var(ctx, :"name$", "")), "]"))
      |> mes("Excuse me.")
      |> mes("Are you...")
      |> mes("Gunther Doubleharmony?")
      |> next()
      |> mes("[Gunther Doubleharmony]")
      |> mes(
        "...the Merchant was so poor he didn't even have--eh? Oh yeah, right. That's me. What's up?"
      )
      |> next()
      |> mes("^3355FFYou explain that you have come to him, seeking lost song lyrics.^000000")
      |> next()
      |> mes("[Gunther Doubleharmony]")
      |> mes("Ahhhhhhh, I see.")
      |> mes("Now, what was the")
      |> mes("name of the song again?")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"inputstr$", song_title)

    if get_local(ctx, :"inputstr$", "") == "At One, I Fall in Love" do
      ask_requester(ctx)
    else
      ctx
      |> mes("[Gunther Doubleharmony]")
      |> mes(
        "No no no no, I don't know any song with that title, it might not even exist, so you should go and check the name of the song again and tell me, okay?"
      )
      |> close()
    end
  end

  defp ask_requester(ctx) do
    {ctx, requester} =
      ctx
      |> mes("[Gunther Doubleharmony]")
      |> mes("Ah~ that song...?")
      |> mes("By the way, who asked you")
      |> mes("to find out about the song?")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"inputstr$", requester)

    if get_local(ctx, :"inputstr$", "") == "Minty Errende" do
      ctx =
        ctx
        |> mes("[Gunther Doubleharmony]")
        |> mes(
          "Yes, that's my friend! Minty Errende! We used to so close to each other, so I'll write every word of the song for my friend Minty Errende, so turn around please!"
        )
        |> next()
        |> mes("^3355FFGunther furiously scribbled something upon your back.^000000")
        |> next()
        |> mes("[Gunther Doubleharmony]")
        |> mes(
          "There you go! Now you can go back to Minty Errende and show him your back and he will see what I wrote and then remember the lyrics!"
        )

      ctx =
        if get_char_var(ctx, :gef_bard_q, 0) == 2 do
          set_char_var(ctx, :gef_bard_q, 3)
        else
          ctx
        end

      ctx =
        if get_char_var(ctx, :gef_bard_q, 0) == 22 do
          set_char_var(ctx, :gef_bard_q, 23)
        else
          ctx
        end

      close(ctx)
    else
      ctx
      |> mes("[Gunther Doubleharmony]")
      |> mes(
        "No no no, I don't know anyone with that name, so you better go and check the name of the person asking again, okay?"
      )
      |> close()
    end
  end

  defp identify_songwriter(ctx) do
    ctx
    |> mes("[Gunther Doubleharmony]")
    |> mes("You came back again!")
    |> mes(
      "Huh, the song I wrote on your back? Hold on, hold on, let me think let me--ah, right, I got it!"
    )
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "The words I wrote down on your back were written by Mr. Kitty, my idol, my hero! That song is the art of ^228B22Kino Kitty^000000!"
    )
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes("I wish that someday I could be as great a Bard as him!")
    |> close()
  end

  defp offer_entertainment(ctx) do
    {ctx, interest_choice} =
      ctx
      |> mes("[Gunther Doubleharmony]")
      |> mes("Hahaha~!")
      |> mes("Listen, listen!")
      |> next()
      |> mes("[Gunther Doubleharmony]")
      |> mes(
        "I was told this song from one of my friends about this Merchant who lives in Payon and everyone loves this song, especially because I'm singing it and you know that..."
      )
      |> next()
      |> mes("[Gunther Doubleharmony]")
      |> mes("Oh, right...!")
      |> mes("Do you wanna listen")
      |> mes("to my song or a story?")
      |> mes("I know you want to!")
      |> mes("Right, right?")
      |> next()
      |> select(["Show some interest.", "Ignore him."])

    if interest_choice == 1 do
      {ctx, entertainment_choice} =
        ctx
        |> mes("[Gunther Doubleharmony]")
        |> mes("Yay~! I knew it!")
        |> mes("So you wanna hear")
        |> mes("a song or a story?")
        |> next()
        |> select(["A song", "A story", "Maybe some other time"])

      case entertainment_choice do
        1 ->
          sing_random_song(ctx)

        2 ->
          tell_random_story(ctx)

        3 ->
          invite_return(ctx)

        _ ->
          ctx
      end
    else
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", get_temp_var(ctx, :"name$", "")), "]"))
      |> mes("...")
      |> next()
      |> mes("[Gunther Doubleharmony]")
      |> mes(
        "Wow, you're ignoring me, huh? Alright, that's fine by me! Unless you have some kind of problem where you can't talk, then I'm really really sorry."
      )
      |> close()
    end
  end

  defp sing_random_song(ctx) do
    case Enum.random(1..3) do
      1 -> sing_rich_mr_kim(ctx)
      2 -> sing_yggdrasil(ctx)
      3 -> sing_lukes_song(ctx)
      _ -> ctx
    end
  end

  defp tell_random_story(ctx) do
    case Enum.random(1..3) do
      1 -> tell_cheese_story(ctx)
      2 -> tell_swordman_story(ctx)
      3 -> tell_snowman_story(ctx)
      _ -> ctx
    end
  end

  defp invite_return(ctx) do
    ctx
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "You're gonna leave right now and not even listen to me a little bit? Okay, I'm cool, but promise you'll come back and listen to just one of my songs, okay?"
    )
    |> close()
  end

  defp sing_lukes_song(ctx) do
    ctx
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "I will sing one of Luke's songs, you know, Luke, one of the greatest Bards of his time? But I changed the words a little bit."
    )
    |> next()
    |> mes("^228B22I found it in a drawer.")
    |> mes("Old, worn letters")
    |> mes("Forming elaborate words.")
    |> mes("Sincere reflection")
    |> mes("Of a sincere mind.^000000")
    |> next()
    |> mes("^228B22I found it in a drawer.")
    |> mes("Was I really like that once?")
    |> mes("Was I really that childish?")
    |> mes("My memories are tarnished.")
    |> next()
    |> mes("^228B22I found it in a drawer.")
    |> mes("Love I had forgotten.")
    |> mes("She never got this letter.")
    |> mes("But both of us were too shy.")
    |> next()
    |> mes("^228B22I found it in a drawer.")
    |> mes("Love I had forgotten.")
    |> mes("I never gave her this letter.")
    |> mes("But both of us were too proud.")
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "Do you have anyone in mind? Do you? If you ever write a love letter, you must send it and express yourself."
    )
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "If you've written love letters that you'll never send, throw them away. Throw your goddamn pride away."
    )
    |> close()
  end

  defp sing_rich_mr_kim(ctx) do
    ctx
    |> mes("[Gunther Doubleharmony]")
    |> mes("Gunther sings!")
    |> mes("Gunther dances!")
    |> mes("The tile of this song is~")
    |> mes("'The Rich Mr. Kim~!'")
    |> next()
    |> mes("^228B22Merchant of Payon")
    |> mes("So poooooooor~")
    |> mes("No money for armor")
    |> mes("No money to make.")
    |> next()
    |> mes("^228B22Sold the")
    |> mes("Cotton Shirt")
    |> mes("Off his back")
    |> mes("No pity he'll take.^000000")
    |> next()
    |> mes("^228B22First he only sold Red Pots")
    |> mes("At first, he only sold red pots.")
    |> mes("Then he moved up to Carrots, whoohoo~")
    |> mes("He could afford new armor")
    |> mes("and even wear it,")
    |> mes("whoohoo~^000000")
    |> next()
    |> mes("^228B22But one day, he was scammed")
    |> mes("Scammed by a wicked guild.")
    |> mes("Made poor once again.")
    |> mes("He decided to go to Ant Hell")
    |> mes("Right there")
    |> mes("And right then.")
    |> next()
    |> mes("^228B22Bats, Dwarves, Eggs, Ants!")
    |> mes("He battled them all~")
    |> mes("Worm Peelings, Jellopy!")
    |> mes("He gathered loot great and small.")
    |> next()
    |> mes("^228B22Then the glorious day came")
    |> mes("When he found a valuable card")
    |> mes("That'd bring great wealth to his naaaame~^000000")
    |> next()
    |> mes("^228B22But he kept it dear to him")
    |> mes("To remember his times of")
    |> mes("working so hard.")
    |> mes("He never sold it, never sold")
    |> mes("his precious card~^000000")
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "That's a very old story about rich Mr. Kim, and his rise from rags to riches to rags to riches. Is it true or is it fiction? Oh, please don't ask me! I've no clue!"
    )
    |> close()
  end

  defp sing_yggdrasil(ctx) do
    ctx
    |> mes("[Gunther Doubleharmony]")
    |> mes("*Ahem*")
    |> mes("Gunther sings ")
    |> mes("of Yggdrasil~")
    |> next()
    |> mes("^228B22Evergreen Yggdrasil~")
    |> mes("Giant ashen tree")
    |> mes("reaching for the sky.")
    |> mes("Crystal, morning dew")
    |> mes("From its leaves")
    |> mes("Formed Urd's Pond.^000000")
    |> next()
    |> mes("^228B22Three wise girls.")
    |> mes("Seated beneath its boughs.")
    |> mes("Urd of the past,")
    |> mes("Belldandy of the present")
    |> mes("Skuld the future.^000000")
    |> next()
    |> mes("^228B22Spinning, weaving")
    |> mes("Threads of destiny.")
    |> mes("Evergreen Yggdrasil~")
    |> mes("Giant ashen tree")
    |> mes("reaching for the sky.")
    |> mes("Its roots soaked with tears.^000000")
    |> next()
    |> mes("^228B22Death in Hvergelmir.")
    |> mes("An evil dragon")
    |> mes("Burning its roots")
    |> mes("With eternal flame.")
    |> mes("The evil dragon Nidhogg")
    |> mes("Living between Yggdrasil")
    |> mes("and Niffheim.^000000")
    |> next()
    |> mes("^228B22Evergreen Yggdrasil~")
    |> mes("Giant ashen tree")
    |> mes("reaching for the sky.")
    |> mes("Wisdom in its roots")
    |> mes("Roots reaching")
    |> mes("Mimir's pond.^000000")
    |> next()
    |> mes("^228B22Guarded by a wise giant.")
    |> mes("Odin sacrificed one")
    |> mes("of his eyes for the wisdom.")
    |> mes("Heimdall's horn hidden")
    |> mes("In Yggdrasil's roots")
    |> mes("Will sound one last time")
    |> mes("Signaling Ragnarok.^000000")
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes("This is a very old story...")
    |> mes("Is it truth or fiction? But please don't ask me, I have no idea~!")
    |> close()
  end

  defp tell_cheese_story(ctx) do
    ctx
    |> mes("[Gunther Doubleharmony]")
    |> mes("Um, have you ever")
    |> mes("tasted Comodo cheese?")
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "You can only taste it in Comodo, but you need to have a good strong stomach to digest it. Oh! And the cheese has a secret!"
    )
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "You ^228B22might^000000 be invulnerable to the power of the doomed swords, which come from the other world, if you eat it!"
    )
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "Why don't you go taste it if you haven't yet? I tried to taste it once. It was kind of yummy, but then I fainted. Hahahaha~!"
    )
    |> close()
  end

  defp tell_snowman_story(ctx) do
    ctx
    |> mes("[Gunther Doubleharmony]")
    |> mes("Have you ever been in Lutie,")
    |> mes("land of year round snow?")
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes("There is a snowman named")
    |> mes(
      "SnowySnow and if you met him, you'd know all sorts of things about him like he can talk! It's so strange and mysterious~!"
    )
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "He has a mysterious bag where endless gifts come out, and he's got a mysterious past involving some colder town and something about a nasty witch."
    )
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "But it's okay because he was rescued by some Alchemist and came back to life, but you should go to Lutie if you wanna know more about him, okay?"
    )
    |> close()
  end

  defp tell_swordman_story(ctx) do
    ctx
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "I was passing Prontera the other day at the place where it used to be the Swordman training ground."
    )
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "I saw some kid training really really hard and he didn't notice me watching him, so I guess he was really really serious!"
    )
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "He looked like he wanted to be a professional Swordman, but he was also giving his gear away to other Novices."
    )
    |> next()
    |> mes("[Gunther Doubleharmony]")
    |> mes(
      "I got bored watching him do the same thing over and over and over again, but I think the Monster Research Organization would like him if I introduced him."
    )
    |> close()
  end
end

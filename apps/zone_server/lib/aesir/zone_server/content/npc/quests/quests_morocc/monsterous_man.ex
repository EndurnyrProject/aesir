defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.MonsterousMan do
  @moduledoc """
  Zid tells the player about the cave village and Eva.

  ## Behavior

  - Discusses his past during the Crow of the Fate quest and advances its progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cave",
        x: 22,
        y: 186,
        dir: 3,
        sprite: 999,
        name: "Monsterous Man",
        scope: :shared,
        unique_name: "Monsterous Man#zid"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :barmunt_crow, 0) do
      9 ->
        ctx
        |> mes("^660000You are looking at a man who appears as hideous as a monster.")
        |> mes(
          "He was the man with Eva that you saw in your dream. Of course, he's older now, and his age is showing in his face and skin.^000000"
        )
        |> next()
        |> mes("(WHIZZ)")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Argh...")
        |> next()
        |> mes("^660000The pain in your chest suddenly hits you...")
        |> mes(
          "And your lungs seem much weaker from all of the coughing and sneezing you've suffered lately.^000000"
        )
        |> next()
        |> mes(
          "^660000Rubbing your chest to ease the pain, you keep staring at him in surprise.^000000"
        )
        |> next()
        |> mes("^660000Thankfully, he speaks to you first.^000000")
        |> next()
        |> mes("[Monsterous Man]")
        |> mes("Does my appearance bother you?")
        |> next()
        |> mes("[Monsterous Man]")
        |> mes("So, you know Eva... Huh?")
        |> next()
        |> mes("^660000He sounded weak, as if he did not have enough energy to talk.^000000")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Umm... Ahchoo!")
        |> specialeffect2(:venomdust)
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Do you know a man by the name of Oliver Hilpert?")
        |> next()
        |> mes("[Monsterous Man]")
        |> mes("Oliver? Well, I don't think so.")
        |> mes("What does he have to do with anything?")
        |> next()
        |> mes(
          "^660000You have given him Oliver's novel, <The Crow of the Fate>, explaining strange events that have happened to you.^000000"
        )
        |> next()
        |> mes("....................")
        |> next()
        |> mes("....................")
        |> mes("....................")
        |> next()
        |> mes("....................")
        |> mes("....................")
        |> mes("....................")
        |> next()
        |> mes(
          "^660000He squinted his eyes in curiosity and looked through a few pages of the book quietly. Then he opened his mouth as he handed the book back to you.^000000"
        )
        |> next()
        |> mes("[Monsterous Man]")
        |> mes(
          "I'm surprised that the story in this book is... It's similar to my life story. Very similar."
        )
        |> next()
        |> discuss_history()
        |> mes("[Zid]")
        |> mes("Hmm...")
        |> mes("Maybe Oliver is Eva's boy...")
        |> next()
        |> mes("[Zid]")
        |> mes("No, he's too young to be him because it happened a long time ago...")
        |> next()
        |> mes("[Zid]")
        |> mes(".........................")
        |> next()
        |> mes("[Zid]")
        |> mes("I guess it's just an old memory... Why should I care? Why should anyone?")
        |> next()
        |> mes(
          "^660000Zid stopped talking, and then lowered his head. After the pause, he opened his mouth again.^000000"
        )
        |> next()
        |> mes("[Zid]")
        |> mes("Now I'm too old to remember even Eva or the boy.")
        |> mes(
          "My purpose in life is to protect the other villagers. They have lives ahead of them, living inside this dark cave."
        )
        |> next()
        |> mes("[Zid]")
        |> mes(
          "The book was interesting, but I'm sure that guy, Oliver, experienced the same thing that happened to you."
        )
        |> next()
        |> mes("[Zid]")
        |> mes("Even if he has something to do with Eva, it's too late to do anything for her.")
        |> next()
        |> mes("[Zid]")
        |> mes(
          "Think about it: who can save us from this dark cave, even if Eva or that boy is still alive? The answer is nobody."
        )
        |> next()
        |> mes("[Zid]")
        |> mes(".................................")
        |> next()
        |> mes("[Zid]")
        |> mes("I'm so sorry for not being much help.")
        |> mes("You'd better wake up from the dream, and move on with your life.")
        |> mes("...Sadly everything is nothing but a dream...")
        |> next()
        |> mes("[Zid]")
        |> mes("If you really feel sorry for us, please do not let others know where we are.")
        |> next()
        |> mes(
          "^660000Zid turned his head away from you. You're still not sure if all of this is really happening. It's all so surreal...^000000"
        )
        |> next()
        |> mes(
          "^660000Frustrated by the conversation with Zid, you have decided to go back to Morocc and forget everything.^000000"
        )
        |> set_char_var(:barmunt_crow, 10)
        |> changequest(2066, 2067)
        |> close()

      10 ->
        ctx
        |> mes("Zid seemed to have lost his interest in the book.")
        |> mes("You have decided to deliver the book to Benjamin of Morocc.")
        |> close()

      _ ->
        ctx
        |> mes("[Monsterous Man]")
        |> mes("Don't look at my face...")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_history(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Zid]")
      |> mes(
        "My name is Zid. Tell me what you want from me. I want to know more about this book."
      )
      |> next()
      |> select(["About the Cave Village", "About Himself", "About Eva", "End Conversation"])

    case choice do
      1 ->
        ctx
        |> mes("[Zid]")
        |> mes("Did you notice that our villagers look different?")
        |> next()
        |> mes("[Zid]")
        |> mes(
          "Human curiosity has led to great achievements and contributions, but there is a point where knowledge may be too much to handle."
        )
        |> mes(
          "Everyone in this village is a runaway... We are victims of what happens when people play God, seek out forbidden knowledge, and toy with life."
        )
        |> next()
        |> mes("[Zid]")
        |> mes(
          "We have no choice but hide here because they are too powerful for us to speak out against... And we know that isn't right."
        )
        |> next()
        |> discuss_history()

      2 ->
        ctx
        |> mes("[Zid]")
        |> mes(
          "I was a normal man once, but poverty made me lose my pride, self-esteem, and identity."
        )
        |> mes(
          "I was sick and tired of worrying about food everyday, and I volunteered to be a test subject in some experiment."
        )
        |> mes(
          "I no longer had to worry about starving, but my life as a 'human' ended that day."
        )
        |> next()
        |> mes("[Zid]")
        |> mes(
          "At first, Eva and I were the only ones here, but others joined us, and we formed a small settlement."
        )
        |> mes(
          "Now I'm the oldest villager, and feel the heavy responsibility of protecting others."
        )
        |> next()
        |> discuss_history()

      3 ->
        ctx
        |> mes("[Zid]")
        |> mes("The laboratory in which Eva and I were being tested was not ordinary.")
        |> mes("It was built to test and duplicate God's power of creation.")
        |> next()
        |> mes("[Zid]")
        |> mes(
          "They failed to achieve their objective, and caused a series of unfortunate events"
        )
        |> mes("by trying to manipulate materials that were difficult to even examine.")
        |> mes("They believed their research would open a whole new world for mankind...")
        |> next()
        |> mes("[Zid]")
        |> mes(
          "Eva was one of them... Although she wasn't kind, she at least sympathized for me because I sold myself out of poverty."
        )
        |> next()
        |> mes("[Zid]")
        |> mes("She had a man who loved her so much...")
        |> mes("His name was Sefakiest, and he always supported her research.")
        |> next()
        |> mes("[Zid]")
        |> mes(
          "He... Killed himself in despair after Eva was turned into a mutant just like me... She wanted him to use her as his test subject."
        )
        |> mes(
          "No one expected him to end his life so easily when he was the most enthusiastic researcher of all."
        )
        |> next()
        |> mes("[Zid]")
        |> mes(
          "Then somebody set the laboratory on fire. I assume you've seen that in your dream. The fire completely burned down the building."
        )
        |> next()
        |> mes("[Zid]")
        |> mes(
          "Eva and I were able to escape before we could be found, and then settled down here. After all, we can't just mingle with ordinary humans."
        )
        |> next()
        |> mes("[Zid]")
        |> mes(
          "Eva managed to save one of the test subjects which actually grew up into a normal looking human, but he was actually perfect."
        )
        |> next()
        |> mes("[Zid]")
        |> mes(
          "That boy ran away when he was about 10. I guess he hit puberty... You know boys and girls at that age."
        )
        |> next()
        |> mes("[Zid]")
        |> mes(
          "Eva couldn't forget him. She was waiting for his return inside this dark cave. For a while, he was sending letters without his address, but then they stopped coming. That's when Eva disappeared."
        )
        |> mes("I found ^3131FFa giant black feather^000000 in her room after she left.")
        |> next()
        |> mes("[Zid]")
        |> mes("I don't know why, but... I believe Eva no longer exists...")
        |> next()
        |> discuss_history()

      4 ->
        set_local(ctx, :exitloop, 1)

      _ ->
        throw({:script_end, ctx})
    end
  end
end

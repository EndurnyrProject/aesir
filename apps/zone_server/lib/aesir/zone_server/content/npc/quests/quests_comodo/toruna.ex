defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Toruna do
  @moduledoc """
  Toruna shares stories about Comodo and its history.

  ## Behavior

  - Discusses the legend of Comodo Cheese during the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 88,
        y: 97,
        dir: 4,
        sprite: 109,
        name: "Toruna",
        scope: :shared,
        unique_name: "Toruna#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Toruna]")
      |> mes("When I think about it,")
      |> mes("there are many fascinating")
      |> mes("facts about Comodo. Can")
      |> mes("you believe this entire city")
      |> mes("is built inside a natural cave?")
      |> next()
      |> select(["This cave is huge!", "This place sure is strange...", "Cancel"])

    case choice do
      1 ->
        ctx
        |> mes("[Toruna]")
        |> mes("Oh, this is a huge cave,")
        |> mes("but it's not impossible for")
        |> mes("nature to create something")
        |> mes("of this size and scale if given")
        |> mes("thousands, maybe even millions")
        |> mes("of years. Let me explain...")
        |> next()
        |> mes("[Toruna]")
        |> mes("Now, water is known as")
        |> mes("a universal solvent: running")
        |> mes("water will carve its own path")
        |> mes("in rock, given enough time.")
        |> mes("Now, keep in mind that this")
        |> mes("cave was once solid limestone.")
        |> next()
        |> mes("[Toruna]")
        |> mes("Years and years of running")
        |> mes("water from the rains and the")
        |> mes("water table have broken down")
        |> mes("this giant pocket of limestone,")
        |> mes("clearing out this huge, open")
        |> mes("area, the Comodo Cave.")
        |> next()
        |> mes("[Toruna]")
        |> mes("That may sound incredulous,")
        |> mes("but cracks in limestone grow")
        |> mes("into faults, then spacious gaps")
        |> mes("over years and years of erosion. Now, isn't natural science just")
        |> mes("amazing? You've got to agree...")
        |> close()

      2 ->
        case get_char_var(ctx, :dmdswrd_Q, 0) do
          5 ->
            ctx
            |> mes("[Toruna]")
            |> mes("Yes, that is rather")
            |> mes("peculiar. What's also")
            |> mes("strange is this rumor I've")
            |> mes("been hearing about. Now, are you familiar with Comodo Cheese?")
            |> next()
            |> mes("[Toruna]")
            |> mes("It's this urban legend")
            |> mes("about this magnificent cheese")
            |> mes("that you can only find in Comodo. Now, not too many people believe")
            |> mes("it. I mean, you need goats or cows")
            |> mes("in order to make any cheese.")
            |> next()
            |> mes("[Toruna]")
            |> mes("However, there's this")
            |> mes("strange man that insists")
            |> mes("on its existence. The locals")
            |> mes("here chalk him up to be some")
            |> mes("sort of common loon, but who")
            |> mes("knows? Maybe it does exist...")
            |> set_char_var(:dmdswrd_Q, 6)
            |> next()
            |> mes("[Toruna]")
            |> mes("Well, you can decide for")
            |> mes("yourself whether he's off")
            |> mes("his rocker. The last time")
            |> mes("I saw him, he was in the")
            |> mes("Comodo Bar, so you can")
            |> mes("probably find him there.")

          6 ->
            ctx
            |> mes("[Toruna]")
            |> mes("Well, I like to think of")
            |> mes("Comodo as unique. What's")
            |> mes("really strange are some of")
            |> mes("the locals in this area. I've")
            |> mes("already told you about the")
            |> mes("man in the Comodo Bar, yes?")
            |> next()
            |> mes("[Toruna]")
            |> mes("He keeps insisting")
            |> mes("that there is a special")
            |> mes("kind of cheese in Comodo")
            |> mes("that you cannot get anywhere")
            |> mes("else. It sounds crazy, but his")
            |> mes("claim may be worth verifying...")

          _ ->
            ctx
            |> mes("[Toruna]")
            |> mes("Ah, did you know that")
            |> mes("before it was an exotic")
            |> mes("village of excitement and")
            |> mes("leisure, Comodo was once")
            |> mes("a haven for evil creatures, ruled by a witch named Meropusum?")
            |> next()
            |> mes("[Toruna]")
            |> mes("This witch lay dormant for")
            |> mes("years until she was awoken")
            |> mes("somehow years ago. She was")
            |> mes("a huge threat to the people, but then she was finally defeated")
            |> mes("in the famous War of the Witch.")
            |> next()
            |> mes("[Toruna]")
            |> mes("One of the heroes of that")
            |> mes("war became the current Chief")
            |> mes("of this village, and it was")
            |> mes("through his leadership that")
            |> mes("Comodo grew into a thriving")
            |> mes("tourist attraction.")
            |> next()
            |> mes("[Toruna]")
            |> mes("However, the threat of")
            |> mes("Meropusum still exists,")
            |> mes("so I would be careful when")
            |> mes("exploring the uninhabited")
            |> mes("areas of the Comodo region.")
        end
        |> close()

      3 ->
        ctx
        |> mes("[Toruna]")
        |> mes("There's much to do")
        |> mes("in this city of Comodo,")
        |> mes("as well as much to learn")
        |> mes("about it. I can never tire of")
        |> mes("visiting this exotic city...")
        |> close()

      _ ->
        ctx
    end
  end
end

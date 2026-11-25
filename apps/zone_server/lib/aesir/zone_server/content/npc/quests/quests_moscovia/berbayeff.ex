defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Berbayeff do
  @moduledoc """
  Berbayeff tells travelers about the legendary Moving Island.

  ## Behavior

  - He begins the island quest and directs interested travelers to Mr. Ibanoff.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moscovia",
        x: 171,
        y: 71,
        dir: 3,
        sprite: 968,
        name: "Berbayeff",
        scope: :shared,
        unique_name: "Berbayeff#npc"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :mos_whale_edq, 0)

    cond do
      not Rathena.truthy?(stage) -> begin_quest(ctx)
      stage == 1 -> revisit(ctx)
      stage > 2 and stage < 42 -> island_found(ctx)
      true -> welcome(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp begin_quest(ctx) do
    {ctx, _} =
      ctx
      |> emotion(:fret)
      |> mes("[Berbayeff]")
      |> mes("This..and..that...")
      |> mes("All guys...are distrustful.")
      |> mes("Makes me a braggart.")
      |> next()
      |> select(["Do you have a problem?"])

    ctx =
      ctx
      |> mes("[Berbayeff]")
      |> mes("I haven't seen you before.")
      |> mes("Are you a traveler?")
      |> mes("If so, then you may have")
      |> mes("seen many marvelous things")
      |> mes("from near and far.")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("I'm sure you'll probably")
      |> mes("be interested in my story.")
      |> mes("All the villagers are blockheads,")
      |> mes("so they treat me like an idiot.")

    ctx =
      if isbegin_quest(ctx, 18100) == 0 do
        setquest(ctx, 18100)
      else
        ctx
      end

    {ctx, choice} = ctx |> next() |> select(["I'm not interested in any story.", "Tell me."])

    case choice do
      1 ->
        ctx
        |> mes("[Berbayeff]")
        |> mes("Indeed... You are not interested...")
        |> mes("That's ok.")
        |> next()
        |> mes("[Berbayeff]")
        |> mes("If you change your mind,")
        |> mes("you can talk to me whenever.")
        |> close()

      _ ->
        tell_story(ctx)
    end
  end

  defp tell_story(ctx) do
    {ctx, _} =
      ctx
      |> emotion(:best)
      |> mes("[Berbayeff]")
      |> mes("Good, I have been thinking that")
      |> mes("I would tell you this story from the start.")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("You seem to have spent")
      |> mes("only a few days here.")
      |> mes("Have you ever heard")
      |> mes("about The Moving Island?")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("In Moscovia,")
      |> mes("a story is handed down")
      |> mes("from the ancients, like legends.")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("It is said that")
      |> mes("there is an island")
      |> mes("which sometimes moves,")
      |> mes("not far out at sea.")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("But, nobody has seen")
      |> mes("the island before.")
      |> mes("So, few people have")
      |> mes("believed the legend.")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("Actually, I thought that")
      |> mes("it might be a kind of")
      |> mes("old story... nothing more.")
      |> mes("But then... I saw...")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("Actually, I thought that")
      |> mes("it might be a kind of")
      |> mes("old story... nothing more.")
      |> mes("But then... I saw...")
      |> mes("The Moving Island!!!")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("Surprised? Right...")
      |> mes("It is so surprising.")
      |> mes("Frankly, you don't believe")
      |> mes("any of this story either.")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("I saw the island")
      |> mes("from the middle of")
      |> mes("the village's south shore.")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("At first, I doubted my eyes.")
      |> mes("I have never heard that that island")
      |> mes("really existed here, even though I")
      |> mes("have lived here all my life!")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("I tried to go up")
      |> mes("to look at it from")
      |> mes("higher ground, but")
      |> mes("the island receded")
      |> mes("and disappeared...")
      |> mes("back to the sea.")
      |> next()
      |> select(["The island doesn't appear anymore?"])

    ctx
    |> mes("[Berbayeff]")
    |> mes("If it does,")
    |> mes("one might just think")
    |> mes("that they've looked")
    |> mes("at an apparition.")
    |> next()
    |> mes("[Berbayeff]")
    |> mes("But a few nights ago...")
    |> mes("Finally, the island appeared")
    |> mes("in front of me again,")
    |> mes("while I was driving my ship to go home.")
    |> next()
    |> mes("[Berbayeff]")
    |> mes("At that time, I tried to")
    |> mes("get near the island again,")
    |> mes("slowly, but it disappeared...")
    |> mes("beyond the sea once more.")
    |> next()
    |> mes("[Berbayeff]")
    |> mes("It was then, I couldn't help")
    |> mes("to finally believe")
    |> mes("in the existence of")
    |> mes("The Moving Island!")
    |> next()
    |> mes("[Berbayeff]")
    |> mes("Surely, this must be")
    |> mes("a great discovery!")
    |> mes("Don't you think??")
    |> mes("Doesn't your heart shout out in")
    |> mes("hopes of adventuring out to the island?")
    |> next()
    |> mes("[Berbayeff]")
    |> mes("I haven't given up yet!")
    |> mes("Certainly, it'll appear again")
    |> mes("right in front of us!")
    |> next()
    |> mes("[Berbayeff]")
    |> mes("And on that day,")
    |> mes("I'll definitely go up to that")
    |> mes("island... and verify it with my own eyes!")
    |> changequest(18100, 18101)
    |> set_char_var(:mos_whale_edq, 1)
    |> close()
  end

  defp revisit(ctx) do
    ctx = set_local(ctx, :speak, Enum.random(1..5))

    if get_local(ctx, :speak, 0) < 3 do
      ctx
      |> mes("[Berbayeff]")
      |> mes("Clearly, I want to prove")
      |> mes("the existence of that island to everyone...")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("If the island appears again,")
      |> mes("I should certify its identity.")
      |> mes("Would you like to try it?")
      |> close()
    else
      ctx
      |> mes("[Berbayeff]")
      |> mes("The best way to find the")
      |> mes("island is by direct contact")
      |> mes("with a ship in the sea.")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("Me?")
      |> mes("Of course I have a ship.")
      |> mes("I am a fisherman after all...")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("Ah, you do? You need...")
      |> mes("a ship? Hm...too bad.")
      |> mes("I can't lend my ship to you...")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("But maybe Mr. Ibanoff")
      |> mes("can lend his ship to you")
      |> mes("He likes going around")
      |> mes("adventuring like me.")
      |> mes("He seems to enjoy his youth...")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("Mr. Ibanoff also traveled and")
      |> mes("adventured all over the world")
      |> mes("like you, so he might understand")
      |> mes("your sentiments well.")
      |> next()
      |> mes("[Berbayeff]")
      |> mes("If you want to find the island")
      |> mes("by ship, go to Mr. Ibanoff")
      |> mes("and ask for a favor.")
      |> changequest(18101, 18102)
      |> close()
    end
  end

  defp island_found(ctx) do
    ctx
    |> emotion(:huk)
    |> mes("[Berbayeff]")
    |> mes("Are you serious? Did you say")
    |> mes("you've found The Moving Island?")
    |> next()
    |> emotion(:best)
    |> mes("[Berbayeff]")
    |> mes("The legend is true!!")
    |> mes("I was right, wasn't I?")
    |> mes("You must be a great adventurer.")
    |> close()
  end

  defp welcome(ctx) do
    ctx
    |> mes("[Berbayeff]")
    |> mes("Welcome to Moscovia.")
    |> mes("What's your impression thus far?")
    |> mes("Looks gorgeous, huh?")
    |> next()
    |> mes("[Berbayeff]")
    |> mes("Most travelers and strangers")
    |> mes("like our village.")
    |> mes("I want you to visit places here and")
    |> mes("there. You'll probably love this town.")
    |> close()
  end
end

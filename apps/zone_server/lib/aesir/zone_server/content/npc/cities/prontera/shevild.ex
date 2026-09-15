defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Shevild do
  @moduledoc """
  Shares Shevild's delivery adventures around Prontera's dangerous forests.

  ## Behavior

  - Explains how his delivery work led him into monster lairs.
  - Gives directions to the northern maze or northeastern ruins when asked.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 173,
        y: 24,
        dir: 2,
        sprite: 85,
        name: "Shevild",
        scope: :shared,
        unique_name: "Shevild#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shevild]")
      |> mes("Hey, come on over and let's drink! I have lots of interesting stories to tell!")
      |> mes(
        "I know lots of things about Prontera. I have seen many fine views and I also have explored some monster lairs around this city."
      )
      |> next()
      |> select(["How could you enter monster lairs?", "Cancel"])

    if choice == 1 do
      introduce_lairs(ctx)
    else
      invite_return(ctx)
    end
  end

  defp introduce_lairs(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shevild]")
      |> mes("I may appear to be a drunken man but I am more than meets the eye.")
      |> mes(
        "Well, I happened to enter the places for carrying weapons for hunters or for delivering stuffs and whatsoever."
      )
      |> mes("You might think of me as a mere delivery guy,")
      |> next()
      |> mes("[Shevild]")
      |> mes("But I am very proud of my job. You know how tough the world has become?")
      |> mes("No matter how hard a work is, I am not afraid of doing that.")
      |> next()
      |> mes("[Shevild]")
      |> mes("Anyways, that is how I have explored some strange places like monster lairs...")
      |> mes("That is also a reason why I keep my job.")
      |> mes("Ah, I just recall being inside the maze and the spooky forest!")
      |> next()
      |> select(["The Maze?", "The Spooky Forest?", "Cancel"])

    case choice do
      1 -> discuss_maze(ctx)
      2 -> discuss_forest(ctx)
      3 -> warn_adventurer(ctx)
      _ -> invite_return(ctx)
    end
  end

  defp discuss_maze(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shevild]")
      |> mes(
        "Yes. Few days ago, I have entered a mysterious maze following a group of hunters at the north of Prontera."
      )
      |> next()
      |> mes("[Shevild]")
      |> mes(
        "They said that they could get lots and lots of rare items from the maze even if the maze was filled with awfully strong monsters."
      )
      |> mes(
        "So we went there but as soon as we entered, we were just stuck inside the maze, you know."
      )
      |> next()
      |> mes("[Shevild]")
      |> mes(
        "We were just circling around and then we decided to leave the place. That was one hell of the maze."
      )
      |> mes("But I made up my mind that I would successfully explore the maze one day.")
      |> next()
      |> select(["How can I get there?", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Shevild]")
      |> mes("Err? Haven't you still toured the outside of Prontera?")
      |> mes(
        "The maze can be found inside a forest at the north of Prontera. Go check the north west side of the forest."
      )
      |> close()
    else
      warn_adventurer(ctx)
    end
  end

  defp discuss_forest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shevild]")
      |> mes(
        "When you go outside of Prontera heading to north east, you will arrive at the peaceful ruins. I have been there a while ago, to deliver something to a priest."
      )
      |> mes(
        "I had to pass a forest on the way to the ruins, and the forest was filled with monkeys and raccoons."
      )
      |> next()
      |> mes("[Shevild]")
      |> mes(
        "Be forewarned that the forest is not a place to go on a picnic. If you drop something on the ground, the monkeys come out from nowhere and take away all of your possessions."
      )
      |> next()
      |> select(["How can I get there?", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Shevild]")
      |> mes(
        "There is no road directly leads to the ruins. But if you go north and keep heading to east, you will get there."
      )
      |> mes(
        "Oh, be careful on your way to the ruins because there are some weird plant things that assault passersby for no reason."
      )
      |> close()
    else
      warn_adventurer(ctx)
    end
  end

  defp warn_adventurer(ctx) do
    ctx
    |> mes("[Shevild]")
    |> mes("Yeap, be careful when you adventure alone~")
    |> close()
  end

  defp invite_return(ctx) do
    ctx
    |> mes("[Shevild]")
    |> mes("Come back any time~")
    |> close()
  end
end

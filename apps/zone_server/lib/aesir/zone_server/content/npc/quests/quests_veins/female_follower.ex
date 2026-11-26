defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.FemaleFollower do
  @moduledoc """
  Lamir discusses her unwanted admirer.

  ## Behavior

  - Advances the volcano investigation after the player speaks with her.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temin",
        x: 40,
        y: 124,
        dir: 3,
        sprite: 920,
        name: "Female Follower",
        scope: :shared,
        unique_name: "Female Follower#vol"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Lamir]")
      |> mes("^333333*Sigh*^000000 High Priest Vildt")
      |> mes("left over so much food after")
      |> mes("eating. Didn't he learn to")
      |> mes("finish all of his food?")
      |> next()
      |> mes("[Lamir]")
      |> mes("You know, my mother used")
      |> mes("to threaten that she'd force")
      |> mes("me to marry Karlum if I didn't")
      |> mes("finish all my food when I was")
      |> mes("a kid. I learned never to")
      |> mes("leave any leftovers that way~")
      |> next()
      |> select(["Who's Karlum?"])

    ctx =
      ctx
      |> mes("[Lamir]")
      |> mes("Karlum? Oh, he's been")
      |> mes("chasing me ever since we")
      |> mes("were kids, declaring his")
      |> mes("love and all that. Even")
      |> mes("after we grew up, he's still")
      |> mes("stubborn about that point.")
      |> next()
      |> mes("[Lamir]")
      |> mes("Ugh! Even today, he")
      |> mes("still gets on my nerves!")
      |> mes("I mean, it's great that he's")
      |> mes("a guard at High Priest Vildt's")
      |> mes("office, but come on! Why can't")
      |> mes("he bother another girl?")

    ctx =
      if get_char_var(ctx, :aru_vol, 0) == 1 do
        set_char_var(ctx, :aru_vol, 2)
      else
        ctx
      end

    close(ctx)
  end
end

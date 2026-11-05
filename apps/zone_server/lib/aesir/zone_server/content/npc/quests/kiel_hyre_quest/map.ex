defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Map do
  @moduledoc """
  The cottage world map conceals a poem used in the Kiel Hyre investigation.

  ## Behavior

  - Reveals the hidden paper after steam loosens the map paste.
  - Records the discovery and lets the adventurer reread the poem.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_vila",
        x: 44,
        y: 126,
        dir: 0,
        sprite: 111,
        name: "Map",
        scope: :shared,
        unique_name: "Map#khp1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    poem_stage = get_char_var(ctx, :KHCottagePoem1, 0)
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      poem_stage < 2 and quest_stage < 30 -> inspect_map(ctx)
      poem_stage == 2 and quest_stage < 30 -> reveal_poem(ctx)
      poem_stage > 2 or quest_stage >= 30 -> offer_poem(ctx)
      true -> ctx
    end
  end

  defp inspect_map(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFA magnificent world map,")
      |> mes("detailing the Rune-Midgarts")
      |> mes("Kingdom, Schwarzwald Republic,")
      |> mes("as well as another country to the")
      |> mes("west whose name is unfamiliar")
      |> mes("to you, is pasted to this wall.^000000")
      |> next()
      |> mes("^3355FFAs you examine the")
      |> mes("world map more closely,")
      |> mes("you find that something has")
      |> mes("been hidden underneath it.^000000")
      |> select(["Ignore", "Examine"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFWhatever might be")
        |> mes("hidden beneath this")
        |> mes("map probably isn't")
        |> mes("important enough for")
        |> mes("you to investigate.^000000")
        |> close()

      2 ->
        ctx
        |> mes("^3355FFUnfortunately, you can't")
        |> mes("see what's under the map")
        |> mes("since it's pasted to the wall.")
        |> mes("You'll need to find some")
        |> mes("way to loosen the glue")
        |> mes("without damaging the map...^000000")
        |> set_char_var(:KHCottagePoem1, 1)
        |> close()

      _ ->
        ctx
    end
  end

  defp reveal_poem(ctx) do
    ctx
    |> mes("^3355FFYou bring the pot of")
    |> mes("steaming hot liquid")
    |> mes("close to the world map.")
    |> mes("As the paste on the wall")
    |> mes("moistens, the map slowly")
    |> mes("begins to peel back.^000000")
    |> next()
    |> mes("^3355FFThe peeling map reveals")
    |> mes("a folded piece of paper")
    |> mes("hidden beneath it. You")
    |> mes("take the paper, and smooth")
    |> mes("the map out to adhere it to the")
    |> mes("wall once again. A message is")
    |> mes("written on the piece of paper.^000000")
    |> next()
    |> read_poem()
    |> set_char_var(:KHCottagePoem1, 3)
    |> close()
  end

  defp offer_poem(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis is were you found")
      |> mes("the paper on which the")
      |> mes("poem was written. Perhaps")
      |> mes("it would be a good idea to")
      |> mes("refresh your memory and")
      |> mes("read that poem again.^000000")
      |> next()
      |> select(["Read", "Cancel"])

    case choice do
      1 ->
        ctx |> read_poem() |> close()

      2 ->
        ctx
        |> mes("^3355FFThere's no need for")
        |> mes("you to reread this poem.")
        |> mes("You're a freakin' genius!^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp read_poem(ctx) do
    ctx
    |> mes("^0000FFShe will be in a place")
    |> mes("as cold as the poles.")
    |> mes("When the well is dried")
    |> mes("and the earth is cracked,")
    |> mes("the path to her heart, a")
    |> mes("heart as transparent as")
    |> mes("crystal, will be open.^000000")
    |> next()
    |> mes("^3355FFI'll have to fight four")
    |> mes("snakes with four swords")
    |> mes("to find her. The first sword")
    |> mes("is love. The second sword")
    |> mes("is despair. The third sword")
    |> mes("is rage. The fourth sword is")
    |> mes("hope. To find her, to rescue her.^000000")
    |> next()
    |> mes("^3355FF...............................")
    |> mes("The deeper meaning")
    |> mes("of this poem, if it even")
    |> mes("exists, eludes you.^000000")
  end
end

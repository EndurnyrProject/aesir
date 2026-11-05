defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.WoodenBoard do
  @moduledoc """
  A discarded wooden board conceals a portrait relevant to Mitchell’s investigation.

  ## Behavior

  - Checks inventory capacity and reveals the portrait at the required quest stage.
  - Awards the portrait, advances the quest, and directs the adventurer back to Mitchell.

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
        map: "yuno_fild09",
        x: 158,
        y: 217,
        dir: 0,
        sprite: 111,
        name: "Wooden Board",
        scope: :shared,
        unique_name: "Wooden Board#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{7503, 1}]) == 0 do
      inventory_full(ctx)
    else
      inspect_board(ctx)
    end
  end

  defp inspect_board(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage < 62 or quest_stage >= 64 -> useless_board(ctx)
      quest_stage == 62 -> reveal_portrait(ctx)
      true -> ctx
    end
  end

  defp inventory_full(ctx) do
    ctx
    |> mes("^3355FFJust a second...")
    |> mes("You're carrying too")
    |> mes("many items with you")
    |> mes("right now, so you'll")
    |> mes("need to free up more")
    |> mes("Inventory space first...^000000")
    |> close()
  end

  defp useless_board(ctx) do
    ctx
    |> mes("^3355FFIt's a useless")
    |> mes("wooden board")
    |> mes("in the bushes.^000000")
    |> close()
  end

  defp reveal_portrait(ctx) do
    ctx
    |> mes("^3355FFYou found a long")
    |> mes("wooden board carved")
    |> mes("with the initials, ''K.H.''^000000")
    |> next()
    |> cutin("kh_kyel_port", 2)
    |> mes("^3355FFYou find a portrait of")
    |> mes("a young man, that looks")
    |> mes("like a younger version")
    |> mes("of Kiel Hyre, in a broken")
    |> mes("picture frame underneath")
    |> mes("the old wooden board.^000000")
    |> give_item(7503, 1)
    |> set_char_var(:KielHyreQuest, 64)
    |> next()
    |> cutin("", 255)
    |> mes("^3355FFYou have enough")
    |> mes("information by now,")
    |> mes("so you should report")
    |> mes("back to Mitchell.^000000")
    |> close()
  end
end

defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Pleur do
  @moduledoc """
  A glimpse of Pleur leads the player through the forest.

  ## Behavior

  - Warps the player to one of three maze locations at random.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_maze02",
        x: 57,
        y: 151,
        dir: 1,
        sprite: 91,
        name: "Pleur",
        scope: :shared,
        unique_name: "Pleur#warp"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou catch a glimpse")
      |> mes("of a girl heading directly")
      |> mes("into a deep forest. You decide")
      |> mes("to follow her and see if you can")
      |> mes("learn more.^000000")
      |> close2()
      |> set_local(:warp_s, Enum.random(1..10))

    case get_local(ctx, :warp_s, 0) do
      roll when roll < 5 -> warp(ctx, "prt_maze02", 11, 146)
      roll when roll > 7 -> warp(ctx, "prt_maze03", 55, 8)
      _ -> warp(ctx, "prt_maze01", 62, 129)
    end
  end
end

defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.OpenManhole do
  @moduledoc """
  The open manhole concludes the ghost quest and leads to the dungeon.

  ## Behavior

  - Concludes the ghost quest and awards experience at the appropriate stage.
  - Warps adventurers to the dungeon otherwise.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_in01",
        x: 206,
        y: 188,
        dir: 1,
        sprite: 844,
        name: "Open Manhole",
        scope: :shared,
        unique_name: "Open Manhole#todunbra"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :brazil_ghost, 0) == 7 do
      ctx =
        ctx
        |> enablenpc("Ghost#bra_end")
        |> mes("[Ghost]")
        |> mes("I am a ghost who died while wandering the jungle many years ago.")
        |> next()
        |> mes("[Ghost]")
        |> mes(
          "I found a pipeline in the jungle and followed the voice of a man to this very spot."
        )
        |> next()
        |> mes("[Ghost]")
        |> mes("That's also where I hurt one of my eyes while walking around in the dark.")
        |> next()
        |> mes("[Ghost]")
        |> mes(
          "I wandered these sewers for days until I found the end of this line connected to the toilet in the museum. I shouted forever begging for help but no one answered my calls."
        )
        |> next()
        |> mes("[Ghost]")
        |> mes(
          "You finally answered my call but it's already way too late. Thank you for at least checking. No one else has bothered to this day."
        )
        |> next()
        |> mes("[Ghost]")
        |> mes("There are many dangerous creatures at the end of this sewer.")
        |> mes(
          "You seem brave though. I bet you wouldn't worry about the monsters there anyways."
        )
        |> next()
        |> mes("[Ghost]")
        |> mes("I guess now I can finally rest in peace.")
        |> mes("Thank you friend.")
        |> set_char_var(:brazil_ghost, 8)
        |> completequest(60_355)

      ctx =
        if Rathena.truthy?(get_char_var(ctx, :VIP_SCRIPT, 0)) and
             Rathena.truthy?(vip_status(ctx, 1)) do
          getexp(ctx, 135_000, 0)
        else
          getexp(ctx, 90_000, 0)
        end

      ctx |> disablenpc("Ghost#bra_end") |> close()
    else
      warp(ctx, "bra_dun01", 87, 47)
    end
  end
end

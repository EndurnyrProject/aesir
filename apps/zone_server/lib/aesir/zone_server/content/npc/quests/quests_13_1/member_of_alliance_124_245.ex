defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MemberOfAlliance124245 do
  @moduledoc """
  A Rune-Midgarts alliance member posted in Lighthalzen, one of the eight voices around
  the expedition.

  ## Behavior

  - Points the player past step 19 at the dimensional rift guard instead of talking.
  - Otherwise sizes up the two alliance heads.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 124,
        y: 245,
        dir: 1,
        sprite: 932,
        name: "Member of Alliance",
        scope: :shared,
        unique_name: "Member of Alliance#5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @hint "-Maybe Munk is a better leader instead of Sakaiz. Anyways you should be heading to the dimensional rift next to Morocc and find the Guard there-"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) > 19 do
      pointed_to_rift(ctx)
    else
      chatter(ctx)
    end
  end

  defp pointed_to_rift(ctx) do
    ctx
    |> mes(@hint)
    |> close()
  end

  defp chatter(ctx) do
    ctx
    |> mes("[Member of Alliance]")
    |> mes("The head of the alliance, Sikaiz... doesn't look healthy.")
    |> next()
    |> mes("[Member of Alliance]")
    |> mes("But his upright eyes")
    |> mes("are quite reliable.")
    |> next()
    |> mes("[Member of Alliance]")
    |> mes(
      "Munkenro looks so willing to do anything for success. As well as he also seems flexible..."
    )
    |> close()
  end
end

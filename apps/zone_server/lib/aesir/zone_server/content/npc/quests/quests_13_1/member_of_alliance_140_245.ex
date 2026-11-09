defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MemberOfAlliance140245 do
  @moduledoc """
  A Rune-Midgarts alliance member posted in Lighthalzen, one of the eight voices around
  the expedition.

  ## Behavior

  - Points the player past step 19 at the dimensional rift guard instead of talking.
  - Otherwise complains about how far the gathering place is from the rift.

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
        x: 140,
        y: 245,
        dir: 1,
        sprite: 85,
        name: "Member of Alliance",
        scope: :shared,
        unique_name: "Member of Alliance#3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @hint "-You're still here? You're a member of the alliance now so you should head to the dimensional rift next to Morocc and find the Guard there-"

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
    |> mes(
      "I know we are all to go to the dimensional rift. That's why we are allied strongly. But we gather here... so far from there..."
    )
    |> next()
    |> mes("[Member of Alliance]")
    |> mes("I think we'd better gather in Prontera on Rune-Midgarts, where I am living.")
    |> next()
    |> mes("[Member of Alliance]")
    |> mes("Or just warp for commuting.")
    |> mes("I would hope so.")
    |> close()
  end
end

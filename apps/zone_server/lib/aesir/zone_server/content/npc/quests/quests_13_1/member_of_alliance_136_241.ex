defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MemberOfAlliance136241 do
  @moduledoc """
  A Rune-Midgarts alliance member posted in Lighthalzen, one of the eight voices around
  the expedition.

  ## Behavior

  - Points the player past step 19 at the dimensional rift guard instead of talking.
  - Otherwise complains about how bored he is.

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
        x: 136,
        y: 241,
        dir: 3,
        sprite: 849,
        name: "Member of Alliance",
        scope: :shared,
        unique_name: "Member of Alliance#6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @hint "-I'm so bored!!! You should be heading to the dimensional rift next to Morocc and find the Guard there. It's probably less boring there than it is here-"

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
    |> mes("I am almost dying of boredom!")
    |> next()
    |> mes("[Member of Alliance]")
    |> mes("So boring!")
    |> next()
    |> mes("[Member of Alliance]")
    |> mes("I am not in a good mood.")
    |> close()
  end
end

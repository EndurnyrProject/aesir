defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests131.MemberOfAlliance do
  @moduledoc """
  A member of the Rune-Midgarts alliance who shares the kingdom's private view of its
  Schwarzwald and Arunafeltz partners.

  ## Behavior

  - Talks about the alliance's secret plans once the player has reached `ep13_ryu` 12 or 13.
  - Tells everyone else that strength is what matters.

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
        map: "prt_cas",
        x: 23,
        y: 104,
        dir: 5,
        sprite: 754,
        name: "Member of Alliance",
        scope: :renewal,
        unique_name: "Member of Alliance#prt"
      },
      %{
        map: "prt_castle",
        x: 117,
        y: 51,
        dir: 5,
        sprite: 754,
        name: "Member of Alliance",
        scope: :pre_renewal,
        unique_name: "Member of Alliance#prt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) in [12, 13] do
      secret_plans(ctx)
    else
      strength_lines(ctx)
    end
  end

  defp secret_plans(ctx) do
    ctx
    |> mes("[Member of Alliance]")
    |> mes(
      "If we have absolute power, we wouldn't have to get along with Schwarzwald and Arunafeltz."
    )
    |> next()
    |> mes("[Member of Alliance]")
    |> mes(
      "I don't know when Satan Morocc will attack us, and whether we're powerful enough to detect him."
    )
    |> next()
    |> mes("[Member of Alliance]")
    |> mes("We couldn't avoid cooperating with them. We don't have many choices left.")
    |> next()
    |> mes("[Member of Alliance]")
    |> mes("So we will take advantage over them in secret, in this dimensional rift.")
    |> close()
  end

  defp strength_lines(ctx) do
    ctx
    |> mes("[Member of Alliance]")
    |> mes("If we'd have had more power,")
    |> mes("we wouldn't be like this now.")
    |> mes("Strength is most important.")
    |> close()
  end
end

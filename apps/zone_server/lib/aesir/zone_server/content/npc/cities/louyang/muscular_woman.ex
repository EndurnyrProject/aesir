defmodule Aesir.ZoneServer.Content.Npc.Cities.Louyang.MuscularWoman do
  @moduledoc """
  Recruits women for the all-female Maiden Palace.

  ## Behavior

  - Invites female visitors to consider joining the group.
  - Dismisses other visitors without discussing recruitment.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vidar
    - Mass Zero
    - Dino9021
    - Celest
    - MasterOfMuppets
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "louyang",
        x: 297,
        y: 167,
        dir: 2,
        sprite: 815,
        name: "Muscular Woman",
        scope: :shared,
        unique_name: "Muscular Woman#lou"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if sex(ctx) == get_char_var(ctx, :SEX_FEMALE, 0) do
      recruit_visitor(ctx)
    else
      dismiss_visitor(ctx)
    end
  end

  defp recruit_visitor(ctx) do
    ctx
    |> mes("[Zhi Ching Li]")
    |> mes(
      "All the members of the Maiden Palace, including myself and our master, are all female."
    )
    |> next()
    |> mes("[Zhi Ching Li]")
    |> mes(
      "Recently we've had a hard time recruiting new members, so I came here to check if there's any woman who wishes to join us."
    )
    |> emotion(:think)
    |> close()
  end

  defp dismiss_visitor(ctx) do
    ctx
    |> mes("[Zhi Ching Li]")
    |> mes("...")
    |> next()
    |> mes("[Zhi Ching Li]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Zhi Ching Li]")
    |> mes("Please leave me")
    |> mes("alone, I'm busy.")
    |> close()
  end
end

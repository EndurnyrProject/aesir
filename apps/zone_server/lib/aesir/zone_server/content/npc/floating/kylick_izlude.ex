defmodule Aesir.ZoneServer.Content.Npc.Floating.KylickIzlude do
  @moduledoc """
  Kylick, an Izlude lookout who talks about Amatsu or the town telescope.

  ## Behavior

  - Outside renewal, half of the interactions are about Amatsu's seafood; the
    rest always describe the telescope that watches the coast.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Nexon
    - Silentdragon
    - MasterOfMuppets
    - Silent
    - Evera
    - CAHTEXHuK
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/izlude.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlude",
        x: 140,
        y: 186,
        dir: 4,
        sprite: 97,
        name: "Kylick",
        scope: :renewal,
        unique_name: "Kylick#izlude"
      },
      %{
        map: "izlude_a",
        x: 140,
        y: 186,
        dir: 4,
        sprite: 97,
        name: "Kylick",
        scope: :renewal,
        unique_name: "Kylick#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 140,
        y: 186,
        dir: 4,
        sprite: 97,
        name: "Kylick",
        scope: :renewal,
        unique_name: "Kylick#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 140,
        y: 186,
        dir: 4,
        sprite: 97,
        name: "Kylick",
        scope: :renewal,
        unique_name: "Kylick#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 140,
        y: 186,
        dir: 4,
        sprite: 97,
        name: "Kylick",
        scope: :renewal,
        unique_name: "Kylick#izlude_d"
      },
      %{
        map: "izlude",
        x: 150,
        y: 143,
        dir: 2,
        sprite: 97,
        name: "Kylick",
        scope: :pre_renewal,
        unique_name: "Kylick#izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if not Rathena.truthy?(checkre(ctx, 0)) and Rathena.truthy?(:rand.uniform(2) - 1) do
      about_amatsu(ctx)
    else
      about_the_telescope(ctx)
    end
  end

  defp about_amatsu(ctx) do
    ctx
    |> mes("[Kylick]")
    |> mes("I was thinking, even though the people of Izlude live so close to the ocean...")
    |> next()
    |> mes("[Kylick]")
    |> mes(
      "There are other cultures that have completely developed by living off of the sea. Of course, I'm talking about Amatsu."
    )
    |> next()
    |> mes("[Kylick]")
    |> mes(
      "I hear the cuisine there is really good! Although the idea of eating raw fish is new to me, I would love to go there, and try it just once!"
    )
    |> close()
  end

  defp about_the_telescope(ctx) do
    ctx
    |> mes("[Kylick]")
    |> mes("Don't you think Binoculars")
    |> mes("are really COOL?! You can")
    |> mes("see all sorts of places...!")
    |> next()
    |> mes("[Kylick]")
    |> mes(
      "Here in Izlude, we are responsible for maintaining peace not only on land but also at sea. That's why this city has a huge telescope."
    )
    |> next()
    |> mes("[Kylick]")
    |> mes(
      "This telescope constantly watches over the sea, so that we can prevent any serious trouble from happening. You know..."
    )
    |> next()
    |> mes("[Kylick]")
    |> mes("An ounce of")
    |> mes("prevention is worth")
    |> mes("a pound of cure")
    |> mes("after all, right?")
    |> close()
  end
end

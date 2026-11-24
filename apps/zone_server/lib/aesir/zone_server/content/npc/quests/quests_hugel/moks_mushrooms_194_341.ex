defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.MoksMushrooms194341 do
  @moduledoc """
  Provides mushrooms for the rebellion quest.

  ## Behavior

  - Lets the player gather quest materials, with a chance of failure.
  - Temporarily disables this gathering spot after a successful collection.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_fild06",
        x: 194,
        y: 341,
        dir: 3,
        sprite: 111,
        name: "Moks Mushrooms",
        scope: :shared,
        unique_name: "Moks Mushrooms#Mush2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTimer20000", ctx), do: enable_spot(ctx)

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :hg_tre, 0)

    cond do
      progress in 10..14 ->
        {ctx, choice} =
          ctx
          |> mes("- You found mushrooms that are as big as your palm. -")
          |> next()
          |> select(["Gather them.", "Pass."])

        case choice do
          1 -> gather(ctx, progress)
          2 -> ctx |> mes("- You decided to pass by them. -") |> close()
          _ -> ctx
        end

      progress == 15 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I think that this will do.")
        |> close()

      true ->
        enable_spot(ctx)
    end
  end

  defp gather(ctx, progress) do
    ctx =
      ctx
      |> mes("- You decided to gather the mushrooms. -")
      |> next()
      |> mes("- *Snip Snip* -")
      |> next()
      |> mes("- *Snip Snip* -")
      |> mes("- *Snip Snip* -")
      |> next()
      |> mes("- *Snip Snip* -")
      |> mes("- *Snip Snip* -")
      |> mes("- *Snip Snip* -")
      |> specialeffect2(:cone)
      |> next()

    if Enum.random(1..5) > 4 do
      ctx
      |> mes(
        "- You were being clumsy and broke the mushrooms. You have failed in gathering the mushrooms. -"
      )
      |> specialeffect2(:stunattack)
      |> close()
    else
      ctx
      |> mes("- You have successfully gathered mushrooms. -")
      |> specialeffect2(:vallentine2)
      |> set_char_var(:hg_tre, progress + 1)
      |> mes("Collected Moks Mushroom Solution: #{progress - 10 + 1}ea ")
      |> initnpctimer()
      |> disablenpc("Moks Mushrooms#Mush2")
      |> close()
    end
  end

  defp enable_spot(ctx), do: ctx |> enablenpc("Moks Mushrooms#Mush2") |> stopnpctimer()
end

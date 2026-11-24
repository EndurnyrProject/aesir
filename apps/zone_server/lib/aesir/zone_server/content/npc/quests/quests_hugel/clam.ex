defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Clam do
  @moduledoc """
  Provides clams for the rebellion quest.

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
        map: "hugel",
        x: 209,
        y: 163,
        dir: 3,
        sprite: 111,
        name: "Clam",
        scope: :shared,
        unique_name: "Clam#C1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTimer20000", ctx), do: enable_spot(ctx)

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :hg_tre, 0)

    cond do
      progress in 20..24 ->
        {ctx, choice} =
          ctx
          |> mes("- You found very fresh clams whose shells are shining under the sunlight. -")
          |> next()
          |> select(["Gather them.", "Pass."])

        case choice do
          1 -> gather(ctx, progress)
          2 -> ctx |> mes("- You decided to pass by them. -") |> close()
          _ -> ctx
        end

      progress == 25 ->
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
      |> mes("- You started opening clam shells to gather Clam Flesh.-")
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
      |> mes("- Clams are too strong to open. You have failed in gathering Clam Flesh. -")
      |> specialeffect2(:stunattack)
      |> close()
    else
      ctx
      |> mes("- You have successfully gathered Clam Flesh. -")
      |> specialeffect2(:vallentine2)
      |> set_char_var(:hg_tre, progress + 1)
      |> mes("Collected Clam Flesh: #{progress - 20 + 1}ea ")
      |> initnpctimer()
      |> disablenpc("Clam#C1")
      |> close()
    end
  end

  defp enable_spot(ctx), do: ctx |> enablenpc("Clam#C1") |> stopnpctimer()
end

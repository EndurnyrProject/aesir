defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.MoksBugs218373 do
  @moduledoc """
  Provides bugs for the rebellion quest.

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
        x: 218,
        y: 373,
        dir: 1,
        sprite: 1053,
        name: "Moks Bugs",
        scope: :shared,
        unique_name: "Moks Bugs#Bug4"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTimer20000", ctx), do: enable_spot(ctx)

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :hg_tre, 0)

    cond do
      progress in 30..34 ->
        {ctx, choice} =
          ctx
          |> mes("- You found big brown Moks Bugs in the bushes. -")
          |> next()
          |> select(["Catch them.", "Pass."])

        case choice do
          1 -> gather(ctx, progress)
          2 -> ctx |> mes("- You decided to pass by them. -") |> close()
          _ -> ctx
        end

      progress == 35 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Aww...I don't want to touch dirty things like bugs!")
        |> close()

      true ->
        enable_spot(ctx)
    end
  end

  defp gather(ctx, progress) do
    ctx =
      ctx
      |> mes("- You nervously stretched your hands toward Moks Bugs.-")
      |> next()
      |> mes("- *Whizz Whizz*-")
      |> next()
      |> mes("- *Whizz Whizz Bzzzz* -")
      |> mes("- *Whizz Whizz*-")
      |> next()
      |> mes("- *Whizz Whizz Bzzzz* -")
      |> mes("- *Whizz Whizz*-")
      |> mes("- *Whizz Whizz*-")
      |> specialeffect2(:cone)
      |> next()

    if Enum.random(1..5) > 4 do
      ctx
      |> mes("- The bugs quickly ran away. You have failed to gather their shells. -")
      |> specialeffect2(:stunattack)
      |> close()
    else
      ctx
      |> mes("- You have successfully gathered Moks Bugs Shells. -")
      |> specialeffect2(:vallentine2)
      |> set_char_var(:hg_tre, progress + 1)
      |> mes("Collected Moks Bugs Shells: #{progress - 30 + 1}ea ")
      |> initnpctimer()
      |> disablenpc("Moks Bugs#Bug4")
      |> close()
    end
  end

  defp enable_spot(ctx), do: ctx |> enablenpc("Moks Bugs#Bug4") |> stopnpctimer()
end

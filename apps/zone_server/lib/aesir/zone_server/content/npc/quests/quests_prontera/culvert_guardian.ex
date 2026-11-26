defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.CulvertGuardian do
  @moduledoc """
  The guardian admits registered volunteers to the Prontera Culvert.

  ## Behavior

  - Other visitors are directed to the recruiter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_fild05",
        x: 270,
        y: 212,
        dir: 5,
        sprite: 105,
        name: "Culvert Guardian",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8)) do
      {ctx, choice} =
        ctx
        |> mes("[Culvert Guardian]")
        |> mes("Ah, you're one of our volunteers. This is the entrance of the Prontera Culvert.")
        |> mes("Do you wish to")
        |> mes("go inside?")
        |> next()
        |> select(["Sure.", "Quit."])

      if choice == 1, do: warp(ctx, "prt_sewb1", 131, 247), else: close(ctx)
    else
      ctx
      |> mes("[Culvert Guardian]")
      |> mes("I'm sorry, but we can only allow volunteers for the Culvert Campaign to enter.")
      |> next()
      |> mes("[Culvert Guardian]")
      |> mes(
        "If you'd like to volunteer, please visit the ^000077Culvert Registrar^000000 located in the 11 O'clock direction of Prontera."
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end

defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22e.Soullinker.SoulLinkerVar do
  @moduledoc """
  GM tool that resets the Soul Linker job quest ceremony lock.

  ## Behavior

  - Requires the GM password check before offering the reset.
  - Resetting frees the ceremony so another candidate can enter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celestria
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "sec_in02",
        x: 35,
        y: 153,
        dir: 0,
        sprite: 871,
        name: "Soul Linker Var",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Todo

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> todo(:callfunc, ["F_GM_NPC"])
      |> mes("[Soul Linker Var]")
      |> mes("I can reset the Soul Linker")
      |> mes("NPCs if a Soul Linker candidate")
      |> mes("encounters a problem during the")
      |> mes("end of the job quest. Please do")
      |> mes("not use this function if players are still in the Quest Map.")
      |> next()

    if Todo.call!(:callfunc, ["F_GM_NPC", 1854, 0]) < 1 do
      ctx |> mes("[Soul Linker Var]") |> mes("Password") |> mes("is incorrect.") |> close()
    else
      offer_reset(ctx)
    end
  end

  defp offer_reset(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Soul Linker Var]")
      |> mes("Would you like to")
      |> mes("reset the Soul Linker")
      |> mes("Global Variable?")
      |> next()
      |> select(["Reset", "Cancel"])

    case choice do
      1 ->
        ctx
        |> mes("[Soul Linker Var]")
        |> mes("The Soul Linker")
        |> mes("Job Quest NPCs")
        |> mes("have been reset.")
        |> set_npc_var_of("SoulLinkerTest", "Kid#link1", 0)
        |> close()

      2 ->
        ctx
        |> mes("[Soul Linker Var]")
        |> mes("You have canceled")
        |> mes("this command.")
        |> close()

      _ ->
        ctx
    end
  end
end

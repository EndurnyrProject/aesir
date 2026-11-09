defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.SplPrs1 do
  @moduledoc """
  Voices a prisoner's plea from the other side of a wall.

  ## Behavior

  - Responds to OnTouch in intelligible speech while the Ring of the Ancient Wise King is equipped and the ep13_2_rhea
    gate is complete; otherwise speaks in untranslated language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_in01",
        x: 265,
        y: 315,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#spl_prs1",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    speak_through_wall(ctx)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch", ctx)

  defp speak_through_wall(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Voice from another side]")
      |> mes("Sir, Please!!!")
      |> mes("How can I communicate secretly with Manuk!!")
      |> mes("I'm innocent. Please.")
      |> close()
    else
      ctx
      |> mes("[Voice from another side]")
      |> mes("RuffUdeneo Mu VilAsh")
      |> mes("YurReDur Ha DielTalNe Ko Lars")
      |> mes("HirVerWeh Yu AnuNud")
      |> close()
    end
  end
end

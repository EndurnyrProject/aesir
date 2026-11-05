defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.KnightSkills.Npc do
  @moduledoc """
  Invisible trigger at the 7th Division training grounds that plays the Knights' training
  shouts during the Charge Attack skill quest.

  ## Behavior

  - Stepping in before quest step 3 plays the Knights' dramatized battle cries, advancing step 1
    to 2.
  - Does nothing once the quest has progressed further.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - DracoRPG
    - Samuray22
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 69,
        y: 351,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#tour",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :KNGT_SK, 0) > 2, do: ctx, else: training_shouts(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch", ctx)

  defp training_shouts(ctx) do
    ctx =
      ctx
      |> mes("[?]")
      |> mes("Kiiiiiiai~!")
      |> mes("Yaaaaaaaaap!")
      |> mes("Hoo! Haa! Haiyah!")
      |> next()
      |> mes("[?]")
      |> mes("Si-Aiyah!")
      |> mes("Rowr rowr rowr")
      |> mes("GrrrrrrrraaAAHH!")
      |> next()
      |> mes("^3355FFThese Knights appear to be")
      |> mes("putting themselves through")
      |> mes("some gruelingly difficult")
      |> mes("training. But as you listen")
      |> mes("a little more closely, their")
      |> mes("screams seem a bit dramatized.^000000")

    ctx
    |> advance_from(get_char_var(ctx, :KNGT_SK, 0))
    |> close()
  end

  defp advance_from(ctx, 1), do: set_char_var(ctx, :KNGT_SK, 2)
  defp advance_from(ctx, _step), do: ctx
end

defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.Npc do
  @moduledoc """
  Hidden trigger that lets Acolytes hear a noise from a convent window during the Acolyte
  training quest.

  ## Behavior

  - On touch, Acolytes at certain quest steps hear a sound coming from the window, hinting at
    the eavesdropping spot nearby.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Capuche
    - Euphy
    - Daegaladh
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_monk",
        x: 217,
        y: 123,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#tu_monk",
        trigger: {10, 10}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) and
         get_char_var(ctx, :tu_acolyte01, 0) in [4, 10, 25] do
      ctx
      |> mes("[Sound by Window]")
      |> mes("...")
      |> next()
      |> mes("^3355FFThere's some kind")
      |> mes("of noise coming from")
      |> mes("yonder window...^000000")
      |> close()
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
